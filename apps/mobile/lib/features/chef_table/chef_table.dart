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
    final soon = state.inventory.where((b) => b.usable && b.expiryDate != null && b.expiryDate!.difference(now).inDays >= 0 && b.expiryDate!.difference(now).inDays <= 3).toList()
      ..sort((a,b) => a.expiryDate!.compareTo(b.expiryDate!));
    final recommendations = state.recommendations.where((r) => localized(r.recipe.title, context.language).toLowerCase().contains(query.toLowerCase()) || r.recipe.ingredients.any((i) => state.foods.any((f) => f.id == i['food_id'] && localized(f.name, context.language).toLowerCase().contains(query.toLowerCase())))).toList();
    final pick = recommendations.firstOrNull;
    return Scaffold(body: PageBody(onRefresh: () => ref.read(appProvider.notifier).refresh(), children: [
      EditorialHeader(eyebrow: context.t('chef_eyebrow'), title: context.t('chef_table'), subtitle: context.t('chef_editorial'), actions: [
        RoundAction(icon: Icons.notifications_none, label: context.t('notifications'), onPressed: () => context.push('/notifications')),
        RoundAction(icon: Icons.person_outline, label: context.t('profile'), onPressed: () => context.go('/profile')),
      ]),
      SearchPill(hint: context.t('recipe_search_hint'), onChanged: (value) => setState(() => query = value), onFilter: () => sheet(context, const ChefFilters())),
      const SizedBox(height: 20),
      if (state.error != null) StatusNote(text: context.t(state.offline ? 'offline_inventory' : state.error!), warning: true),
      if (state.inventory.isEmpty) EmptyMessage(title: context.t('start_with_fridge'), body: context.t('empty_fridge_body'), action: FilledButton(onPressed: state.offline ? null : () => sheet(context, const AddFoodSheet()), child: Text(context.t('add_food'))))
      else if (pick == null) EmptyMessage(title: context.t('no_recipes'), body: context.t('no_recipes_body'))
      else ...[
        RecipeCard(recommendation: pick, featured: true),
        const SizedBox(height: 16),
        InformationPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t('why_picked'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _Reason(icon: Icons.kitchen_outlined, text: context.t('ingredients_at_home', {'available': pick.available, 'total': pick.total})),
          if (pick.useSoon.isNotEmpty) _Reason(icon: Icons.schedule, text: context.t('uses_expiring', {'count': pick.useSoon.length})),
          _Reason(icon: Icons.timer_outlined, text: context.t('minutes_value', {'minutes': pick.recipe.minutes})),
          if (pick.warnings.isNotEmpty) StatusNote(text: context.t('preference_warning'), warning: true),
        ])),
      ],
      if (soon.isNotEmpty) ...[
        SectionHeading(title: context.t('use_these_first'), actionLabel: context.t('view_all'), onAction: () => context.push('/expiry')),
        HorizontalFoodRail(children: [for (final batch in soon.take(6)) FoodPhotoCard(id: batch.food.id, photoId: batch.food.photoId, title: localized(batch.food.name, context.language), subtitle: '${batch.quantity} ${batch.food.unit}', imageHeight: 110, badge: StatusBadge(label: expiryLabel(context, batch), icon: Icons.schedule), onTap: () => sheet(context, BatchSheet(batch: batch)))]),
      ],
      if (pick != null) ...[
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () => context.push('/recipes/${pick.recipe.id}'), icon: const Icon(Icons.restaurant), label: Text(context.t('cook_now'))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => context.push('/recipe-library'), icon: const Icon(Icons.format_list_bulleted), label: Text(context.t('see_alternatives'))),
      ],
      if (recommendations.length > 1) ...[
        SectionHeading(title: context.t('also_for_you')),
        for (final recommendation in recommendations.skip(1)) RecipeCard(recommendation: recommendation),
      ],
      const SizedBox(height: 24),
      SettingsGroup(title: context.t('your_kitchen'), children: [
        for (final item in [
          ('favorites', '/recipe-library?favorites=true', Icons.favorite_outline),
          ('leftovers', '/leftovers', Icons.takeout_dining_outlined),
          ('meal_planner', '/planner', Icons.calendar_month_outlined),
          ('shopping_list', '/shopping', Icons.shopping_bag_outlined),
          ('recipe_library', '/recipe-library', Icons.menu_book_outlined),
        ]) SettingRow(title: context.t(item.$1), icon: item.$3, onTap: () => context.push(item.$2)),
      ]),
    ]));
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(text))]));
}

class ChefFilters extends ConsumerStatefulWidget {
  const ChefFilters({super.key});
  @override
  ConsumerState<ChefFilters> createState() => _ChefFiltersState();
}
class _ChefFiltersState extends ConsumerState<ChefFilters> {
  late String mode = ref.read(appProvider).mode;
  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(24, 8, 24, 28), children: [
    Text(context.t('cooking_your_way'), style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 20),
    for (final value in ['for_you','quick','use_soon','no_shopping','health_first','plant_based']) Padding(padding: const EdgeInsets.only(bottom: 10), child: Semantics(selected: mode == value, child: Material(color: mode == value ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text(context.t(value)), subtitle: Text(context.t('mode_description_$value')), trailing: Icon(mode == value ? Icons.check_circle : Icons.circle_outlined, color: Theme.of(context).colorScheme.primary), onTap: () => setState(() => mode = value))))),
    TextButton(onPressed: () => setState(() => mode = 'for_you'), child: Text(context.t('reset_filters'))),
    AsyncAction(label: context.t('apply_filters'), enabled: !ref.watch(appProvider).offline, action: () async { await ref.read(appProvider.notifier).refresh(mode: mode); if (context.mounted) { Navigator.pop(context); } }),
  ]);
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta),
              if (r.warnings.isNotEmpty)
                StatusNote(text: context.t('preference_warning')),
            ],
          ),
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
            Stack(children: [FoodImage(id: r.recipe.id, height: 250, radius: 0), Positioned(left: 16, top: 16, child: StatusBadge(label: context.t('today_pick'), icon: Icons.auto_awesome, emphasis: true))]),
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
