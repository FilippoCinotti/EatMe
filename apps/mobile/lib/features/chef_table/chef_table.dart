import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../fridge/fridge.dart';

class ChefTablePage extends ConsumerWidget {
  const ChefTablePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final now = DateUtils.dateOnly(DateTime.now());
    final soon = state.inventory
        .where(
          (b) =>
              b.usable &&
              b.expiryDate != null &&
              b.expiryDate!.difference(now).inDays >= 0 &&
              b.expiryDate!.difference(now).inDays <= 2,
        )
        .take(3)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('hello', {'name': state.profile['name'] as String? ?? ''}),
        ),
        actions: [
          IconButton(
            tooltip: context.t('recipe_library'),
            onPressed: () => context.push('/recipe-library'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          Text(
            context.t('chef_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.error != null)
            StatusNote(
              text: context.t(
                state.offline ? 'offline_inventory' : state.error!,
              ),
              warning: true,
            ),
          if (soon.isNotEmpty) ...[
            SectionHeading(
              title: context.t('use_these_first'),
              actionLabel: context.t('view_all'),
              onAction: () => context.go('/fridge'),
            ),
            Card(
              child: Column(
                children: [
                  for (final batch in soon)
                    ListTile(
                      leading: FoodMark(food: batch.food),
                      title: Text(localized(batch.food.name, context.language)),
                      subtitle: Text(
                        '${batch.quantity} ${batch.food.unit} · ${expiryLabel(context, batch)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => sheet(context, BatchSheet(batch: batch)),
                    ),
                ],
              ),
            ),
          ],
          SectionHeading(title: context.t('today_pick')),
          if (state.inventory.isEmpty)
            EmptyMessage(
              title: context.t('start_with_fridge'),
              body: context.t('empty_fridge_body'),
              action: FilledButton(
                onPressed: state.offline
                    ? null
                    : () => sheet(context, const AddFoodSheet()),
                child: Text(context.t('add_food')),
              ),
            )
          else if (state.recommendations.isEmpty)
            EmptyMessage(
              title: context.t('no_recipes'),
              body: context.t('no_recipes_body'),
            )
          else
            RecipeCard(
              recommendation: state.recommendations.first,
              featured: true,
            ),
          SectionHeading(title: context.t('cooking_your_way')),
          TextButton.icon(onPressed: () => context.push('/recipe-library?favorites=true'), icon: const Icon(Icons.favorite_outline), label: Text(context.t('favorites'))),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in [
                  'for_you',
                  'quick',
                  'use_soon',
                  'no_shopping',
                  'health_first',
                  'plant_based',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(switch (mode) {
                        'quick' => Icons.schedule,
                        'use_soon' => Icons.kitchen_outlined,
                        'no_shopping' => Icons.shopping_bag_outlined,
                        'health_first' => Icons.eco_outlined,
                        _ => Icons.auto_awesome_outlined,
                      }, size: 18),
                      label: Text(context.t(mode)),
                      selected: state.mode == mode,
                      onSelected: state.offline
                          ? null
                          : (_) => ref
                                .read(appProvider.notifier)
                                .refresh(mode: mode),
                    ),
                  ),
              ],
            ),
          ),
          if (state.recommendations.length > 1) ...[
            SectionHeading(title: context.t('also_for_you')),
            for (final recommendation in state.recommendations.skip(1))
              RecipeCard(recommendation: recommendation),
          ],
          if (state.leftovers.isNotEmpty) ...[
            SectionHeading(
              title: context.t('prepared_meals'),
              actionLabel: context.t('view_all'),
              onAction: () => context.push('/leftovers'),
            ),
            for (final meal in state.leftovers.take(2))
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.takeout_dining_outlined),
                  title: Text(
                    localized(
                      Map<String, dynamic>.from(meal['recipe_title'] as Map),
                      context.language,
                    ),
                  ),
                  subtitle: Text(
                    '${meal['remaining']} ${context.t('servings')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/leftovers'),
                ),
              ),
          ],
          SectionHeading(title: context.t('your_kitchen')),
          for (final item in [
            ('meal_planner', '/planner', Icons.calendar_month_outlined),
            ('shopping_list', '/shopping', Icons.shopping_bag_outlined),
            ('recipe_library', '/recipe-library', Icons.menu_book_outlined),
          ])
            Card(
              child: ListTile(
                leading: IconBadge(item.$3),
                title: Text(context.t(item.$1)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(item.$2),
              ),
            ),
        ],
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recommendation,
    this.featured = false,
  });
  final Recommendation recommendation;
  final bool featured;
  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final meta = context.t('recipe_meta', {
      'minutes': r.recipe.minutes,
      'available': r.available,
      'total': r.total,
    });
    if (!featured) {
      return Card(
        child: ListTile(
          leading: FoodImage(
            id: r.recipe.id,
            width: 64,
            height: 64,
            radius: 14,
          ),
          title: Text(localized(r.recipe.title, context.language)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(meta), if (r.warnings.isNotEmpty) StatusNote(text: context.t('preference_warning'))]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/recipes/${r.recipe.id}'),
        ),
      );
    }
    return Card(
      child: InkWell(
        onTap: () => context.push('/recipes/${r.recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoodImage(id: r.recipe.id, height: 210, radius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localized(r.recipe.title, context.language),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 17,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meta,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (r.useSoon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.t('uses_expiring', {'count': r.useSoon.length}),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  if (r.warnings.isNotEmpty)
                    StatusNote(text: context.t('preference_warning')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
