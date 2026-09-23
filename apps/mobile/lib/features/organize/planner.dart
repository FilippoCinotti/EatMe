import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/entitlements.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import 'guilty_pleasure.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key, this.initialRecipeId});
  final String? initialRecipeId;
  @override
  ConsumerState<PlannerPage> createState() => _PlannerState();
}

class _PlannerState extends ResourceState<PlannerPage> {
  @override
  String get path => '/plans';
  DateTime start = DateUtils.dateOnly(DateTime.now());
  List<Json> recipes = [];
  List<String>? participants;
  Json? selected;
  List<Json>? draftMeals;
  bool pendingAdded = false;
  @override
  Future<void> load() async {
    await super.load();
    try {
      final result = await ref.read(apiProvider).request('GET', '/recipes');
      if (mounted && context.mounted) {
        setState(() {
          recipes = records(result['items']);
          selected = records(
            data?['items'],
          ).where((p) => p['start_date'] == isoDay(start)).firstOrNull;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && context.mounted) setState(() => error = e.code);
    }
  }

  List<Json> get preferenceOverrides =>
      records(selected?['data']?['preference_overrides']);

  Future<void> saveMeals(List<Json> meals, {List<Json>? overrides}) async {
    final source = overrides ?? preferenceOverrides;
    final validTargets = {
      for (final meal in meals) '${meal['date']}:${meal['slot']}',
    };
    final safeOverrides = source
        .where(
          (item) =>
              item['scope'] == 'day' ||
              validTargets.contains('${item['date']}:${item['slot']}'),
        )
        .toList();
    final result = await command({
      'action': 'save',
      'start_date': isoDay(start),
      'meals': meals,
      'preference_overrides': safeOverrides,
      if (selected != null) 'id': selected!['id'],
      if (selected != null) 'expected_version': selected!['version'],
    });
    if (mounted && result['id'] != null) setState(() => selected = result);
  }

  bool hasGuiltyPleasure(Json meal, List<Json> overrides) => overrides.any(
    (item) =>
        item['mode'] == 'guilty_pleasure' &&
        item['date'] == meal['date'] &&
        (item['scope'] == 'day' ||
            (item['scope'] == 'meal' && item['slot'] == meal['slot'])),
  );

  Future<void> changeGuiltyPleasure(Json meal) async {
    final overrides = [...preferenceOverrides];
    final active = hasGuiltyPleasure(meal, overrides);
    final choice = await showGuiltyPleasureSheet(context, active: active);
    if (choice == null || !mounted) return;
    if (choice == 'off') {
      overrides.removeWhere(
        (item) =>
            item['date'] == meal['date'] &&
            (item['scope'] == 'day' || item['slot'] == meal['slot']),
      );
    } else {
      overrides.removeWhere(
        (item) =>
            item['date'] == meal['date'] &&
            (choice == 'day' || item['slot'] == meal['slot']),
      );
      overrides.add({
        'mode': 'guilty_pleasure',
        'scope': choice,
        'date': meal['date'],
        if (choice == 'meal') 'slot': meal['slot'],
      });
    }
    await saveMeals(records(selected?['data']?['meals']), overrides: overrides);
  }

  Future<void> addMeal(DateTime day, String slot) async {
    final recipe = await chooseRecipe();
    if (recipe == null || !mounted) return;
    await addSpecificMeal(day, slot, recipe);
  }

  Future<Json?> chooseRecipe() => showModalBottomSheet<Json>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (context) => ListView(
      children: [
        for (final recipe in recipes)
          ListTile(
            title: Text(labelOf(recipe['title'], context)),
            subtitle: Text('${recipe['minutes']} min'),
            onTap: () => Navigator.pop(context, recipe),
          ),
      ],
    ),
  );

  Future<void> replaceMeal(DateTime day, String slot, Json meal) async {
    final recipe = await chooseRecipe();
    if (recipe == null || !mounted) return;
    if (draftMeals != null) {
      setState(() {
        final index = draftMeals!.indexOf(meal);
        draftMeals![index] = {...meal, 'recipe_id': recipe['id']};
      });
      return;
    }
    await addSpecificMeal(day, slot, recipe);
  }

  Future<void> addSpecificMeal(DateTime day, String slot, Json recipe) async {
    final servings = await askText(
      context,
      context.t('servings'),
      initial: '1',
      numeric: true,
    );
    if (servings == null) return;
    final meals = records(
      selected?['data']?['meals'],
    ).where((m) => !(m['date'] == isoDay(day) && m['slot'] == slot)).toList();
    meals.add({
      'date': isoDay(day),
      'slot': slot,
      'recipe_id': recipe['id'],
      'servings': int.tryParse(servings) ?? 1,
      if (participants != null) 'participants': participants,
    });
    await saveMeals(meals);
    if (mounted && recipe['id'] == widget.initialRecipeId) {
      setState(() => pendingAdded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meals = draftMeals ?? records(selected?['data']?['meals']);
    final overrides = preferenceOverrides;
    final entitlement = ref.watch(entitlementsProvider).asData?.value;
    final canSmartPlan =
        entitlement?.can(EntitlementCapability.smartPlanning) == true;
    final canGenerateShopping =
        entitlement?.can(EntitlementCapability.generatedShopping) == true;
    final settings = Map<String, dynamic>.from(
      ref.watch(appProvider).profile['settings'] as Map? ?? {},
    );
    final mealTiming = Map<String, dynamic>.from(
      settings['meal_timing'] as Map? ?? const {'mode': 'standard'},
    );
    final enabledSlots = Map<String, dynamic>.from(
      mealTiming['slots'] as Map? ?? const {},
    );
    final pendingRecipe = pendingAdded || widget.initialRecipeId == null
        ? null
        : recipes
              .where((recipe) => recipe['id'] == widget.initialRecipeId)
              .firstOrNull;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('plan'))),
      body: content([
        EatMeTabStrip(
          values: [
            ('plan', context.t('my_plan')),
            ('dinners', context.t('dinners')),
            ('shopping', context.t('shopping_list')),
          ],
          selected: 'plan',
          onSelected: (value) {
            if (value == 'dinners') context.go('/plan/dinners');
            if (value == 'shopping') context.go('/plan/shopping');
          },
        ),
        const SizedBox(height: 24),
        Text(
          context.t('week_at_a_glance'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          context.t('plan_editorial'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (mealTiming['mode'] != 'standard') ...[
          const SizedBox(height: 14),
          StatusNote(
            text: context.t('active_eating_window', {
              'start': mealTiming['start'] as String? ?? '—',
              'end': mealTiming['end'] as String? ?? '—',
            }),
          ),
        ],
        if (pendingRecipe != null) ...[
          const SizedBox(height: 18),
          InformationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('plan_this_recipe'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(labelOf(pendingRecipe['title'], context)),
                const SizedBox(height: 14),
                AsyncAction(
                  label: context.t('add_to_tonight'),
                  action: () => addSpecificMeal(
                    DateUtils.dateOnly(DateTime.now()),
                    'dinner',
                    pendingRecipe,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const EatMeIcon(EatMeGlyph.calendar, size: 19),
          label: Text(
            MaterialLocalizations.of(context).formatMediumDate(start),
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (date != null) {
              setState(() => start = date);
              await load();
            }
          },
        ),
        AsyncAction(
          label: context.t('who_is_eating'),
          secondary: true,
          action: () async {
            final value = await chooseDiners(
              context,
              ref.read(apiProvider),
              participants,
            );
            if (value != null && mounted) setState(() => participants = value);
          },
        ),
        AsyncAction(
          label: context.t(
            canSmartPlan ? 'generate_week' : 'smart_plan_with_plus',
          ),
          action: () async {
            if (!canSmartPlan) {
              await showContextualPlusPrompt(
                context,
                benefit: 'smart_planning_plus_body',
              );
              return;
            }
            final result = await command({
              'action': 'preview_generate',
              if (participants != null) 'participants': participants,
              'start_date': isoDay(start),
              'servings': 1,
            });
            if (mounted && result['preview'] == true) {
              setState(() => draftMeals = records(result['data']?['meals']));
            }
          },
        ),
        if (draftMeals != null) ...[
          const SizedBox(height: 12),
          InformationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('smart_plan_preview_title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(context.t('smart_plan_preview_body')),
                const SizedBox(height: 14),
                AsyncAction(
                  label: context.t('accept_plan'),
                  action: () async {
                    await saveMeals(draftMeals!);
                    if (mounted) setState(() => draftMeals = null);
                  },
                ),
                TextButton(
                  onPressed: () => setState(() => draftMeals = null),
                  child: Text(context.t('discard_preview')),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (selected != null)
          AsyncAction(
            label: context.t(
              canGenerateShopping
                  ? 'build_shopping_list'
                  : 'generated_shopping_with_plus',
            ),
            secondary: true,
            action: () async {
              if (!canGenerateShopping) {
                await showContextualPlusPrompt(
                  context,
                  benefit: 'generated_shopping_plus_body',
                );
                return;
              }
              await Mutation().send(
                ref.read(apiProvider),
                'POST',
                '/shopping',
                {'action': 'generate', 'plan_id': selected!['id']},
              );
              if (mounted && context.mounted) context.go('/plan/shopping');
            },
          ),
        const SizedBox(height: 24),
        for (var i = 0; i < 7; i++) ...[
          Text(
            MaterialLocalizations.of(
              context,
            ).formatFullDate(start.add(Duration(days: i))),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final slot in [
            'breakfast',
            'lunch',
            'dinner',
            'snack',
          ].where((slot) => enabledSlots[slot] as bool? ?? true))
            Builder(
              builder: (context) {
                final day = start.add(Duration(days: i));
                final meal = meals
                    .where((m) => m['date'] == isoDay(day) && m['slot'] == slot)
                    .firstOrNull;
                final recipe = recipes
                    .where((r) => r['id'] == meal?['recipe_id'])
                    .firstOrNull;
                final guiltyPleasure =
                    meal != null && hasGuiltyPleasure(meal, overrides);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InformationPanel(
                    tinted: false,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: meal == null
                          ? null
                          : FoodImage(
                              id: '${meal['recipe_id']}',
                              width: 56,
                              height: 56,
                              radius: 12,
                            ),
                      title: Text(context.t(slot)),
                      subtitle: meal == null
                          ? null
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${labelOf(recipe?['title'] ?? '', context)} · ${meal['servings']}',
                                ),
                                if (guiltyPleasure)
                                  Text(
                                    context.t('guilty_pleasure'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                              ],
                            ),
                      trailing: meal == null
                          ? const EatMeIcon(EatMeGlyph.plus)
                          : PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'delete') {
                                  if (draftMeals != null) {
                                    setState(() => draftMeals!.remove(meal));
                                  } else {
                                    await saveMeals(
                                      meals.where((m) => m != meal).toList(),
                                    );
                                  }
                                } else if (action == 'guilty_pleasure') {
                                  await changeGuiltyPleasure(meal);
                                } else {
                                  await replaceMeal(day, slot, meal);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'replace',
                                  child: Text(context.t('replace')),
                                ),
                                PopupMenuItem(
                                  value: 'guilty_pleasure',
                                  child: Text(
                                    context.t(
                                      guiltyPleasure
                                          ? 'view_guilty_pleasure_context'
                                          : 'make_guilty_pleasure',
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(context.t('delete')),
                                ),
                              ],
                            ),
                      onTap: () => meal == null
                          ? addMeal(day, slot)
                          : context.push('/recipes/${meal['recipe_id']}'),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ]),
    );
  }
}
