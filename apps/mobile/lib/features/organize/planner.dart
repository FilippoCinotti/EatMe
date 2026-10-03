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
  int focusedDay = 0;
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

  Future<void> generatePlan(bool canSmartPlan) async {
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
  }

  Future<void> removeMeal(Json meal, List<Json> meals) async {
    if (draftMeals != null) {
      setState(() => draftMeals!.remove(meal));
    } else {
      await saveMeals(meals.where((value) => value != meal).toList());
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
    final enabled = Map<String, dynamic>.from(
      mealTiming['slots'] as Map? ?? const {},
    );
    final slots = [
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    ].where((slot) => enabled[slot] as bool? ?? true).toList();
    final day = start.add(Duration(days: focusedDay));
    final plannedToday = <({String slot, Json meal, Json? recipe})>[];
    for (final slot in slots) {
      final meal = meals
          .where(
            (value) => value['date'] == isoDay(day) && value['slot'] == slot,
          )
          .firstOrNull;
      if (meal != null) {
        plannedToday.add((
          slot: slot,
          meal: meal,
          recipe: recipes
              .where((recipe) => recipe['id'] == meal['recipe_id'])
              .firstOrNull,
        ));
      }
    }
    final featured =
        plannedToday.where((value) => value.slot == 'dinner').firstOrNull ??
        plannedToday.firstOrNull;
    final upcoming = <({DateTime day, Json meal, Json? recipe})>[];
    for (
      var offset = focusedDay + 1;
      offset < 7 && upcoming.length < 2;
      offset++
    ) {
      final candidateDay = start.add(Duration(days: offset));
      final meal = meals
          .where((value) => value['date'] == isoDay(candidateDay))
          .firstOrNull;
      if (meal != null) {
        upcoming.add((
          day: candidateDay,
          meal: meal,
          recipe: recipes
              .where((recipe) => recipe['id'] == meal['recipe_id'])
              .firstOrNull,
        ));
      }
    }
    final emptyDays = List.generate(
      7,
      (index) => isoDay(start.add(Duration(days: index))),
    ).where((date) => !meals.any((meal) => meal['date'] == date)).length;
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
            ('dinners', context.t('with_friends')),
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
          context.t('plan_kicker').toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 3,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('plan_compact_title'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        _WeekStrip(
          start: start,
          selected: focusedDay,
          onSelected: (value) => setState(() => focusedDay = value),
        ),
        const SizedBox(height: 18),
        _WeekSummary(
          planned: meals.length,
          emptyDays: emptyDays,
          progress: slots.isEmpty
              ? 0
              : (meals.length / (slots.length * 7)).clamp(0.0, 1.0).toDouble(),
          onComplete: () => generatePlan(canSmartPlan),
        ),
        if (mealTiming['mode'] != 'standard') ...[
          const SizedBox(height: 12),
          StatusNote(
            text: context.t('active_eating_window', {
              'start': mealTiming['start'] as String? ?? '—',
              'end': mealTiming['end'] as String? ?? '—',
            }),
          ),
        ],
        if (pendingRecipe != null) ...[
          const SizedBox(height: 14),
          InformationPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('plan_this_recipe')),
                      Text(
                        labelOf(pendingRecipe['title'], context),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => addSpecificMeal(
                    DateUtils.dateOnly(DateTime.now()),
                    'dinner',
                    pendingRecipe,
                  ),
                  child: Text(context.t('add_to_tonight')),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PlannerActionTile(
                key: const ValueKey('planner-date-action'),
                icon: EatMeGlyph.calendar,
                label: context.t('change_week'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date != null) {
                    setState(() {
                      start = DateUtils.dateOnly(date);
                      focusedDay = 0;
                    });
                    await load();
                  }
                },
              ),
            ),
            if (participants == null || participants!.isEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _PlannerActionTile(
                  key: const ValueKey('planner-diners-action'),
                  icon: EatMeGlyph.usersRound,
                  label: context.t('who_is_eating'),
                  onTap: () async {
                    final value = await chooseDiners(
                      context,
                      ref.read(apiProvider),
                      participants,
                    );
                    if (value != null && mounted) {
                      setState(() => participants = value);
                    }
                  },
                ),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
              child: _PlannerActionTile(
                key: const ValueKey('planner-smart-action'),
                icon: canSmartPlan
                    ? EatMeGlyph.sparkles
                    : EatMeGlyph.badgeCheck,
                label: context.t(canSmartPlan ? 'generate_week' : 'eatme_plus'),
                emphasized: true,
                onTap: () => generatePlan(canSmartPlan),
              ),
            ),
          ],
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
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              DateUtils.isSameDay(day, DateTime.now())
                  ? context.t('today')
                  : context.t('day_plan'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            Text(
              MaterialLocalizations.of(context).formatMediumDate(day),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (featured != null)
          _PlannerMealCard(
            day: day,
            slot: featured.slot,
            meal: featured.meal,
            recipe: featured.recipe,
            featured: true,
            guiltyPleasure: hasGuiltyPleasure(featured.meal, overrides),
            onOpen: () =>
                context.push('/recipes/${featured.meal['recipe_id']}'),
            onReplace: () => replaceMeal(day, featured.slot, featured.meal),
            onDelete: () => removeMeal(featured.meal, meals),
            onGuiltyPleasure: () => changeGuiltyPleasure(featured.meal),
          ),
        for (final slot in slots)
          if (featured == null || slot != featured.slot) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final item = plannedToday
                    .where((value) => value.slot == slot)
                    .firstOrNull;
                return _PlannerMealCard(
                  day: day,
                  slot: slot,
                  meal: item?.meal,
                  recipe: item?.recipe,
                  featured: false,
                  guiltyPleasure: item == null
                      ? false
                      : hasGuiltyPleasure(item.meal, overrides),
                  onOpen: () => item == null
                      ? addMeal(day, slot)
                      : context.push('/recipes/${item.meal['recipe_id']}'),
                  onReplace: item == null
                      ? null
                      : () => replaceMeal(day, slot, item.meal),
                  onDelete: item == null
                      ? null
                      : () => removeMeal(item.meal, meals),
                  onGuiltyPleasure: item == null
                      ? null
                      : () => changeGuiltyPleasure(item.meal),
                );
              },
            ),
          ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            context.t('upcoming_days'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: upcoming.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = upcoming[index];
                return _UpcomingMealCard(
                  day: item.day,
                  meal: item.meal,
                  recipe: item.recipe,
                  onTap: () =>
                      context.push('/recipes/${item.meal['recipe_id']}'),
                );
              },
            ),
          ),
        ],
        if (selected != null) ...[
          const SizedBox(height: 20),
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
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.start,
    required this.selected,
    required this.onSelected,
  });

  final DateTime start;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == index,
              label: localizations.formatFullDate(
                start.add(Duration(days: index)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelected(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    children: [
                      Text(
                        localizations.narrowWeekdays[start
                                .add(Duration(days: index))
                                .weekday %
                            7],
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                        child: Text(
                          '${start.add(Duration(days: index)).day}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: selected == index
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child:
                            DateUtils.isSameDay(
                              start.add(Duration(days: index)),
                              today,
                            )
                            ? Text(
                                context.t('today'),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.planned,
    required this.emptyDays,
    required this.progress,
    required this.onComplete,
  });

  final int planned;
  final int emptyDays;
  final double progress;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => InformationPanel(
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const EatMeIcon(EatMeGlyph.utensils, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('planned_meals_count', {'count': planned}),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    context.t('days_to_complete', {'count': emptyDays}),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onComplete,
              child: Text(context.t('complete')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(value: progress, minHeight: 5),
        ),
      ],
    ),
  );
}

class _PlannerMealCard extends StatelessWidget {
  const _PlannerMealCard({
    required this.day,
    required this.slot,
    required this.meal,
    required this.recipe,
    required this.featured,
    required this.guiltyPleasure,
    required this.onOpen,
    this.onReplace,
    this.onDelete,
    this.onGuiltyPleasure,
  });

  final DateTime day;
  final String slot;
  final Json? meal;
  final Json? recipe;
  final bool featured;
  final bool guiltyPleasure;
  final VoidCallback onOpen;
  final VoidCallback? onReplace;
  final VoidCallback? onDelete;
  final VoidCallback? onGuiltyPleasure;

  @override
  Widget build(BuildContext context) {
    final hasMeal = meal != null;
    final title = hasMeal
        ? labelOf(recipe?['title'] ?? '', context)
        : context.t('add_meal');
    return InformationPanel(
      tinted: featured,
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('planner-slot-$slot'),
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(featured ? 14 : 10),
          child: Row(
            children: [
              if (hasMeal)
                FoodImage(
                  id: '${meal!['recipe_id']}',
                  imageUrl: '${recipe?['image_url'] ?? ''}',
                  width: featured ? 104 : 52,
                  height: featured ? 92 : 52,
                  radius: featured ? 18 : 14,
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const EatMeIcon(EatMeGlyph.plus, size: 22),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(slot).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.6,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: featured ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: featured
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    if (hasMeal) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${recipe?['minutes'] ?? '—'} min · ${meal!['servings']} ${context.t('servings')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (guiltyPleasure)
                        Text(
                          context.t('guilty_pleasure'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                    ],
                  ],
                ),
              ),
              if (hasMeal)
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'replace') onReplace?.call();
                    if (action == 'delete') onDelete?.call();
                    if (action == 'guilty_pleasure') onGuiltyPleasure?.call();
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
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingMealCard extends StatelessWidget {
  const _UpcomingMealCard({
    required this.day,
    required this.meal,
    required this.recipe,
    required this.onTap,
  });

  final DateTime day;
  final Json meal;
  final Json? recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 270,
    child: InformationPanel(
      tinted: false,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              FoodImage(
                id: '${meal['recipe_id']}',
                imageUrl: '${recipe?['image_url'] ?? ''}',
                width: 92,
                height: 92,
                radius: 17,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MaterialLocalizations.of(context).formatShortDate(day),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labelOf(recipe?['title'] ?? '', context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${recipe?['minutes'] ?? '—'} min'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PlannerActionTile extends StatelessWidget {
  const _PlannerActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final EatMeGlyph icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = emphasized
        ? scheme.primaryContainer
        : scheme.surfaceContainer;
    final foreground = emphasized ? scheme.primary : scheme.onSurface;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 74),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EatMeIcon(icon, size: 24, color: foreground),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
