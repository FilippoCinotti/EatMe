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
        title: Text(context.t('eatme')),
        actions: [
          IconButton(
            tooltip: context.t('profile'),
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          Text(
            context.t('hello', {
              'name': state.profile['name'] as String? ?? '',
            }),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.t('dinner_question'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined),
                label: Text(context.t('meal_planner')),
                onPressed: () => context.push('/planner'),
              ),
              ActionChip(
                avatar: const Icon(Icons.shopping_bag_outlined),
                label: Text(context.t('shopping_list')),
                onPressed: () => context.push('/shopping'),
              ),
              ActionChip(
                avatar: const Icon(Icons.book_outlined),
                label: Text(context.t('recipe_library')),
                onPressed: () => context.push('/recipe-library'),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
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
          if (state.error != null)
            StatusNote(
              text: context.t(
                state.offline ? 'offline_inventory' : state.error!,
              ),
              warning: true,
            ),
          if (soon.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              context.t('use_these_first'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: soon
                  .map(
                    (b) => ActionChip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(localized(b.food.name, context.language)),
                      onPressed: () => sheet(context, BatchSheet(batch: b)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 28),
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
          else ...[
            RecipeCard(
              recommendation: state.recommendations.first,
              featured: true,
            ),
            const SizedBox(height: 28),
            Text(
              context.t('also_for_you'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final recommendation in state.recommendations.skip(1))
              RecipeCard(recommendation: recommendation),
          ],
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
    final scheme = Theme.of(context).colorScheme;
    final meta = context.t('recipe_meta', {
      'minutes': r.recipe.minutes,
      'available': r.available,
      'total': r.total,
    });
    if (!featured) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        title: Text(localized(r.recipe.title, context.language)),
        subtitle: Text(meta),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => context.push('/recipes/${r.recipe.id}'),
      );
    }
    return Material(
      color: scheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${r.recipe.id}'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('today_pick'),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 28),
              Icon(Icons.ramen_dining, size: 72, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                localized(r.recipe.title, context.language),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(meta),
              if (r.useSoon.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(context.t('uses_expiring', {'count': r.useSoon.length})),
              ],
              if (r.warnings.isNotEmpty)
                StatusNote(text: context.t('preference_warning')),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    context.t('view_recipe'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, color: scheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
