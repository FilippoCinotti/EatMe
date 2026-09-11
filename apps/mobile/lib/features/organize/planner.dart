import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});
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
  @override
  Future<void> load() async {
    await super.load();
    try {
      final result = await ref.read(apiProvider).request('GET', '/recipes');
      if (mounted)
        setState(() {
          recipes = records(result['items']);
          selected = records(
            data?['items'],
          ).where((p) => p['start_date'] == isoDay(start)).firstOrNull;
        });
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.code);
    }
  }

  Future<void> saveMeals(List<Json> meals) async {
    final result = await command({
      'action': 'save',
      'start_date': isoDay(start),
      'meals': meals,
      if (selected != null) 'id': selected!['id'],
      if (selected != null) 'expected_version': selected!['version'],
    });
    if (mounted && result['id'] != null) setState(() => selected = result);
  }

  Future<void> addMeal(DateTime day, String slot) async {
    final recipe = await showModalBottomSheet<Json>(
      context: context,
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
    if (recipe == null || !mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final meals = records(selected?['data']?['meals']);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('meal_planner'))),
      body: content([
        Text(
          context.t('week_at_a_glance'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
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
        AsyncAction(label: context.t('who_is_eating'), secondary: true, action: () async {
          final value = await chooseDiners(context, ref.read(apiProvider), participants);
          if (value != null && mounted) setState(() => participants = value);
        }),
        AsyncAction(
          label: context.t('generate_week'),
          action: () async {
            final result = await command({
              'action': 'generate',
              if (participants != null) 'participants': participants,
              'start_date': isoDay(start),
              'servings': 1,
              if (selected != null) 'id': selected!['id'],
              if (selected != null) 'expected_version': selected!['version'],
            });
            if (mounted && result['id'] != null)
              setState(() => selected = result);
          },
        ),
        const SizedBox(height: 8),
        if (selected != null)
          AsyncAction(
            label: context.t('build_shopping_list'),
            secondary: true,
            action: () async {
              await Mutation().send(
                ref.read(apiProvider),
                'POST',
                '/shopping',
                {'action': 'generate', 'plan_id': selected!['id']},
              );
              if (mounted) context.push('/shopping');
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
          for (final slot in ['breakfast', 'lunch', 'dinner', 'snack'])
            Builder(
              builder: (context) {
                final day = start.add(Duration(days: i));
                final meal = meals
                    .where((m) => m['date'] == isoDay(day) && m['slot'] == slot)
                    .firstOrNull;
                final recipe = recipes
                    .where((r) => r['id'] == meal?['recipe_id'])
                    .firstOrNull;
                return Card(
                  child: ListTile(
                    title: Text(context.t(slot)),
                    subtitle: meal == null
                        ? null
                        : Text(
                            '${labelOf(recipe?['title'] ?? '', context)} · ${meal['servings']}',
                          ),
                    trailing: meal == null
                        ? const Icon(Icons.add)
                        : PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'delete') {
                                await saveMeals(
                                  meals.where((m) => m != meal).toList(),
                                );
                              } else {
                                await addMeal(day, slot);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'replace',
                                child: Text(context.t('replace')),
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
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ]),
    );
  }
}
