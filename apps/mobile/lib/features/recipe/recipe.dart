import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../organize/shared.dart';

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
  String tab = 'ingredients';
  List<String>? participants;
  Future<(Recipe, Json)> load() async {
    final api = ref.read(apiProvider);
    final recipe = await api.request('GET', '/recipes/${widget.recipeId}');
    final preview = await api.request(
      'POST',
      '/cooking/preview',
      body: {'recipe_id': widget.recipeId, 'servings': servings, if (participants != null) 'participants': participants},
    );
    return (Recipe.fromJson(recipe), preview);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          tooltip: context.t('favorite'),
          icon: const Icon(Icons.favorite_border),
          onPressed: () async {
            await Mutation().send(ref.read(apiProvider), 'POST', '/recipes', {
              'action': 'favorite',
              'recipe_id': widget.recipeId,
              'enabled': true,
            });
          },
        ),
      ],
    ),
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
        return PageBody(
          children: [
            Text(
              localized(recipe.title, context.language),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            Text(context.t('minutes', {'minutes': recipe.minutes})),
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
                  icon: const Icon(Icons.remove),
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
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AsyncAction(label: context.t('who_is_eating'), secondary: true, action: () async {
              final value = await chooseDiners(context, ref.read(apiProvider), participants);
              if (value != null && mounted) setState(() { participants = value; future = load(); });
            }),
            SegmentedButton<String>(
              segments: ['ingredients', 'overview', 'why']
                  .map(
                    (s) => ButtonSegment(value: s, label: Text(context.t(s))),
                  )
                  .toList(),
              selected: {tab},
              onSelectionChanged: (s) => setState(() => tab = s.first),
            ),
            const SizedBox(height: 20),
            if (tab == 'ingredients')
              for (final item in (plan['ingredients'] as List))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    localized(
                      Map<String, dynamic>.from(item['food']['name'] as Map),
                      context.language,
                    ),
                  ),
                  subtitle: Text(
                    context.t('required_available', {
                      'required': item['quantity'] as String,
                      'available': item['available'] as String,
                      'unit': item['food']['unit'] as String,
                    }),
                  ),
                ),
            if (tab == 'overview')
              for (final (index, instruction)
                  in recipe.instructions(context.language).indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${index + 1}. $instruction',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
            if (tab == 'why') ...[
              StatusNote(text: context.t('validation_explanation')),
              for (final diet
                  in ref
                      .read(appProvider)
                      .diets
                      .where(
                        (d) => (plan['diet_rules_version'] as Map).containsKey(
                          d.id,
                        ),
                      ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localized(diet.name, context.language)),
                  subtitle: Text(
                    context.t('rule_version', {
                      'version':
                          (plan['diet_rules_version'] as Map)[diet.id] as int,
                    }),
                  ),
                ),
              StatusNote(text: context.t('demo_data_not_a_safety_guarantee')),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.t('nutrition')),
              children: [StatusNote(text: context.t('nutrition_unavailable'))],
            ),
            if ((plan['shortages'] as List).isNotEmpty)
              StatusNote(text: context.t('missing_ingredients_notice')),
            const SizedBox(height: 24),
            AsyncAction(
              label: context.t('build_shopping_list'),
              secondary: true,
              action: () async {
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
                        (f) =>
                            recipe.ingredients.any((i) => i['food_id'] == f.id),
                      )
                      .toList(),
                );
                if (original == null || !context.mounted) return;
                final replacement = await chooseFood(context, foods);
                if (replacement == null || !context.mounted) return;
                final amount = await askText(
                  context,
                  '${context.t('quantity')} (${replacement.unit})',
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
                if (context.mounted) context.push('/recipe-editor', extra: changed);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: ref.watch(appProvider).offline
                  ? null
                  : () => context.push('/cook/${recipe.id}?servings=$servings', extra: participants),
              child: Text(context.t('start_cooking')),
            ),
          ],
        );
      },
    ),
  );
}
