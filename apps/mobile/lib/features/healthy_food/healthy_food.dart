import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class HealthyFoodPage extends ConsumerStatefulWidget {
  const HealthyFoodPage({super.key});
  @override
  ConsumerState<HealthyFoodPage> createState() => _HealthyFoodPageState();
}

class _HealthyFoodPageState extends ConsumerState<HealthyFoodPage> {
  String query = '', group = 'all';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final foods = state.foods
        .where(
          (food) =>
              (group == 'all' || food.group == group) &&
              localized(
                food.name,
                context.language,
              ).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final groups = state.foods.map((food) => food.group).toSet().toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('healthy_food'))),
      body: PageBody(
        children: [
          Text(
            context.t('discover_food'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: context.t('search_food'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in ['all', ...groups])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(context.t('food_group_$value')),
                      selected: group == value,
                      onSelected: (_) => setState(() => group = value),
                    ),
                  ),
              ],
            ),
          ),
          SectionHeading(title: context.t('explore_foods')),
          if (state.offline)
            StatusNote(text: context.t('online_required'), warning: true),
          if (foods.isEmpty)
            EmptyMessage(
              title: context.t('no_food_results'),
              body: context.t('try_another_search'),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 330 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 23
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final food in foods)
                    SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          onTap: state.offline
                              ? null
                              : () =>
                                    sheet(context, FoodAssessment(food: food)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FoodImage(
                                id: food.id,
                                height: columns == 2 ? 136 : 180,
                                radius: 0,
                                fallback: Icons.eco_outlined,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localized(food.name, context.language),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.t('food_group_${food.group}'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class FoodAssessment extends ConsumerStatefulWidget {
  const FoodAssessment({super.key, required this.food});
  final Food food;
  @override
  ConsumerState<FoodAssessment> createState() => _FoodAssessmentState();
}

class _FoodAssessmentState extends ConsumerState<FoodAssessment> {
  late Future<Json> future = load();
  Future<Json> load() => ref
      .read(apiProvider)
      .request('GET', '/foods/${widget.food.id}/compatibility');
  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusNote(
                text: context.t(
                  snapshot.error is ApiFailure
                      ? (snapshot.error as ApiFailure).code
                      : 'unknown_error',
                ),
                warning: true,
              ),
              FilledButton(
                onPressed: () => setState(() => future = load()),
                child: Text(context.t('retry')),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final data = snapshot.data!,
          assessment = Map<String, dynamic>.from(data['assessment'] as Map);
      final compatible = assessment['status'] == 'no_known_conflict';
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        children: [
          FoodImage(
            id: widget.food.id,
            height: 220,
            radius: 22,
            fallback: Icons.eco_outlined,
          ),
          const SizedBox(height: 20),
          Text(
            localized(widget.food.name, context.language),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Text(
            context.t('for_you'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.t(compatible ? 'no_known_conflict' : 'not_compatible'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: compatible
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          for (final reason in (assessment['reasons'] as List))
            StatusNote(
              text: context.t(reason['code'] as String),
              warning: true,
            ),
          for (final warning in (assessment['warnings'] as List))
            StatusNote(text: context.t(warning['code'] as String)),
          StatusNote(text: context.t(assessment['notice'] as String)),
          const Divider(),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.t('nutrition')),
            children: [StatusNote(text: context.t('nutrition_unavailable'))],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.t('ingredients_allergens')),
            children: [
              for (final allergen in (data['food']['allergens'] as List))
                ListTile(title: Text(context.t('allergen_$allergen'))),
              StatusNote(text: context.t('check_package')),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.t('scientific_evidence')),
            children: [StatusNote(text: context.t('evidence_unavailable'))],
          ),
        ],
      );
    },
  );
}
