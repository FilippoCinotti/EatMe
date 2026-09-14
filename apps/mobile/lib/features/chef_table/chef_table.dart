import 'recipe_favorite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../fridge/fridge.dart';

class ChefTablePage extends ConsumerStatefulWidget {
  const ChefTablePage({super.key});
  @override
  ConsumerState<ChefTablePage> createState() => _ChefTablePageState();
}

class _ChefTablePageState extends ConsumerState<ChefTablePage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final now = DateUtils.dateOnly(DateTime.now());
    final soon =
        state.inventory
            .where(
              (b) =>
                  b.usable &&
                  b.expiryDate != null &&
                  b.expiryDate!.difference(now).inDays >= 0 &&
                  b.expiryDate!.difference(now).inDays <= 3,
            )
            .toList()
          ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    final recommendations = state.recommendations
        .where(
          (r) =>
              localized(
                r.recipe.title,
                context.language,
              ).toLowerCase().contains(query.toLowerCase()) ||
              r.recipe.ingredients.any(
                (i) => state.foods.any(
                  (f) =>
                      f.id == i['food_id'] &&
                      localized(
                        f.name,
                        context.language,
                      ).toLowerCase().contains(query.toLowerCase()),
                ),
              ),
        )
        .toList();
    final pick = recommendations.firstOrNull;
    final pickSoon = pick == null
        ? null
        : soon
              .where((batch) => pick.useSoon.contains(batch.food.id))
              .firstOrNull;
    return Scaffold(
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          EditorialHeader(
            eyebrow: context.t('chef_eyebrow'),
            title: context.t('chef_table'),
            subtitle: context.t('chef_editorial'),
            actions: [
              RoundAction(
                icon: EatMeGlyph.bell,
                label: context.t('notifications'),
                onPressed: () => context.push('/notifications'),
              ),
              RoundAction(
                icon: EatMeGlyph.userRound,
                label: context.t('profile'),
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
          SearchPill(
            hint: context.t('recipe_search_hint'),
            onChanged: (value) => setState(() => query = value),
            onFilter: () => sheet(context, const ChefFilters()),
          ),
          const SizedBox(height: 20),
          if (state.error != null)
            StatusNote(
              text: context.t(
                state.offline ? 'offline_inventory' : state.error!,
              ),
              warning: true,
            ),
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
          else if (pick == null)
            EmptyMessage(
              title: context.t('no_recipes'),
              body: context.t('no_recipes_body'),
            )
          else ...[
            RecipeCard(recommendation: pick, featured: true),
            const SizedBox(height: 16),
            InformationPanel(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('why_picked'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _Reason(
                    icon: EatMeGlyph.house,
                    text: context.t('ingredients_at_home', {
                      'available': pick.available,
                      'total': pick.total,
                    }),
                  ),
                  if (pick.useSoon.isNotEmpty)
                    _Reason(
                      icon: EatMeGlyph.clockAlert,
                      text: pickSoon == null
                          ? context.t('uses_expiring', {
                              'count': pick.useSoon.length,
                            })
                          : context.t('use_soon_named', {
                              'food': localized(
                                pickSoon.food.name,
                                context.language,
                              ),
                              'date': expiryLabel(context, pickSoon),
                            }),
                    ),
                  _Reason(
                    icon: EatMeGlyph.timer,
                    text: context.t('minutes_value', {
                      'minutes': pick.recipe.minutes,
                    }),
                  ),
                  if (pick.warnings.isNotEmpty)
                    StatusNote(
                      text: context.t('preference_warning'),
                      warning: true,
                    ),
                ],
              ),
            ),
          ],
          if (soon.isNotEmpty) ...[
            SectionHeading(
              title: context.t('use_these_first'),
              actionLabel: context.t('view_all'),
              onAction: () => context.push('/expiry'),
            ),
            HorizontalFoodRail(
              children: [
                for (final batch in soon.take(6))
                  FoodPhotoCard(
                    id: batch.food.id,
                    photoId: batch.food.photoId,
                    title: localized(batch.food.name, context.language),
                    subtitle: '${batch.quantity} ${batch.food.unit}',
                    imageHeight: 110,
                    badge: StatusBadge(
                      label: expiryLabel(context, batch),
                      icon: EatMeGlyph.clock,
                    ),
                    onTap: () => sheet(context, BatchSheet(batch: batch)),
                  ),
              ],
            ),
          ],
          if (pick != null) ...[
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final cook = FilledButton.icon(
                  onPressed: () => context.push('/recipes/${pick.recipe.id}'),
                  icon: const EatMeIcon(EatMeGlyph.chefHat, size: 20),
                  label: Text(context.t('cook_now')),
                );
                final alternatives = OutlinedButton.icon(
                  onPressed: () => context.push('/recipe-library'),
                  icon: const EatMeIcon(EatMeGlyph.listFilter, size: 20),
                  label: Text(context.t('see_alternatives')),
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [cook, const SizedBox(height: 10), alternatives],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 6, child: cook),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: alternatives),
                  ],
                );
              },
            ),
          ],
          if (recommendations.length > 1) ...[
            SectionHeading(title: context.t('also_for_you')),
            for (final recommendation in recommendations.skip(1))
              RecipeCard(recommendation: recommendation),
          ],
          SectionHeading(
            title: context.t('your_kitchen'),
            actionLabel: context.t('view_all'),
            onAction: () => sheet(context, const _KitchenToolsSheet()),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in [
                  (
                    'favorites',
                    '/recipe-library?favorites=true',
                    EatMeGlyph.heart,
                  ),
                  ('leftovers', '/leftovers', EatMeGlyph.packageOpen),
                  ('meal_planner', '/planner', EatMeGlyph.calendarDays),
                ]) ...[
                  CompactShortcut(
                    title: context.t(item.$1),
                    icon: item.$3,
                    onTap: () => context.push(item.$2),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.text});
  final EatMeGlyph icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EatMeIcon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 2,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class ChefFilters extends ConsumerStatefulWidget {
  const ChefFilters({super.key});
  @override
  ConsumerState<ChefFilters> createState() => _ChefFiltersState();
}

class _ChefFiltersState extends ConsumerState<ChefFilters> {
  late String mode = ref.read(appProvider).mode;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
    children: [
      Text(
        context.t('filters'),
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 6),
      Text(
        context.t('cooking_your_way'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      for (final value in [
        'for_you',
        'quick',
        'use_soon',
        'no_shopping',
        'health_first',
        'plant_based',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EatMeSelectionRow(
            icon: switch (value) {
              'for_you' => EatMeGlyph.sparkles,
              'quick' => EatMeGlyph.timer,
              'use_soon' => EatMeGlyph.clockAlert,
              'no_shopping' => EatMeGlyph.refrigerator,
              'health_first' => EatMeGlyph.heartPulse,
              _ => EatMeGlyph.sprout,
            },
            title: context.t(value),
            subtitle: context.t('mode_description_$value'),
            selected: mode == value,
            onTap: () => setState(() => mode = value),
          ),
        ),
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, constraints) {
          final reset = OutlinedButton(
            onPressed: () => setState(() => mode = 'for_you'),
            child: Text(context.t('reset_filters')),
          );
          final apply = AsyncAction(
            label: context.t('apply_filters'),
            enabled: !ref.watch(appProvider).offline,
            action: () async {
              await ref.read(appProvider.notifier).refresh(mode: mode);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          );
          if (constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(16) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [reset, const SizedBox(height: 10), apply],
            );
          }
          return Row(
            children: [
              Expanded(flex: 4, child: reset),
              const SizedBox(width: 10),
              Expanded(flex: 6, child: apply),
            ],
          );
        },
      ),
    ],
  );
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/recipes/${r.recipe.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FoodImage(id: r.recipe.id, width: 70, height: 70, radius: 18),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localized(r.recipe.title, context.language),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meta,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (r.warnings.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          StatusBadge(
                            label: context.t('preference_warning'),
                            icon: EatMeGlyph.circleAlert,
                            warning: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const EatMeIcon(EatMeGlyph.chevronRight),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return HeroRecipeCard(
      imageId: r.recipe.id,
      title: localized(r.recipe.title, context.language),
      onTap: () => context.push('/recipes/${r.recipe.id}'),
      badge: StatusBadge(
        label: context.t('best_match'),
        icon: EatMeGlyph.sparkles,
        emphasis: true,
      ),
      action: RecipeFavorite(recipeId: r.recipe.id),
      metadata: [
        StatusBadge(
          label: context.t('minutes', {'minutes': r.recipe.minutes}),
          icon: EatMeGlyph.clock,
        ),
        StatusBadge(
          label: context.t('ingredients_at_home', {
            'available': r.available,
            'total': r.total,
          }),
          icon: EatMeGlyph.house,
        ),
      ],
      footer: r.warnings.isEmpty
          ? null
          : StatusNote(text: context.t('preference_warning'), warning: true),
    );
  }
}

class _KitchenToolsSheet extends StatelessWidget {
  const _KitchenToolsSheet();

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
    children: [
      Text(
        context.t('your_kitchen'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      for (final item in [
        ('favorites', '/recipe-library?favorites=true', EatMeGlyph.heart),
        ('leftovers', '/leftovers', EatMeGlyph.packageOpen),
        ('meal_planner', '/planner', EatMeGlyph.calendarDays),
        ('shopping_list', '/shopping', EatMeGlyph.shoppingBasket),
        ('recipe_library', '/recipe-library', EatMeGlyph.bookOpen),
        ('import_recipe', '/recipe-import', EatMeGlyph.sparkles),
      ])
        SettingRow(
          title: context.t(item.$1),
          icon: item.$3,
          onTap: () {
            Navigator.pop(context);
            context.push(item.$2);
          },
        ),
    ],
  );
}
