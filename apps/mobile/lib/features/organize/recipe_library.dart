import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import 'social_recipe_import.dart';

class RecipeLibraryPage extends ConsumerStatefulWidget {
  const RecipeLibraryPage({super.key, this.initialFavorites = false});
  final bool initialFavorites;
  @override
  ConsumerState<RecipeLibraryPage> createState() => _LibraryState();
}

class _LibraryState extends ResourceState<RecipeLibraryPage> {
  @override
  String get path => '/recipes';
  late String filter = widget.initialFavorites ? 'favorites' : 'all';
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = records(data?['items'])
        .where(
          (r) =>
              (filter == 'all' ||
                  (filter == 'favorites' && r['favorite'] == true) ||
                  (filter == 'imported' &&
                      '${r['source_platform'] ?? ''}'.isNotEmpty) ||
                  (filter == 'yours' &&
                      r['private'] == true &&
                      '${r['source_platform'] ?? ''}'.isEmpty)) &&
              labelOf(
                r['title'],
                context,
              ).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('recipe_library'))),
      body: content([
        SocialImportHeader(
          eyebrow: context.t('your_collection'),
          title: context.t('recipes_you_love'),
          subtitle: context.t('recipe_library_support'),
        ),
        SearchPill(
          hint: context.t('search_recipes'),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 20),
        _ImportRecipeCard(
          onTap: () async {
            await context.push('/recipe-import');
            await load();
          },
        ),
        const SizedBox(height: 18),
        _LibraryFilters(
          selected: filter,
          onSelected: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                context.t(filter == 'all' ? 'all_recipes' : filter),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await context.push('/recipe-editor');
                await load();
              },
              icon: const EatMeIcon(EatMeGlyph.plus, size: 18),
              label: Text(context.t('create_recipe')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final recipe in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecipeLibraryRow(
              recipe: recipe,
              onTap: () => context.push('/recipes/${recipe['id']}'),
              onFavorite: () async {
                await guard(() async {
                  await command({
                    'action': 'favorite',
                    'recipe_id': recipe['id'],
                    'enabled': recipe['favorite'] != true,
                  });
                });
              },
            ),
          ),
        if (items.isEmpty) StatusNote(text: context.t('no_recipes')),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class _ImportRecipeCard extends StatelessWidget {
  const _ImportRecipeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        key: const Key('recipe_import_entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: EatMeIcon(
                  EatMeGlyph.sparkles,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('import_recipe'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.t('import_recipe_support'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const EatMeIcon(EatMeGlyph.chevronRight),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LibraryFilters extends StatelessWidget {
  const _LibraryFilters({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in const ['all', 'favorites', 'yours', 'imported'])
        Semantics(
          button: true,
          selected: selected == value,
          child: InkWell(
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected == value
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                context.t(value),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected == value
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _RecipeLibraryRow extends StatelessWidget {
  const _RecipeLibraryRow({
    required this.recipe,
    required this.onTap,
    required this.onFavorite,
  });
  final Json recipe;
  final VoidCallback onTap, onFavorite;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FoodImage(
              id: '${recipe['id']}',
              imageUrl:
                  '${recipe['hero_image_url'] ?? recipe['image_url'] ?? recipe['thumbnail_url'] ?? ''}',
              ingredientIds: (recipe['ingredients'] as List? ?? const [])
                  .map((item) => '${(item as Map)['food_id'] ?? ''}')
                  .where((id) => id.isNotEmpty)
                  .toList(),
              width: 72,
              height: 72,
              radius: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelOf(recipe['title'], context),
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBadge(
                        label: '${recipe['minutes']} min',
                        icon: EatMeGlyph.clock,
                      ),
                      if ('${recipe['source_platform'] ?? ''}'.isNotEmpty)
                        StatusBadge(
                          label: context.t('imported'),
                          icon: EatMeGlyph.sparkles,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EatMeIconButton(
              glyph: EatMeGlyph.heart,
              label: context.t('favorite'),
              onPressed: onFavorite,
              foregroundColor: recipe['favorite'] == true
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
      ),
    ),
  );
}

class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, this.initial});
  final Json? initial;
  @override
  ConsumerState<RecipeEditorPage> createState() => _EditorState();
}

class _EditorState extends ConsumerState<RecipeEditorPage> {
  final title = TextEditingController(),
      steps = TextEditingController(),
      servings = TextEditingController(text: '2'),
      minutes = TextEditingController(text: '20');
  final mutation = Mutation();
  List<Json> ingredients = [];
  bool reviewed = false;
  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    if (value != null) {
      final name = value['title'];
      title.text = name is Map ? '${name['en']}' : '${name ?? ''}';
      dynamic flatten(dynamic value) {
        if (value is String) return [value];
        if (value is List) {
          return value.expand((v) => List<String>.from(flatten(v))).toList();
        }
        if (value is Map) {
          if (value['text'] is String) return [value['text'] as String];
          final localizedSteps = value['en'] ?? value['it'];
          if (localizedSteps != null) return flatten(localizedSteps);
          return flatten(value['itemListElement']);
        }
        return <String>[];
      }

      final rawSteps = value['steps'] ?? flatten(value['instructions']);
      steps.text = rawSteps is Map
          ? (rawSteps['en'] as List).join('\n')
          : rawSteps is List
          ? rawSteps.join('\n')
          : '';
      servings.text = '${value['servings'] ?? 2}';
      minutes.text = '${value['minutes'] ?? 20}';
      ingredients = records(value['ingredients']);
    }
  }

  @override
  void dispose() {
    for (final controller in [title, steps, servings, minutes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('create_recipe'))),
      body: PageBody(
        children: [
          TextField(
            controller: title,
            maxLength: 160,
            decoration: InputDecoration(labelText: context.t('recipe_name')),
          ),
          if (widget.initial?['ingredients_text'] != null)
            SelectableText(
              (widget.initial!['ingredients_text'] as List).join('\n'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: servings,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.t('servings')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.t('minutes')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.t('ingredients'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final ingredient in ingredients)
            ListTile(
              title: Text(
                foods
                        .where((f) => f.id == ingredient['food_id'])
                        .map((f) => localized(f.name, context.language))
                        .firstOrNull ??
                    context.t('unknown_ingredient'),
              ),
              subtitle: Text('${ingredient['quantity']}'),
              trailing: IconButton(
                tooltip: context.t('delete'),
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => ingredients.remove(ingredient)),
              ),
            ),
          AsyncAction(
            label: context.t('add_ingredient'),
            secondary: true,
            action: () async {
              final food = await chooseFood(context, foods);
              if (food == null || !mounted || !context.mounted) return;
              final amount = await askText(
                context,
                '${context.t('quantity')} (${food.unit})',
                initial: food.unit == 'pcs' ? '1' : '100',
                numeric: true,
              );
              if (amount != null && mounted && context.mounted) {
                setState(
                  () =>
                      ingredients.add({'food_id': food.id, 'quantity': amount}),
                );
              }
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: steps,
            minLines: 5,
            maxLines: 12,
            maxLength: 20000,
            decoration: InputDecoration(
              labelText: context.t('recipe_steps'),
              helperText: context.t('one_step_per_line'),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.initial != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('review_recipe_steps')),
              value: reviewed,
              onChanged: (value) => setState(() => reviewed = value == true),
            ),
          AsyncAction(
            label: context.t('save_private_recipe'),
            enabled:
                ingredients.isNotEmpty && (widget.initial == null || reviewed),
            action: () async {
              final result = await mutation.send(
                ref.read(apiProvider),
                'POST',
                '/recipes',
                {
                  'action': 'save',
                  'recipe': {
                    'title': title.text,
                    'servings': int.tryParse(servings.text) ?? 0,
                    'minutes': int.tryParse(minutes.text) ?? 0,
                    'ingredients': ingredients,
                    'steps': steps.text
                        .split('\n')
                        .where((s) => s.trim().isNotEmpty)
                        .toList(),
                    'source_url': widget.initial?['source_url'] ?? '',
                  },
                },
              );
              if (mounted && context.mounted) {
                context.replace('/recipes/${result['id']}');
              }
            },
          ),
        ],
      ),
    );
  }
}
