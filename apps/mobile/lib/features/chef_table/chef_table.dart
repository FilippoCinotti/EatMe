import 'dart:async';
import 'dart:convert';

import 'recipe_favorite.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../fridge/fridge.dart';
import '../organize/guilty_pleasure.dart';
import '../onboarding/first_access_tour.dart';

class ChefTablePage extends ConsumerStatefulWidget {
  const ChefTablePage({super.key});
  @override
  ConsumerState<ChefTablePage> createState() => _ChefTablePageState();
}

class _ChefTablePageState extends ConsumerState<ChefTablePage> {
  String query = '';
  Timer? searchDebounce;
  List<Recommendation>? searchResults;
  String? searchError;
  bool searchLoading = false;
  int searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => openTourIfPending());
  }

  Future<void> openTourIfPending() async {
    final userId = ref.read(apiProvider).userId;
    if (userId == null || !await FirstAccessTour.isPending(userId)) return;
    if (mounted) context.push('/tour');
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  void updateSearch(String value) {
    searchDebounce?.cancel();
    final normalized = value.trim();
    final generation = ++searchGeneration;
    setState(() {
      query = value;
      searchError = null;
      searchLoading = normalized.isNotEmpty;
      if (normalized.isEmpty) searchResults = null;
    });
    if (normalized.isEmpty) return;
    searchDebounce = Timer(
      const Duration(milliseconds: 320),
      () => runSearch(normalized, generation),
    );
  }

  Future<void> runSearch(String value, int generation) async {
    try {
      final mode = ref.read(appProvider).mode;
      final uri = Uri(
        path: '/recommendations',
        queryParameters: {'mode': mode, 'query': value},
      );
      final response = await ref.read(apiProvider).request('GET', '$uri');
      final results = (response['items'] as List? ?? const [])
          .map(
            (item) =>
                Recommendation.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      if (!mounted || generation != searchGeneration) return;
      setState(() {
        searchResults = results;
        searchLoading = false;
        searchError = null;
      });
    } on ApiFailure catch (error) {
      if (!mounted || generation != searchGeneration) return;
      setState(() {
        searchResults = const [];
        searchLoading = false;
        searchError = error.code;
      });
    }
  }

  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Widget _build(BuildContext context) {
    final state = ref.watch(appProvider);
    final fullName = (state.profile['name'] as String? ?? '').trim();
    final name = fullName.isEmpty ? '' : fullName.split(RegExp(r'\s+')).first;
    final initials = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    final hour = DateTime.now().hour;
    final greetingKey = hour < 12
        ? 'good_morning'
        : hour < 18
        ? 'good_afternoon'
        : 'good_evening';
    final settings = Map<String, dynamic>.from(
      state.profile['settings'] as Map? ?? {},
    );
    final avatarMediaId = settings['avatar_media_id'] as String?;
    final assignments = (settings['diets'] as List? ?? const [])
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final activeDiets = state.diets
        .where(
          (diet) =>
              assignments.any((assignment) => assignment['diet_id'] == diet.id),
        )
        .toList();
    final hardRestrictionCount =
        (settings['allergies'] as List? ?? const []).length +
        (settings['intolerances'] as List? ?? const []).length +
        (settings['never_suggest'] as List? ?? const []).length;
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
    final normalizedQuery = query.trim().toLowerCase();
    final matchingRecommendations = normalizedQuery.isEmpty
        ? state.recommendations
        : searchResults ?? const <Recommendation>[];
    final pick = matchingRecommendations.firstOrNull;
    final hasNoSearchMatch =
        normalizedQuery.isNotEmpty &&
        !searchLoading &&
        searchError == null &&
        matchingRecommendations.isEmpty;
    final visibleRecommendations = matchingRecommendations;
    return Scaffold(
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          EditorialHeader(
            eyebrow: '',
            title: name.isEmpty
                ? context.t(greetingKey)
                : context.t('${greetingKey}_name', {'name': name}),
            subtitle: context.t('cooking_your_way'),
            actions: [
              RoundAction(
                icon: EatMeGlyph.bell,
                label: context.t('notifications'),
                onPressed: () => context.push('/notifications'),
              ),
              _ChefAvatarAction(
                mediaId: avatarMediaId,
                initials: initials,
                label: context.t('profile'),
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
          SearchPill(
            hint: context.t('recipe_search_hint'),
            onChanged: updateSearch,
            onFilter: () => sheet(context, const ChefFilters()),
          ),
          if (searchLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in [
                  'for_you',
                  'use_soon',
                  'quick',
                  'no_shopping',
                  'health_first',
                  'guilty_pleasure',
                ]) ...[
                  _ModePill(
                    label: context.t(value),
                    selected: state.mode == value,
                    onTap:
                        state.offline &&
                            !(value == 'guilty_pleasure' &&
                                state.guiltyPleasureActive)
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            final controller = ref.read(appProvider.notifier);
                            if (value == 'guilty_pleasure') {
                              final choice = await showGuiltyPleasureSheet(
                                context,
                                active: state.guiltyPleasureActive,
                              );
                              if (!mounted) return;
                              if (choice == 'off') {
                                await controller.disableGuiltyPleasure();
                              } else if (choice == 'meal' || choice == 'day') {
                                await controller.enableGuiltyPleasure(choice!);
                              }
                            } else {
                              await controller.setRecommendationMode(value);
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (state.guiltyPleasureActive) ...[
            InformationPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EatMeIcon(EatMeGlyph.sparkles, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('guilty_pleasure_tonight'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(context.t('guilty_pleasure_active_body')),
                        TextButton(
                          onPressed: () => ref
                              .read(appProvider.notifier)
                              .disableGuiltyPleasure(),
                          child: Text(context.t('turn_off')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (hasNoSearchMatch) ...[
            const SizedBox(height: 10),
            StatusNote(text: context.t('try_another_search')),
          ],
          if (searchError != null) ...[
            const SizedBox(height: 10),
            StatusNote(text: context.t(searchError!), warning: true),
          ],
          const SizedBox(height: 22),
          if (state.error != null)
            StatusNote(
              text: context.t(
                state.offline ? 'offline_inventory' : state.error!,
              ),
              warning: true,
            ),
          if (state.inventory.isEmpty && normalizedQuery.isEmpty)
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
          else if (pick == null && normalizedQuery.isEmpty)
            EmptyMessage(
              title: context.t('no_recipes'),
              body: context.t('no_recipes_body'),
            )
          else if (pick != null) ...[
            RecipeCard(
              recommendation: pick,
              featured: true,
              actions: _ChefRecipeActions(recipeId: pick.recipe.id),
              profileContext: _ProfileContext(
                diets: activeDiets,
                primaryDiet: settings['primary_diet'] as String?,
                hardRestrictionCount: hardRestrictionCount,
                unknownPolicy:
                    settings['unknown_ingredient_policy'] as String? ??
                    'strict',
                onManage: () => context.push('/diet-health'),
              ),
            ),
          ],
          if (normalizedQuery.isEmpty && soon.isNotEmpty) ...[
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
                    imageUrl: batch.food.imageUrl,
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
          if (visibleRecommendations.length > 1) ...[
            SectionHeading(title: context.t('also_for_you')),
            for (final recommendation in visibleRecommendations.skip(1))
              RecipeCard(recommendation: recommendation),
          ],
          if (normalizedQuery.isEmpty) ...[
            SectionHeading(
              title: context.t('your_kitchen'),
              actionLabel: context.t('view_all'),
              onAction: () => sheet(context, const _KitchenToolsSheet()),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in [
                      (
                        'favorites',
                        '/recipe-library?favorites=true',
                        EatMeGlyph.heart,
                      ),
                      ('leftovers', '/leftovers', EatMeGlyph.packageOpen),
                      ('meal_planner', '/plan', EatMeGlyph.calendarDays),
                    ]) ...[
                      CompactShortcut(
                        width:
                            132 *
                            (MediaQuery.textScalerOf(context).scale(15) / 15)
                                .clamp(1, 3),
                        title: context.t(item.$1),
                        icon: item.$3,
                        onTap: () => context.push(item.$2),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChefAvatarAction extends ConsumerStatefulWidget {
  const _ChefAvatarAction({
    required this.mediaId,
    required this.initials,
    required this.label,
    required this.onPressed,
  });

  final String? mediaId;
  final String initials, label;
  final VoidCallback onPressed;

  @override
  ConsumerState<_ChefAvatarAction> createState() => _ChefAvatarActionState();
}

class _ChefAvatarActionState extends ConsumerState<_ChefAvatarAction> {
  late Future<Json?> avatar;

  @override
  void initState() {
    super.initState();
    avatar = _load();
  }

  @override
  void didUpdateWidget(covariant _ChefAvatarAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) avatar = _load();
  }

  Future<Json?> _load() async {
    final mediaId = widget.mediaId;
    if (mediaId == null || mediaId.isEmpty) return null;
    try {
      return await ref.read(apiProvider).request('GET', '/media/$mediaId');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(
      key: const ValueKey('chef-profile-avatar-fallback'),
      child: widget.initials.isEmpty
          ? EatMeIcon(EatMeGlyph.userRound, size: 22, color: scheme.onSurface)
          : Text(
              widget.initials,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: scheme.surfaceContainer,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: FutureBuilder<Json?>(
              future: avatar,
              builder: (context, snapshot) {
                final encoded = snapshot.data?['base64'] as String?;
                if (encoded == null || encoded.isEmpty) return fallback;
                try {
                  return Image.memory(
                    base64Decode(encoded),
                    key: const ValueKey('chef-profile-avatar-image'),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                } on FormatException {
                  return fallback;
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
