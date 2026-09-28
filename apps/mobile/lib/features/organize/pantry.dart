import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

/// Household basics (oil, salt-like staples, spices…) that EatMe+ assumes are
/// always on hand: they complete recipes without being tracked in Fridge.
class PantryPage extends ConsumerStatefulWidget {
  const PantryPage({super.key});
  @override
  ConsumerState<PantryPage> createState() => _PantryState();
}

class _PantryState extends ResourceState<PantryPage> {
  @override
  String get path => '/pantry';
  Set<String>? selected;
  final extra = <Food>[];

  Set<String> get current =>
      selected ??
      {for (final id in (data?['food_ids'] as List? ?? const [])) '$id'};

  Future<void> addFood() async {
    final food = await chooseFood(context, ref.read(appProvider).foods);
    if (food == null || !mounted) return;
    setState(() {
      selected = {...current, food.id};
      if (!options.any((option) => option.id == food.id)) extra.add(food);
    });
  }

  List<Food> get options {
    final seen = <String>{};
    return [
      for (final raw in [
        ...records(data?['items']),
        ...records(data?['suggestions']),
      ])
        if (seen.add(raw['id'] as String)) Food.fromJson(raw),
      ...extra.where((food) => seen.add(food.id)),
    ];
  }

  Future<void> save() async {
    await command({
      'action': 'set',
      'food_ids': [
        for (final food in options)
          if (current.contains(food.id)) food.id,
      ],
      'expected_version': data?['version'] ?? 0,
    });
    selected = null;
    extra.clear();
    await ref.read(appProvider.notifier).refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('pantry_saved'))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('pantry_staples'))),
    body: content([
      Text(
        context.t('pantry_intro'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(context.t('pantry_body')),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final food in options)
            FilterChip(
              key: ValueKey('pantry-${food.id}'),
              label: Text(localized(food.name, context.language)),
              selected: current.contains(food.id),
              onSelected: (value) => setState(
                () => selected = value
                    ? {...current, food.id}
                    : ({...current}..remove(food.id)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      AsyncAction(
        label: context.t('pantry_add_other'),
        secondary: true,
        action: addFood,
      ),
      const SizedBox(height: 10),
      AsyncAction(
        key: const ValueKey('save-pantry'),
        label: context.t('save'),
        action: save,
      ),
    ]),
  );
}
