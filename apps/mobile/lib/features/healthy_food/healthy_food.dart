import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../fridge/fridge.dart';
import '../organize/shared.dart';
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

class _HealthyFoodPageState extends ResourceState<HealthyFoodPage> {
  @override
  String get path => "/preferences";
  bool favoritesOnly = false, savingFavorite = false;
  String query = '', group = 'all';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final favorites = (data?['data']?['favorite_foods'] as List? ?? []).toSet();
    final foods = state.foods
        .where(
          (food) =>
              (!favoritesOnly || favorites.contains(food.id)) &&
              (group == 'all' || food.group == group) &&
              localized(
                food.name,
                context.language,
              ).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final groups = state.foods.map((food) => food.group).toSet().toList()
      ..sort();
    final featured = state.foods
        .where((food) => favorites.contains(food.id))
        .toList();
    return Scaffold(
      body: PageBody(
        children: [
          EditorialHeader(
            eyebrow: context.t('healthy_eyebrow'),
            title: context.t('healthy_editorial'),
            subtitle: context.t('healthy_support'),
            art: _DiscoveryArt(food: state.foods.firstOrNull),
            actions: [
              RoundAction(
                icon: EatMeGlyph.chartSpline,
                label: context.t('wellbeing'),
                onPressed: () => context.push('/wellbeing'),
              ),
              RoundAction(
                icon: EatMeGlyph.userRound,
                label: context.t('profile'),
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
          if (error != null) StatusNote(text: context.t(error!), warning: true),
          SearchPill(
            hint: context.t('search_food'),
            onChanged: (value) => setState(() => query = value),
            onFilter: () => sheet(
              context,
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: [
                  Text(
                    context.t('filters'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  SettingRow(
                    title: context.t('all_foods'),
                    icon: EatMeGlyph.libraryBig,
                    trailing: !favoritesOnly
                        ? EatMeIcon(
                            EatMeGlyph.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => favoritesOnly = false);
                      Navigator.pop(context);
                    },
                  ),
                  SettingRow(
                    title: context.t('favorites'),
                    icon: EatMeGlyph.heart,
                    trailing: favoritesOnly
                        ? EatMeIcon(
                            EatMeGlyph.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => favoritesOnly = true);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final value in ['all', ...groups])
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: CategoryTile(
                      label: context.t('food_group_$value'),
                      foodId:
                          (value == 'all'
                                  ? state.foods.firstOrNull
                                  : state.foods
                                        .where((f) => f.group == value)
                                        .firstOrNull)
                              ?.id ??
                          '',
                      selected: group == value,
                      icon: value == 'all' ? EatMeGlyph.libraryBig : null,
                      onTap: () => setState(() => group = value),
                    ),
                  ),
              ],
            ),
          ),
          if (featured.isNotEmpty &&
              !favoritesOnly &&
              query.isEmpty &&
              group == 'all') ...[
            SectionHeading(
              title: context.t('featured_for_you'),
              actionLabel: context.t('view_all'),
              onAction: () => setState(() => favoritesOnly = true),
            ),
            _FeaturedDiscoveryCard(
              food: featured.first,
              onTap: state.offline
                  ? null
                  : () => sheet(
                      context,
                      FoodAssessment(food: featured.first),
                    ),
            ),
            if (featured.length > 1) ...[
              const SizedBox(height: 14),
              HorizontalFoodRail(
                children: [
                  for (final food in featured.skip(1))
                    FoodPhotoCard(
                      id: food.id,
                      photoId: food.photoId,
                      title: localized(food.name, context.language),
                      subtitle: context.t('saved_by_you'),
                      imageHeight: 112,
                      onTap: state.offline
                          ? null
                          : () => sheet(context, FoodAssessment(food: food)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
          ],
          if (featured.isEmpty &&
              !favoritesOnly &&
              query.isEmpty &&
              group == 'all') ...[
            SectionHeading(title: context.t('start_discovering')),
            InformationPanel(
              child: SettingRow(
                title: context.t('save_foods_to_feature'),
                subtitle: context.t('save_foods_to_feature_body'),
                icon: EatMeGlyph.heart,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SectionHeading(
            title: context.t(favoritesOnly ? 'favorites' : 'full_catalog'),
          ),
          if (state.offline)
            StatusNote(text: context.t('online_required'), warning: true),
          if (foods.isEmpty)
            EmptyMessage(
              title: context.t('no_food_results'),
              body: context.t('try_another_search'),
            ),
          AdaptivePhotoGrid(
            children: [
              for (final food in foods)
                FoodPhotoCard(
                  id: food.id,
                  photoId: food.photoId,
                  title: localized(food.name, context.language),
                  subtitle: context.t('food_group_${food.group}'),
                  imageHeight: 136,
                  onTap: state.offline
                      ? null
                      : () => sheet(context, FoodAssessment(food: food)),
                  actionIcon: EatMeGlyph.heart,
                  actionEmphasis: favorites.contains(food.id),
                  actionLabel: context.t(
                    favorites.contains(food.id)
                        ? 'remove_favorite'
                        : 'add_favorite',
                  ),
                  onAction: state.offline || data == null || savingFavorite
                      ? null
                      : () => guard(() async {
                          setState(() => savingFavorite = true);
                          try {
                            await Mutation()
                                .send(ref.read(apiProvider), 'POST', '/foods', {
                                  'action': 'favorite',
                                  'food_id': food.id,
                                  'enabled': !favorites.contains(food.id),
                                });
                            await load();
                          } finally {
                            if (mounted) {
                              setState(() => savingFavorite = false);
                            }
                          }
                        }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          InformationPanel(
            child: SettingRow(
              title: context.t('diet_health'),
              subtitle: context.t('healthy_profile_hint'),
              icon: EatMeGlyph.shieldCheck,
              onTap: () => context.push('/profile/edit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedDiscoveryCard extends StatelessWidget {
  const _FeaturedDiscoveryCard({required this.food, required this.onTap});
  final Food food;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(
              id: food.id,
              photoId: food.photoId,
              width: double.infinity,
              height: 210,
              radius: 0,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('saved_by_you').toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          localized(food.name, context.language),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          context.t('featured_favorite_body'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: EatMeIcon(
                      EatMeGlyph.chevronRight,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FoodAssessment extends ConsumerStatefulWidget {
  const FoodAssessment({super.key, required this.food});
  final Food food;
  @override
  ConsumerState<FoodAssessment> createState() => _FoodAssessmentState();
}

class _FoodAssessmentState extends ConsumerState<FoodAssessment> {
  String tab = 'information';
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
      final food = Map<String, dynamic>.from(data['food'] as Map);
      final nutrition = data['nutrition'] as Map?;
      final values = nutrition?['values'] as Map? ?? {};
      final evidence = records(data['evidence']);
      final compatible = assessment['status'] == 'no_known_conflict';
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        children: [
          FoodImage(
            id: widget.food.id,
            photoId: widget.food.photoId,
            height: 220,
            radius: 22,
            fallback: Icons.eco_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            localized(widget.food.name, context.language),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            context.t(compatible ? 'no_known_conflict' : 'not_compatible'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final reason in records(assessment['reasons']))
            StatusNote(
              text: context.t(reason['code'] as String),
              warning: true,
            ),
          for (final warning in records(assessment['warnings']))
            StatusNote(text: context.t(warning['code'] as String)),
          StatusNote(text: context.t(assessment['notice'] as String)),
          EatMeTabStrip(
            values: [
              for (final value in ['information', 'nutrition', 'for_you'])
                (value, context.t(value)),
            ],
            selected: tab,
            onSelected: (value) => setState(() => tab = value),
          ),
          const SizedBox(height: 16),
          if (tab == 'for_you') ...[
            TextButton(
              onPressed: () => context.push('/profile/edit'),
              child: Text(context.t('edit_profile')),
            ),
          ],
          if (tab == 'nutrition') ...[
            if (values.isEmpty)
              StatusNote(text: context.t('nutrition_unavailable')),
            if (values.isNotEmpty)
              Text('${context.t('nutrition_basis')}: ${nutrition!['basis']}'),
            for (final entry in values.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('nutrient_${entry.key}')),
                trailing: Text(
                  '${entry.value['value']} ${entry.value['unit']}',
                ),
              ),
            if (nutrition?['source_url'] is String)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(nutrition!['source_url'] as String),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(context.t('read_source')),
              ),
            StatusNote(text: context.t('nutrition_score_unavailable')),
          ],
          if (tab == 'information') ...[
            SectionHeading(title: context.t('ingredients_allergens')),
            Text(localized(widget.food.name, context.language)),
            if (food['ingredient_status'] != 'known')
              StatusNote(text: context.t('unknown_ingredients'), warning: true),
            for (final allergen in (food['allergens'] as List? ?? []))
              ListTile(title: Text(context.t('allergen_$allergen'))),
            for (final allergen in (food['may_contain'] as List? ?? []))
              StatusNote(
                text:
                    '${context.t('may_contain')}: ${context.t('allergen_$allergen')}',
              ),
            StatusNote(text: context.t('check_package')),
            SectionHeading(title: context.t('scientific_evidence')),
            if (evidence.isEmpty)
              StatusNote(text: context.t('evidence_unavailable')),
            for (final item in evidence)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(item['claim'] as String),
                      Text('${item['publisher']} · ${item['published_date']}'),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(item['url'] as String),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(context.t('read_source')),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          AsyncAction(
            label: context.t('add_to_fridge'),
            action: () =>
                sheet(context, AddFoodSheet(initialFood: widget.food)),
          ),
        ],
      );
    },
  );
}

class _DiscoveryArt extends StatelessWidget {
  const _DiscoveryArt({required this.food});

  final Food? food;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned(
        right: -10,
        top: -10,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      ),
      if (food != null)
        Positioned(
          right: -4,
          bottom: 0,
          child: FoodImage(
            id: food!.id,
            photoId: food!.photoId,
            width: 92,
            height: 92,
            radius: 46,
          ),
        ),
      Positioned(
        left: 0,
        top: 2,
        child: Transform.rotate(
          angle: -.45,
          child: EatMeBrandMark(
            size: 34,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .7),
          ),
        ),
      ),
    ],
  );
}
