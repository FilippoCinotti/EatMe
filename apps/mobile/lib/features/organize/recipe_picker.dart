import 'package:flutter/material.dart';

import '../../core/localization.dart';
import '../../core/models.dart';
import 'shared.dart';

bool recipeFitsMeal(Json recipe, String slot) {
  final types = List<String>.from(recipe['meal_types'] as List? ?? const []);
  return types.contains(slot) || (slot == 'snack' && types.contains('merenda'));
}

List<Json> recipesForMeal(
  List<Json> recipes,
  List<Food> foods,
  String slot,
  String query,
  String language,
) {
  final term = query.trim().toLowerCase();
  final names = {
    for (final food in foods) food.id: localized(food.name, language),
  };
  final matching = recipes.where((recipe) {
    if (term.isEmpty) return true;
    final title = recipe['title'];
    if ((title is Map
            ? localized(Map<String, dynamic>.from(title), language)
            : '$title')
        .toLowerCase()
        .contains(term))
      return true;
    return records(recipe['ingredients']).any((ingredient) {
      final name =
          ingredient['name'] ??
          ingredient['food']?['name'] ??
          names[ingredient['food_id']] ??
          '';
      return (name is Map
              ? localized(Map<String, dynamic>.from(name), language)
              : '$name')
          .toLowerCase()
          .contains(term);
    });
  }).toList();
  return [
    ...matching.where((recipe) => recipeFitsMeal(recipe, slot)),
    ...matching.where((recipe) => !recipeFitsMeal(recipe, slot)),
  ];
}

class RecipePicker extends StatefulWidget {
  const RecipePicker({
    super.key,
    required this.recipes,
    required this.foods,
    required this.slot,
  });
  final List<Json> recipes;
  final List<Food> foods;
  final String slot;

  @override
  State<RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<RecipePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final items = recipesForMeal(
      widget.recipes,
      widget.foods,
      widget.slot,
      query,
      context.language,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(widget.slot),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('planner-recipe-search'),
                    decoration: InputDecoration(
                      hintText: context.t('recipe_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(context.t('planner_no_recipes')))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final recipe = items[index];
                        final fits = recipeFitsMeal(recipe, widget.slot);
                        final heading =
                            index == 0 ||
                            recipeFitsMeal(items[index - 1], widget.slot) !=
                                fits;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (heading)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Text(
                                  context.t(
                                    fits
                                        ? 'planner_meal_recipes'
                                        : 'planner_other_recipes',
                                  ),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ListTile(
                              title: Text(labelOf(recipe['title'], context)),
                              subtitle: Text('${recipe['minutes']} min'),
                              onTap: () => Navigator.pop(context, recipe),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MealTarget {
  const MealTarget(this.day, this.slot);
  final DateTime day;
  final String slot;
}

class MealScheduleSheet extends StatefulWidget {
  const MealScheduleSheet({
    super.key,
    required this.initialDay,
    required this.title,
  });
  final DateTime initialDay;
  final String title;

  @override
  State<MealScheduleSheet> createState() => _MealScheduleSheetState();
}

class _MealScheduleSheetState extends State<MealScheduleSheet> {
  late DateTime day = widget.initialDay;
  String? slot;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('plan_this_recipe'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(widget.title),
        const SizedBox(height: 16),
        ListTile(
          key: const ValueKey('schedule-day'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: Text(context.t('planner_choose_day')),
          subtitle: Text(context.displayDate(day)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: day,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (picked != null && mounted) setState(() => day = picked);
          },
        ),
        const SizedBox(height: 12),
        Text(context.t('planner_choose_meal')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final value in ['breakfast', 'lunch', 'snack', 'dinner'])
              ChoiceChip(
                key: ValueKey('schedule-$value'),
                label: Text(context.t(value)),
                selected: slot == value,
                onSelected: (_) => setState(() => slot = value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('schedule-confirm'),
            onPressed: slot == null
                ? null
                : () => Navigator.pop(context, MealTarget(day, slot!)),
            child: Text(context.t('plan_this')),
          ),
        ),
      ],
    ),
  );
}
