import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class RecipeLibraryPage extends ConsumerStatefulWidget {
  const RecipeLibraryPage({super.key, this.initialFavorites = false});
  final bool initialFavorites;
  @override
  ConsumerState<RecipeLibraryPage> createState() => _LibraryState();
}

class _LibraryState extends ResourceState<RecipeLibraryPage> {
  @override
  String get path => '/recipes';
  late bool favorites = widget.initialFavorites;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = records(data?['items'])
        .where(
          (r) =>
              (!favorites || r['favorite'] == true) &&
              labelOf(
                r['title'],
                context,
              ).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('recipe_library'))),
      body: content([
        TextField(
          decoration: InputDecoration(
            labelText: context.t('search_recipes'),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 16),
        FilterChip(
          label: Text(context.t('favorites')),
          selected: favorites,
          onSelected: (v) => setState(() => favorites = v),
        ),
        const SizedBox(height: 16),
        AsyncAction(
          label: context.t('create_recipe'),
          action: () async {
            await context.push('/recipe-editor');
            await load();
          },
        ),
        const SizedBox(height: 8),
        AsyncAction(
          label: context.t('import_recipe_url'),
          secondary: true,
          action: () async {
            final url = await askText(context, context.t('recipe_url'));
            if (url == null) return;
            final draft = await ref
                .read(apiProvider)
                .request(
                  'POST',
                  '/recipes/import-url',
                  body: {'url': url, 'private_use_confirmed': true},
                );
            if (mounted && context.mounted) {
              await context.push('/recipe-editor', extra: draft);
              await load();
            }
          },
        ),
        StatusNote(text: context.t('private_import_notice')),
        for (final recipe in items)
          Card(
            child: ListTile(
              leading: FoodImage(
                id: '${recipe['id']}',
                width: 60,
                height: 60,
                radius: 14,
              ),
              title: Text(labelOf(recipe['title'], context)),
              subtitle: Text('${recipe['minutes']} min'),
              trailing: IconButton(
                tooltip: context.t('favorite'),
                icon: Icon(
                  recipe['favorite'] == true
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () async {
                  await guard(() async {
                    await command({
                      'action': 'favorite',
                      'recipe_id': recipe['id'],
                      'enabled': recipe['favorite'] != true,
                    });
                  });
                },
              ),
              onTap: () => context.push('/recipes/${recipe['id']}'),
            ),
          ),
        if (items.isEmpty) StatusNote(text: context.t('no_recipes')),
      ]),
    );
  }
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
          return value['text'] is String
              ? [value['text'] as String]
              : flatten(value['itemListElement']);
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
      appBar: AppBar(title: Text(context.t('create_recipe'))),
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
