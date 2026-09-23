import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/entitlements.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../organize/shared.dart';
import '../../core/share_text.dart';

class RecipePage extends ConsumerStatefulWidget {
  const RecipePage({super.key, required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends ConsumerState<RecipePage> {
  late int servings =
      ref.read(appProvider).profile['household_size'] as int? ?? 1;
  late Future<(Recipe, Json)> future = load();
  String tab = 'overview';
  bool favorite = false;
  List<Json> compatibilityWarnings = [];
  bool privateRecipe = false;
  Json rawRecipe = {};
  final mutation = Mutation();
  List<String>? participants;
  List<Json> selectedDiners = [];
  Future<void> toggleFavorite() async {
    final next = !favorite;
    setState(() => favorite = next);
    try {
      await mutation.send(ref.read(apiProvider), 'POST', '/recipes', {
        'action': 'favorite',
        'recipe_id': widget.recipeId,
        'enabled': next,
      });
    } catch (_) {
      if (mounted) setState(() => favorite = !next);
      rethrow;
    }
  }

  Future<Food?> chooseReplacement(Recipe recipe, Food original) async {
    final response = await mutation.send(ref.read(apiProvider), 'POST', '/recipes', {
      'action': 'substitution_candidates',
      'recipe_id': recipe.id,
      'food_id': original.id,
    });
    if (!mounted) return null;
    final candidates = records(response['candidates']);
    final allFoods = ref
        .read(appProvider)
        .foods
        .where(
          (food) =>
              food.id != original.id &&
              food.group != 'packaged',
        )
        .toList();
    return showModalBottomSheet<Food>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .72,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              context.t('suggested_substitutions'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.t('suggested_substitutions_body', {
                'food': localized(original.name, context.language),
              }),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (candidates.isEmpty)
              StatusNote(text: context.t('no_suggested_substitutions')),
            for (final candidate in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      Food.fromJson(
                        Map<String, dynamic>.from(candidate['food'] as Map),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          FoodImage(
                            id: '${candidate['food']['id']}',
                            imageUrl:
                                '${candidate['food']['image_url'] ?? candidate['food']['thumbnail_url'] ?? ''}',
                            width: 50,
                            height: 50,
                            radius: 15,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localized(
                                    Map<String, dynamic>.from(
                                      candidate['food']['name'] as Map,
                                    ),
                                    context.language,
                                  ),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  context.t(
                                    candidate['source'] == 'curated'
                                        ? 'curated_culinary_match'
                                        : 'same_food_family',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (candidate['at_home'] == true)
                            StatusBadge(
                              label: context.t('in_fridge'),
                              icon: EatMeGlyph.refrigerator,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final food = await chooseFood(sheetContext, allFoods);
                if (food != null && sheetContext.mounted) {
                  Navigator.pop(sheetContext, food);
                }
              },
              child: Text(context.t('browse_all_ingredients')),
            ),
          ],
        ),
      ),
    );
  }

  Future<(Recipe, Json)> load() async {
    final api = ref.read(apiProvider);
    final recipe = await api.request('GET', '/recipes/${widget.recipeId}');
    if (mounted) {
      setState(() {
        favorite = recipe['favorite'] == true;
        compatibilityWarnings = [
          ...records(recipe['compatibility']?['reasons']),
          ...records(recipe['compatibility']?['warnings']),
        ];
        privateRecipe = recipe['private'] == true;
        rawRecipe = recipe;
      });
    }
    try {
      final preview = await api.request(
        'POST',
        '/cooking/preview',
        body: {
          'recipe_id': widget.recipeId,
          'servings': servings,
          if (participants != null) 'participants': participants,
        },
      );
      return (Recipe.fromJson(recipe), preview);
    } on ApiFailure catch (error) {
      if (!error.offline && error.code != 'recipe_not_compatible') rethrow;
      final model = Recipe.fromJson(recipe),
          foods = ref.read(appProvider).foods;
      return (
        model,
        {
          'preview_unavailable': error.code,
          'shortages': [],
          'diet_rules_version': recipe['diet_rules_version'] ?? {},
          'nutrition': recipe['nutrition'],
          'ingredients': model.ingredients.map((item) {
            final food = foods
                .where((f) => f.id == item['food_id'])
                .firstOrNull;
            return {
              'food': {
                'name': food?.name ?? {'en': context.t('unknown_ingredient')},
                'unit': food?.unit ?? '',
              },
              'quantity':
                  ((double.tryParse('${item['quantity']}') ?? 0) *
                          servings /
                          model.servings)
                      .toStringAsFixed(2),
              'available': '—',
            };
          }).toList(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const EatMeAppBar(),
    body: FutureBuilder<(Recipe, Json)>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PageBody(
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
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (recipe, plan) = snapshot.data!;
        final nutrition = plan['nutrition'] as Map?;
        final nutrients = nutrition?['totals'] as Map? ?? {};
        final ingredientRows = plan['ingredients'] as List? ?? const [];
        final availableCount = ingredientRows.where((value) {
          final item = Map<String, dynamic>.from(value as Map);
          final required = double.tryParse('${item['quantity']}');
          final available = double.tryParse('${item['available']}');
          return required != null && available != null && available >= required;
        }).length;
        final hasConflict =
            rawRecipe['compatibility']?['status'] == 'not_compatible';
        final needsReview = compatibilityWarnings.isNotEmpty;
        return PageBody(
          children: [
            if (plan['preview_unavailable'] != null)
              StatusNote(
                text: context.t(plan['preview_unavailable'] as String),
                warning: true,
              ),
            Stack(
              children: [
                FoodImage(
                  id: recipe.id,
                  imageUrl: recipe.imageUrl,
                  ingredientIds: recipe.ingredientIds,
                  height: 280,
                  radius: 28,
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: EatMeIconButton(
                    glyph: EatMeGlyph.heart,
                    filled: favorite,
                    label: context.t(favorite ? 'remove_favorite' : 'favorite'),
                    foregroundColor: favorite
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: .92),
                    onPressed: toggleFavorite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              localized(recipe.title, context.language),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            if (rawRecipe['description'] is Map) ...[
              const SizedBox(height: 10),
              Text(
                localized(
                  Map<String, dynamic>.from(rawRecipe['description'] as Map),
                  context.language,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  label: context.t('minutes', {'minutes': recipe.minutes}),
                  icon: EatMeGlyph.clock,
                ),
                StatusBadge(
                  label: context.t('portions', {'count': servings}),
                  icon: EatMeGlyph.utensils,
                ),
              ],
            ),
            const SizedBox(height: 18),
            InformationPanel(
              tinted: !hasConflict,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EatMeIcon(
                        hasConflict
                            ? EatMeGlyph.triangleAlert
                            : needsReview
                            ? EatMeGlyph.circleAlert
                            : EatMeGlyph.shieldCheck,
                        color: hasConflict
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t(
                            hasConflict
                                ? 'diet_fit_conflict_title'
                                : needsReview
                                ? 'diet_fit_review_title'
                                : 'diet_fit_match_title',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      hasConflict
                          ? 'diet_fit_conflict_body'
                          : needsReview
                          ? 'diet_fit_review_body'
                          : 'diet_fit_match_body',
                    ),
                  ),
                ],
              ),
            ),
            if ('${rawRecipe['source_url'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 18),
              InformationPanel(
                tinted: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const EatMeIcon(EatMeGlyph.sparkles),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('imported_from_source', {
                              'source':
                                  const {
                                    'youtube',
                                    'instagram',
                                  }.contains('${rawRecipe['source_platform']}')
                                  ? context.t('${rawRecipe['source_platform']}')
                                  : context.t('original_source'),
                            }),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if ('${rawRecipe['source_creator'] ?? ''}'.isNotEmpty)
                            Text(
                              context.t('source_by', {
                                'creator': '${rawRecipe['source_creator']}',
                              }),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if ((rawRecipe['adaptations'] as List? ?? [])
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                context.t('adaptation_count', {
                                  'count':
                                      (rawRecipe['adaptations'] as List).length,
                                }),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('${rawRecipe['source_url']}'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(context.t('original')),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.t('recipe_actions')),
              children: [
                AsyncAction(
                  label: context.t('share_recipe'),
                  secondary: true,
                  action: () => shareText(
                    context,
                    localized(recipe.title, context.language),
                    '${localized(recipe.title, context.language)}\n${context.t('portions', {'count': recipe.servings})}\n${recipe.ingredients.map((i) {
                      final food = ref.read(appProvider).foods.where((f) => f.id == i['food_id']).firstOrNull;
                      return '${food == null ? context.t('food_unavailable') : localized(food.name, context.language)}: ${i['quantity']} ${food?.unit ?? ''}';
                    }).join('\n')}\n\n${recipe.instructions(context.language).asMap().entries.map((s) => '${s.key + 1}. ${s.value}').join('\n')}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(context.t('servings')),
                const Spacer(),
                IconButton(
                  tooltip: context.t('fewer'),
                  onPressed: servings > 1
                      ? () => setState(() {
                          servings--;
                          future = load();
                        })
                      : null,
                  icon: const EatMeIcon(EatMeGlyph.minus, size: 18),
                ),
                Text('$servings'),
                IconButton(
                  tooltip: context.t('more'),
                  onPressed: servings < 20
                      ? () => setState(() {
                          servings++;
                          future = load();
                        })
                      : null,
                  icon: const EatMeIcon(EatMeGlyph.plus, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AsyncAction(
              label: context.t('who_is_eating'),
              secondary: true,
              action: () async {
                final api = ref.read(apiProvider);
                final value = await chooseDiners(
                  context,
                  api,
                  participants,
                );
                if (value != null && mounted) {
                  final home = await api.request('GET', '/households');
                  if (!mounted) return;
                  final members = records(home['members']);
                  setState(() {
                    participants = value;
                    selectedDiners = members
                        .where((member) => value.contains(member['user_id']))
                        .toList();
                    future = load();
                  });
                }
              },
            ),
            if (selectedDiners.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final diner in selectedDiners)
                    _DinerChip(name: diner['name'] as String? ?? ''),
                ],
              ),
            ],
            const SizedBox(height: 24),
            EatMeTabStrip(
              values: [
                for (final value in [
                  'overview',
                  'ingredients',
                  'steps',
                  'nutrition',
                ])
                  (value, context.t(value)),
              ],
              selected: tab,
              onSelected: (value) => setState(() => tab = value),
            ),
            const SizedBox(height: 20),
            if (tab == 'overview') ...[
              InformationPanel(
                tinted: false,
                child: Row(
                  children: [
                    const EatMeIcon(EatMeGlyph.refrigerator, size: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('you_have'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            context.t('ingredient_coverage', {
                              'available': availableCount,
                              'total': ingredientRows.length,
                            }),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StatusNote(text: context.t('validation_explanation')),
              for (final warning in compatibilityWarnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: StatusNote(
                    text: context.t(warning['code'] as String),
                    warning: true,
                  ),
                ),
            ],
            if (tab == 'ingredients')
              for (final item in ingredientRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InformationPanel(
                    tinted: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const EatMeIcon(EatMeGlyph.leaf, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localized(
                                  Map<String, dynamic>.from(
                                    item['food']['name'] as Map,
                                  ),
                                  context.language,
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                context.t('required_available', {
                                  'required': item['quantity'] as String,
                                  'available': item['available'] as String,
                                  'unit': item['food']['unit'] as String,
                                }),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (tab == 'steps')
              for (final (index, row)
                  in recipe.instructionSteps(context.language).indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${row['text'] ?? ''}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (row['timer_seconds'] is num &&
                          (row['timer_seconds'] as num) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            context.t('start_timer_minutes', {
                              'count': ((row['timer_seconds'] as num) / 60)
                                  .ceil(),
                            }),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                    ],
                  ),
                ),
            if (tab == 'nutrition') ...[
              StatusNote(
                text: context.t(
                  nutrients.isEmpty
                      ? 'nutrition_unavailable'
                      : nutrition?['complete'] != true
                      ? 'partial_nutrition'
                      : nutrition?['estimated'] == true
                      ? 'nutrition_proxy_method'
                      : 'nutrition_method',
                ),
                warning:
                    nutrients.isNotEmpty && nutrition?['complete'] != true,
              ),
              if (nutrients.isNotEmpty)
                Text('${nutrition?['servings']} ${context.t('servings')}'),
              for (final nutrient in nutrients.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InformationPanel(
                    tinted: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(context.t('nutrient_${nutrient.key}')),
                        ),
                        Text(
                          '${nutrient.value['value']} ${nutrient.value['unit']}',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if ((plan['shortages'] as List).isNotEmpty)
              StatusNote(text: context.t('missing_ingredients_notice')),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  ref.watch(appProvider).offline ||
                      plan['preview_unavailable'] != null
                  ? null
                  : () => context.push(
                      '/cook/${recipe.id}?servings=$servings',
                      extra: participants,
                    ),
              child: Text(context.t('start_cooking')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/plan?recipe=${recipe.id}'),
              icon: const EatMeIcon(EatMeGlyph.calendarDays, size: 20),
              label: Text(context.t('add_to_plan')),
            ),
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.t('more_recipe_tools')),
              children: [
                AsyncAction(
                  label: context.t('build_shopping_list'),
                  secondary: true,
                  action: () async {
                    final entitlement = await ref.read(
                      entitlementsProvider.future,
                    );
                    if (!entitlement.can(
                      EntitlementCapability.generatedShopping,
                    )) {
                      if (context.mounted) {
                        await showContextualPlusPrompt(
                          context,
                          benefit: 'generated_shopping_plus_body',
                        );
                      }
                      return;
                    }
                    await Mutation().send(
                      ref.read(apiProvider),
                      'POST',
                      '/shopping',
                      {
                        'action': 'generate',
                        'meals': [
                          {'recipe_id': recipe.id, 'servings': servings},
                        ],
                      },
                    );
                    if (context.mounted) context.push('/shopping');
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final rating in [1, -1])
                      AsyncAction(
                        label: context.t(
                          rating == 1 ? 'like_recipe' : 'dislike_recipe',
                        ),
                        secondary: true,
                        action: () async {
                          await Mutation()
                              .send(ref.read(apiProvider), 'POST', '/recipes', {
                                'action': 'feedback',
                                'recipe_id': recipe.id,
                                'rating': rating,
                              });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                AsyncAction(
                  label: context.t('substitute_ingredient'),
                  secondary: true,
                  action: () async {
                    final foods = ref.read(appProvider).foods;
                    final original = await chooseFood(
                      context,
                      foods
                          .where(
                            (f) => recipe.ingredients.any(
                              (i) => i['food_id'] == f.id,
                            ),
                          )
                          .toList(),
                    );
                    if (original == null || !context.mounted) return;
                    final replacement = await chooseReplacement(
                      recipe,
                      original,
                    );
                    if (replacement == null || !context.mounted) return;
                    final originalIngredient = recipe.ingredients
                        .where((item) => item['food_id'] == original.id)
                        .firstOrNull;
                    final amount = await askText(
                      context,
                      '${context.t('quantity')} (${replacement.unit})',
                      initial: replacement.unit == original.unit
                          ? '${originalIngredient?['quantity'] ?? ''}'
                          : '',
                      numeric: true,
                    );
                    if (amount == null) return;
                    final changed = await Mutation()
                        .send(ref.read(apiProvider), 'POST', '/recipes', {
                          'action': 'substitute',
                          'recipe_id': recipe.id,
                          'food_id': original.id,
                          'replacement_id': replacement.id,
                          'quantity': amount,
                        });
                    if (context.mounted) {
                      context.push('/recipe-editor', extra: changed);
                    }
                  },
                ),
                const SizedBox(height: 24),
                AsyncAction(
                  label: context.t('report_problem'),
                  secondary: true,
                  action: () async {
                    final message = await askText(
                      context,
                      context.t('report_notice'),
                    );
                    if (message == null || message.isEmpty) return;
                    await mutation.send(
                      ref.read(apiProvider),
                      'POST',
                      '/reports',
                      {
                        'kind': 'recipe',
                        'subject_id': recipe.id,
                        'message': message,
                      },
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t('report_sent'))),
                      );
                    }
                  },
                ),
                if (privateRecipe)
                  AsyncAction(
                    label: context.t('archive_recipe'),
                    secondary: true,
                    action: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.t('archive_recipe')),
                          content: Text(context.t('archive_recipe_body')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(context.t('cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(context.t('archive_recipe')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await mutation.send(
                        ref.read(apiProvider),
                        'POST',
                        '/recipes',
                        {'action': 'delete', 'recipe_id': recipe.id},
                      );
                      await ref.read(appProvider.notifier).refresh();
                      if (context.mounted) context.go('/chef');
                    },
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}


class _DinerChip extends StatelessWidget {
  const _DinerChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initials = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              initials.isEmpty ? '•' : initials,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(trimmed, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
