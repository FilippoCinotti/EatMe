import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

Json _copy(Json value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Food? _food(List<Food> foods, dynamic id) =>
    foods.where((item) => item.id == id).firstOrNull;

String _foodName(BuildContext context, List<Food> foods, dynamic id) {
  final value = _food(foods, id);
  return value == null
      ? context.t('unknown_ingredient')
      : localized(value.name, context.language);
}

bool _supportedUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (host == 'youtube.com' || host == 'm.youtube.com') {
    return (uri.path == '/watch' &&
            (uri.queryParameters['v'] ?? '').isNotEmpty) ||
        ((uri.pathSegments.firstOrNull == 'shorts' ||
                uri.pathSegments.firstOrNull == 'live') &&
            uri.pathSegments.length == 2);
  }
  if (host == 'youtu.be') return uri.pathSegments.length == 1;
  if (host != 'instagram.com' || uri.pathSegments.length != 2) return false;
  return const {'p', 'reel', 'tv'}.contains(uri.pathSegments.first);
}

class SocialImportHeader extends StatelessWidget {
  const SocialImportHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow, title, subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
      ),
      const SizedBox(height: 10),
      Text(title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 28),
    ],
  );
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.platform, {super.key});
  final String platform;

  @override
  Widget build(BuildContext context) {
    final youtube = platform == 'youtube';
    return Semantics(
      label: context.t(youtube ? 'youtube' : 'instagram'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: youtube
                    ? const Color(0xffd6332f)
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                youtube ? 'YT' : 'IG',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.t(youtube ? 'youtube' : 'instagram'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class ImportRecipePage extends ConsumerStatefulWidget {
  const ImportRecipePage({super.key});

  @override
  ConsumerState<ImportRecipePage> createState() => _ImportRecipePageState();
}

class _ImportRecipePageState extends ConsumerState<ImportRecipePage> {
  final controller = TextEditingController();
  bool confirmed = false;
  String? inlineError;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> paste() async {
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || value?.text == null) return;
    setState(() {
      controller.text = value!.text!.trim();
      inlineError = null;
    });
  }

  Future<void> start() async {
    final url = controller.text.trim();
    if (!_supportedUrl(url)) {
      setState(
        () => inlineError = url.isEmpty
            ? 'invalid_public_url'
            : 'unsupported_recipe_source',
      );
      return;
    }
    if (!confirmed) {
      setState(() => inlineError = 'private_use_confirmation_required');
      return;
    }
    await Navigator.push<Json>(
      context,
      MaterialPageRoute(builder: (_) => ImportProcessingPage(sourceUrl: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(appProvider).offline;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('import_recipe'))),
      body: PageBody(
        children: [
          SocialImportHeader(
            eyebrow: context.t('recipe_library'),
            title: context.t('bring_recipes'),
            subtitle: context.t('import_intro'),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [SourceBadge('youtube'), SourceBadge('instagram')],
          ),
          const SizedBox(height: 22),
          TextField(
            key: const Key('social_url'),
            controller: controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => start(),
            onChanged: (_) => setState(() => inlineError = null),
            decoration: InputDecoration(
              labelText: context.t('paste_recipe_link'),
              suffixIcon: TextButton(
                onPressed: paste,
                child: Text(context.t('paste')),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InformationPanel(
            tinted: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Semantics(
              checked: confirmed,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => confirmed = !confirmed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox.adaptive(
                      value: confirmed,
                      onChanged: (value) =>
                          setState(() => confirmed = value == true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(context.t('public_import_confirmation')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (inlineError != null) ...[
            const SizedBox(height: 14),
            StatusNote(text: context.t(inlineError!), warning: true),
          ],
          if (offline) ...[
            const SizedBox(height: 14),
            StatusNote(
              text: context.t('import_requires_connection'),
              warning: true,
            ),
          ],
          const SizedBox(height: 24),
          AsyncAction(
            key: const Key('start_social_import'),
            label: context.t('import_recipe'),
            enabled: !offline,
            action: start,
          ),
          const SizedBox(height: 18),
          Text(
            context.t('private_import_notice'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class ImportProcessingPage extends ConsumerStatefulWidget {
  const ImportProcessingPage({super.key, required this.sourceUrl});
  final String sourceUrl;

  @override
  ConsumerState<ImportProcessingPage> createState() =>
      _ImportProcessingPageState();
}

class _ImportProcessingPageState extends ConsumerState<ImportProcessingPage> {
  String? error;
  bool cancelled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(run);
  }

  Future<void> run() async {
    try {
      final value = await ref
          .read(apiProvider)
          .request(
            'POST',
            '/recipes/import-url',
            body: {'url': widget.sourceUrl, 'private_use_confirmed': true},
          );
      if (!mounted || cancelled) return;
      await Navigator.pushReplacement<Json, Json>(
        context,
        MaterialPageRoute(
          builder: (_) => ImportedRecipeReviewPage(draft: value),
        ),
      );
    } on ApiFailure catch (failure) {
      if (mounted && !cancelled) setState(() => error = failure.code);
    } catch (_) {
      if (mounted && !cancelled) setState(() => error = 'provider_unavailable');
    }
  }

  void cancel() {
    cancelled = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(
      title: Text(context.t('import_recipe')),
      leading: EatMeIconButton(
        glyph: EatMeGlyph.chevronLeft,
        label: context.t('cancel'),
        onPressed: cancel,
      ),
    ),
    body: PageBody(
      children: [
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 146,
            height: 146,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: error == null
                ? const SizedBox.square(
                    dimension: 54,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : EatMeIcon(
                    EatMeGlyph.triangleAlert,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          context.t(error == null ? 'reading_recipe' : error!),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          context.t(
            error == null ? 'reading_recipe_support' : 'import_failure_support',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 30),
        if (error == null)
          InformationPanel(
            tinted: false,
            child: Column(
              children: [
                for (final stage in const [
                  'fetching_source',
                  'extracting_recipe',
                  'matching_ingredients',
                  'preparing_review',
                ])
                  _StageRow(label: context.t(stage)),
              ],
            ),
          )
        else ...[
          StatusNote(text: context.t(error!), warning: true),
          const SizedBox(height: 16),
          AsyncAction(label: context.t('retry'), action: run),
        ],
        const SizedBox(height: 18),
        AsyncAction(
          label: context.t(error == null ? 'cancel_import' : 'back'),
          secondary: true,
          action: () async => cancel(),
        ),
      ],
    ),
  );
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class ImportedRecipeReviewPage extends StatefulWidget {
  const ImportedRecipeReviewPage({super.key, required this.draft});
  final Json draft;

  @override
  State<ImportedRecipeReviewPage> createState() =>
      _ImportedRecipeReviewPageState();
}

class _ImportedRecipeReviewPageState extends State<ImportedRecipeReviewPage> {
  late Json draft;
  late final TextEditingController title, servings, minutes, steps;
  late List<_IngredientEdit> ingredients;

  @override
  void initState() {
    super.initState();
    draft = _copy(widget.draft);
    title = TextEditingController(text: '${draft['title'] ?? ''}');
    servings = TextEditingController(text: '${draft['servings'] ?? ''}');
    minutes = TextEditingController(text: '${draft['minutes'] ?? ''}');
    steps = TextEditingController(
      text: List<String>.from(draft['steps'] as List? ?? []).join('\n'),
    );
    ingredients = records(
      draft['ingredient_rows'],
    ).map(_IngredientEdit.new).toList();
  }

  @override
  void dispose() {
    title.dispose();
    servings.dispose();
    minutes.dispose();
    steps.dispose();
    for (final ingredient in ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  Json buildDraft() => {
    ...draft,
    'title': title.text.trim(),
    'servings': int.tryParse(servings.text),
    'minutes': int.tryParse(minutes.text),
    'steps': steps.text
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'ingredient_rows': ingredients.map((value) => value.value).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final missing = List<String>.from(draft['missing_fields'] as List? ?? []);
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('review_imported_recipe'))),
      body: PageBody(
        children: [
          SocialImportHeader(
            eyebrow: context.t('review_step'),
            title: context.t('review_imported_recipe'),
            subtitle: context.t('review_import_support'),
          ),
          _SourcePanel(draft: draft),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 16),
            StatusNote(text: context.t('partial_recipe_notice'), warning: true),
          ],
          const SizedBox(height: 24),
          TextField(
            key: const Key('import_title'),
            controller: title,
            maxLength: 160,
            decoration: InputDecoration(labelText: context.t('recipe_name')),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: servings,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.t('servings')),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.t('minutes')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionHeading(title: context.t('ingredients')),
          const SizedBox(height: 12),
          for (var index = 0; index < ingredients.length; index++) ...[
            _IngredientEditor(
              key: ValueKey(ingredients[index].identity),
              ingredient: ingredients[index],
              onChanged: () => setState(() {}),
              onDelete: () => setState(() {
                ingredients[index].dispose();
                ingredients.removeAt(index);
              }),
            ),
            const SizedBox(height: 10),
          ],
          AsyncAction(
            key: const Key('review_add_ingredient'),
            label: context.t('add_ingredient'),
            secondary: true,
            action: () async => setState(
              () => ingredients.add(
                _IngredientEdit({
                  'source_text': '',
                  'quantity': null,
                  'unit': null,
                  'food_id': null,
                  'mapping_status': 'unknown',
                  'confirmed': false,
                }),
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const Key('import_steps'),
            controller: steps,
            minLines: 6,
            maxLines: 14,
            maxLength: 20000,
            decoration: InputDecoration(
              labelText: context.t('recipe_steps'),
              helperText: context.t('one_step_per_line'),
            ),
          ),
          const SizedBox(height: 26),
          AsyncAction(
            key: const Key('review_next'),
            label: context.t('next_check_compatibility'),
            enabled: ingredients.isNotEmpty,
            action: () async {
              await Navigator.push<Json>(
                context,
                MaterialPageRoute(
                  builder: (_) => IngredientMappingPage(draft: buildDraft()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IngredientEdit {
  _IngredientEdit(Json row)
    : identity = Object(),
      original = _copy(row),
      name = TextEditingController(text: '${row['source_text'] ?? ''}'),
      quantity = TextEditingController(text: '${row['quantity'] ?? ''}');

  final Object identity;
  final Json original;
  final TextEditingController name, quantity;

  Json get value {
    final changed = name.text.trim() != '${original['source_text'] ?? ''}';
    return {
      ...original,
      'source_text': name.text.trim(),
      'quantity': quantity.text.trim().isEmpty
          ? null
          : quantity.text.trim().replaceAll(',', '.'),
      if (changed) 'mapping_status': 'needs_review',
      if (changed) 'confirmed': false,
    };
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _IngredientEditor extends StatelessWidget {
  const _IngredientEditor({
    super.key,
    required this.ingredient,
    required this.onChanged,
    required this.onDelete,
  });
  final _IngredientEdit ingredient;
  final VoidCallback onChanged, onDelete;

  @override
  Widget build(BuildContext context) => InformationPanel(
    tinted: false,
    padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: ingredient.name,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: context.t('ingredient_name'),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ingredient.quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.t('quantity'),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        EatMeIconButton(
          glyph: EatMeGlyph.trash2,
          label: context.t('delete'),
          onPressed: onDelete,
          backgroundColor: Colors.transparent,
        ),
      ],
    ),
  );
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({required this.draft});
  final Json draft;

  @override
  Widget build(BuildContext context) {
    final thumbnail = '${draft['source_thumbnail_url'] ?? ''}';
    return InformationPanel(
      tinted: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumbnail.startsWith('https://'))
            SizedBox(
              height: 156,
              width: double.infinity,
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _SourceArt(),
              ),
            )
          else
            const SizedBox(height: 126, child: _SourceArt()),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SourceBadge('${draft['source_platform'] ?? 'youtube'}'),
                if ('${draft['source_creator'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.t('source_by', {
                      'creator': '${draft['source_creator']}',
                    }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('${draft['source_url']}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const EatMeIcon(EatMeGlyph.eye, size: 18),
                  label: Text(context.t('view_original')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceArt extends StatelessWidget {
  const _SourceArt();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ],
      ),
    ),
    child: Center(
      child: EatMeIcon(
        EatMeGlyph.cookingPot,
        size: 44,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class IngredientMappingPage extends ConsumerStatefulWidget {
  const IngredientMappingPage({super.key, required this.draft});
  final Json draft;

  @override
  ConsumerState<IngredientMappingPage> createState() =>
      _IngredientMappingPageState();
}

class _IngredientMappingPageState extends ConsumerState<IngredientMappingPage> {
  late Json draft;
  late List<Json> rows;

  @override
  void initState() {
    super.initState();
    draft = _copy(widget.draft);
    rows = records(draft['ingredient_rows']);
  }

  Future<void> choose(int index) async {
    final food = await chooseFood(context, ref.read(appProvider).foods);
    if (food == null || !mounted) return;
    var quantity = '${rows[index]['quantity'] ?? ''}';
    if (quantity.isEmpty) {
      if (!context.mounted) return;
      quantity =
          await askText(
            context,
            '${context.t('quantity')} (${food.unit})',
            initial: food.unit == 'pcs' ? '1' : '100',
            numeric: true,
          ) ??
          '';
    }
    if (!mounted || quantity.isEmpty) return;
    setState(() {
      rows[index] = {
        ...rows[index],
        'food_id': food.id,
        'unit': food.unit,
        'quantity': quantity,
        'mapping_status': 'matched',
        'confirmed': true,
      };
    });
  }

  void confirm(int index) {
    final row = rows[index];
    if (_food(ref.read(appProvider).foods, row['food_id']) == null ||
        double.tryParse('${row['quantity'] ?? ''}') == null) {
      choose(index);
      return;
    }
    setState(() {
      rows[index] = {...row, 'mapping_status': 'matched', 'confirmed': true};
    });
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    final unresolved = rows
        .where(
          (row) =>
              row['mapping_status'] != 'matched' || row['confirmed'] != true,
        )
        .length;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('ingredient_mapping'))),
      body: PageBody(
        children: [
          SocialImportHeader(
            eyebrow: context.t('mapping_step'),
            title: context.t('ingredient_mapping'),
            subtitle: context.t('ingredient_mapping_support'),
          ),
          for (var index = 0; index < rows.length; index++) ...[
            _MappingRow(
              key: ValueKey('$index-${rows[index]['source_text']}'),
              row: rows[index],
              foodName: _foodName(context, foods, rows[index]['food_id']),
              onConfirm: () => confirm(index),
              onChange: () => choose(index),
            ),
            const SizedBox(height: 12),
          ],
          if (unresolved > 0)
            StatusNote(
              text: context.t('mapping_unresolved_count', {
                'count': unresolved,
              }),
              warning: true,
            )
          else
            StatusNote(text: context.t('mapping_complete')),
          const SizedBox(height: 22),
          AsyncAction(
            key: const Key('mapping_check'),
            label: context.t('check_compatibility'),
            action: () async {
              await Navigator.push<Json>(
                context,
                MaterialPageRoute(
                  builder: (_) => CompatibilityCheckingPage(
                    draft: {...draft, 'ingredient_rows': rows},
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    super.key,
    required this.row,
    required this.foodName,
    required this.onConfirm,
    required this.onChange,
  });
  final Json row;
  final String foodName;
  final VoidCallback onConfirm, onChange;

  @override
  Widget build(BuildContext context) {
    final status = '${row['mapping_status'] ?? 'unknown'}';
    final matched = status == 'matched' && row['confirmed'] == true;
    final suggested = row['food_id'] != null;
    return InformationPanel(
      tinted: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${row['source_text'] ?? ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(
                label: context.t(
                  matched
                      ? 'mapping_matched'
                      : suggested
                      ? 'mapping_needs_review'
                      : 'mapping_unknown',
                ),
                icon: matched ? EatMeGlyph.circleCheck : EatMeGlyph.circleAlert,
                warning: !matched,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              EatMeIcon(
                suggested ? EatMeGlyph.leaf : EatMeGlyph.triangleAlert,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  suggested
                      ? '$foodName · ${row['quantity'] ?? context.t('unknown_value')} ${row['unit'] ?? ''}'
                      : context.t('no_canonical_match'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (suggested && !matched)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onConfirm,
                    child: Text(context.t('confirm_mapping')),
                  ),
                ),
              if (suggested && !matched) const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: onChange,
                  child: Text(
                    context.t(suggested ? 'change_mapping' : 'choose_food'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CompatibilityCheckingPage extends ConsumerStatefulWidget {
  const CompatibilityCheckingPage({
    super.key,
    required this.draft,
    this.adaptedCount = 0,
  });
  final Json draft;
  final int adaptedCount;

  @override
  ConsumerState<CompatibilityCheckingPage> createState() =>
      _CompatibilityCheckingPageState();
}

class _CompatibilityCheckingPageState
    extends ConsumerState<CompatibilityCheckingPage> {
  String? error;
  bool cancelled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(check);
  }

  Future<void> check() async {
    try {
      final value = await ref
          .read(apiProvider)
          .request(
            'POST',
            '/recipes/import-review',
            body: {'ingredient_rows': widget.draft['ingredient_rows']},
          );
      if (!mounted || cancelled) return;
      await Navigator.pushReplacement<Json, Json>(
        context,
        MaterialPageRoute(
          builder: (_) => ImportedRecipeResultPage(
            draft: widget.draft,
            result: value,
            adaptedCount: widget.adaptedCount,
          ),
        ),
      );
    } on ApiFailure catch (failure) {
      if (mounted && !cancelled) setState(() => error = failure.code);
    } catch (_) {
      if (mounted && !cancelled) setState(() => error = 'unknown_error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final adapted = widget.adaptedCount > 0;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('compatibility'))),
      body: PageBody(
        children: [
          const SizedBox(height: 30),
          Center(
            child: Container(
              width: 150,
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: error == null
                  ? const CircularProgressIndicator(strokeWidth: 3)
                  : EatMeIcon(
                      EatMeGlyph.triangleAlert,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            context.t(adapted ? 'checking_adapted_recipe' : 'checking_recipe'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('full_check_support'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          InformationPanel(
            tinted: false,
            child: Column(
              children: [
                for (final stage in [
                  if (adapted) 'updating_ingredients',
                  'rechecking_constraints',
                  'recalculating_inventory',
                  'preparing_result',
                ])
                  _StageRow(label: context.t(stage)),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 18),
            StatusNote(text: context.t(error!), warning: true),
            const SizedBox(height: 16),
            AsyncAction(label: context.t('retry'), action: check),
          ],
          const SizedBox(height: 16),
          AsyncAction(
            label: context.t('cancel'),
            secondary: true,
            action: () async {
              cancelled = true;
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class ImportedRecipeResultPage extends ConsumerStatefulWidget {
  const ImportedRecipeResultPage({
    super.key,
    required this.draft,
    required this.result,
    this.adaptedCount = 0,
  });
  final Json draft, result;
  final int adaptedCount;

  @override
  ConsumerState<ImportedRecipeResultPage> createState() =>
      _ImportedRecipeResultPageState();
}

class _ImportedRecipeResultPageState
    extends ConsumerState<ImportedRecipeResultPage> {
  final mutation = Mutation();
  bool acknowledged = false;

  Json recipe() {
    final rows = records(widget.draft['ingredient_rows']);
    return {
      'title': widget.draft['title'],
      'servings': widget.draft['servings'],
      'minutes': widget.draft['minutes'],
      'ingredients': [
        for (final row in rows)
          if (row['mapping_status'] == 'matched' &&
              row['confirmed'] == true &&
              row['food_id'] != null &&
              row['quantity'] != null)
            {'food_id': row['food_id'], 'quantity': row['quantity']},
      ],
      'steps': widget.draft['steps'],
      'source_url': widget.draft['source_url'],
      'source_platform': widget.draft['source_platform'],
      'source_title': widget.draft['source_title'],
      'source_creator': widget.draft['source_creator'],
      'source_thumbnail_url': widget.draft['source_thumbnail_url'],
      'imported_at': widget.draft['imported_at'],
      'provenance': 'public-social-link',
      'adaptations': widget.draft['adaptations'] ?? const [],
    };
  }

  Future<Json> save() =>
      mutation.send(ref.read(apiProvider), 'POST', '/recipes', {
        'action': 'save',
        'recipe': recipe(),
        if (acknowledged) 'safety_acknowledged': true,
      });

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    final compatibility = Map<String, dynamic>.from(
      widget.result['compatibility'] as Map? ?? {},
    );
    final inventory = Map<String, dynamic>.from(
      widget.result['inventory'] as Map? ?? {},
    );
    final status = '${compatibility['status'] ?? 'unknown'}';
    final conflict = status == 'conflict';
    final incomplete = status == 'unknown';
    final fit = status == 'fit';
    final rows = records(widget.draft['ingredient_rows']);
    final completeFields =
        '${widget.draft['title'] ?? ''}'.trim().isNotEmpty &&
        (widget.draft['servings'] is int) &&
        (widget.draft['minutes'] is int) &&
        (widget.draft['steps'] as List? ?? []).isNotEmpty &&
        rows.isNotEmpty;
    final mappingComplete = (inventory['unresolved_count'] ?? 0) == 0;
    final canSave =
        completeFields && mappingComplete && (!conflict || acknowledged);
    final suggestions = records(widget.result['substitutions']);
    final hasCandidates = suggestions.any(
      (item) => records(item['candidates']).isNotEmpty,
    );
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('compatibility'))),
      body: PageBody(
        children: [
          _CompatibilityHero(status: status, adapted: widget.adaptedCount > 0),
          const SizedBox(height: 22),
          _CompatibilityFacts(
            compatibility: compatibility,
            activeDiets: records(widget.result['active_diets']),
          ),
          const SizedBox(height: 22),
          _InventoryPanel(inventory: inventory, foods: foods),
          if (conflict) ...[
            const SizedBox(height: 28),
            SectionHeading(title: context.t('make_fit')),
            const SizedBox(height: 8),
            Text(
              context.t('make_fit_support'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (hasCandidates)
              AsyncAction(
                key: const Key('open_substitutions'),
                label: context.t('review_substitutions'),
                action: () async {
                  await Navigator.push<Json>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubstitutionSelectionPage(
                        draft: widget.draft,
                        result: widget.result,
                      ),
                    ),
                  );
                },
              )
            else
              InformationPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EatMeIcon(EatMeGlyph.circleAlert),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('no_suitable_substitution'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(context.t('no_suitable_substitution_body')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (conflict) ...[
            const SizedBox(height: 24),
            InformationPanel(
              tinted: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox.adaptive(
                    value: acknowledged,
                    onChanged: (value) =>
                        setState(() => acknowledged = value == true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(context.t('acknowledge_recipe_conflicts')),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!completeFields || incomplete) ...[
            const SizedBox(height: 18),
            StatusNote(text: context.t('complete_before_save'), warning: true),
          ],
          const SizedBox(height: 26),
          AsyncAction(
            key: const Key('save_imported_recipe'),
            label: context.t(
              conflict ? 'save_with_warning' : 'save_to_library',
            ),
            enabled: canSave,
            action: () async {
              final saved = await save();
              if (mounted && context.mounted) {
                context.go('/recipes/${saved['id']}');
              }
            },
          ),
          const SizedBox(height: 10),
          AsyncAction(
            key: const Key('cook_imported_recipe'),
            label: context.t('cook_now'),
            secondary: true,
            enabled: canSave && fit,
            action: () async {
              final saved = await save();
              if (mounted && context.mounted) {
                context.go(
                  '/cook/${saved['id']}?servings=${widget.draft['servings']}',
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            context.t('save_source_preserved'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityHero extends StatelessWidget {
  const _CompatibilityHero({required this.status, required this.adapted});
  final String status;
  final bool adapted;

  @override
  Widget build(BuildContext context) {
    final fit = status == 'fit';
    final caution = status == 'caution';
    final title = adapted && fit
        ? 'adapted_success'
        : switch (status) {
            'fit' => 'compatibility_fit',
            'caution' => 'compatibility_caution',
            'conflict' => 'compatibility_conflict',
            _ => 'compatibility_unknown',
          };
    final body = adapted && fit
        ? 'adapted_success_body'
        : switch (status) {
            'fit' => 'fits_profile_body',
            'caution' => 'caution_body',
            'conflict' => 'conflict_body',
            _ => 'unknown_compat_body',
          };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: status == 'conflict'
            ? Theme.of(context).colorScheme.errorContainer
            : fit
            ? Theme.of(context).colorScheme.primary
            : caution
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          EatMeIcon(
            fit ? EatMeGlyph.circleCheck : EatMeGlyph.triangleAlert,
            size: 46,
            color: fit
                ? Theme.of(context).colorScheme.onPrimary
                : status == 'conflict'
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 16),
          Text(
            context.t(title),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: fit ? Theme.of(context).colorScheme.onPrimary : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(body),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: fit
                  ? Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: .82)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityFacts extends StatelessWidget {
  const _CompatibilityFacts({
    required this.compatibility,
    required this.activeDiets,
  });
  final Json compatibility;
  final List<Json> activeDiets;

  @override
  Widget build(BuildContext context) {
    final reasons = records(compatibility['classified_reasons']);
    final warnings = records(compatibility['warnings']);
    return SettingsGroup(
      title: context.t('profile_check'),
      children: [
        SettingRow(
          title: context.t('checking_active_profiles', {
            'count': activeDiets.length,
          }),
          subtitle: context.t('change_profile_before_save'),
          icon: EatMeGlyph.shieldCheck,
          onTap: () => context.push('/diet-health'),
        ),
        if (reasons.isEmpty && compatibility['status'] == 'fit')
          SettingRow(
            title: context.t('no_known_conflicts'),
            icon: EatMeGlyph.shieldCheck,
          ),
        for (final diet in activeDiets)
          SettingRow(
            title: labelOf(diet['name'], context),
            subtitle: context.t('selected_diet_checked'),
            icon: EatMeGlyph.leaf,
          ),
        for (final reason in reasons)
          SettingRow(
            title: context.t('${reason['code']}'),
            subtitle: context.t(switch (reason['classification']) {
              'hard_safety' => 'hard_safety_conflict',
              'diet' => 'diet_conflict',
              'lifestyle' => 'lifestyle_preference',
              _ => 'ingredient_mapping_incomplete',
            }),
            icon: reason['classification'] == 'hard_safety'
                ? EatMeGlyph.triangleAlert
                : EatMeGlyph.circleAlert,
          ),
        for (final warning in warnings)
          SettingRow(
            title: context.t('${warning['code']}'),
            icon: EatMeGlyph.circleAlert,
          ),
        if ((compatibility['unmapped_ingredients'] as List? ?? []).isNotEmpty)
          SettingRow(
            title: context.t('ingredient_mapping_incomplete'),
            subtitle: context.t('unknown_compat_body'),
            icon: EatMeGlyph.triangleAlert,
          ),
      ],
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.inventory, required this.foods});
  final Json inventory;
  final List<Food> foods;

  @override
  Widget build(BuildContext context) {
    final available = inventory['available_count'] ?? 0;
    final total = inventory['total_count'] ?? 0;
    final missing = List<String>.from(
      inventory['missing_food_ids'] as List? ?? [],
    );
    final soon = List<String>.from(
      inventory['use_soon_food_ids'] as List? ?? [],
    );
    return InformationPanel(
      tinted: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EatMeIcon(
                EatMeGlyph.refrigerator,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('inventory_match'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusBadge(
                label: context.t('ingredients_at_home_count', {
                  'available': available,
                  'total': total,
                }),
                emphasis: true,
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              context.t('missing_ingredients'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 7),
            Text(
              missing.map((id) => _foodName(context, foods, id)).join(' · '),
            ),
          ],
          if (soon.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.t('close_to_date_count', {'count': soon.length}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if ((inventory['unresolved_count'] ?? 0) > 0) ...[
            const SizedBox(height: 14),
            Text(
              context.t('mapping_unresolved_count', {
                'count': inventory['unresolved_count'] ?? 0,
              }),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SubstitutionSelectionPage extends ConsumerStatefulWidget {
  const SubstitutionSelectionPage({
    super.key,
    required this.draft,
    required this.result,
  });
  final Json draft, result;

  @override
  ConsumerState<SubstitutionSelectionPage> createState() =>
      _SubstitutionSelectionPageState();
}

class _SubstitutionSelectionPageState
    extends ConsumerState<SubstitutionSelectionPage> {
  final Map<String, Json> selected = {};

  Future<void> apply() async {
    final draft = _copy(widget.draft);
    final rows = records(draft['ingredient_rows']);
    final adaptations = records(draft['adaptations']);
    for (final entry in selected.entries) {
      final replacement = Map<String, dynamic>.from(entry.value['food'] as Map);
      final rowIndex = rows.indexWhere((row) => row['food_id'] == entry.key);
      if (rowIndex < 0) continue;
      final sameUnit = rows[rowIndex]['unit'] == replacement['unit'];
      rows[rowIndex] = {
        ...rows[rowIndex],
        'food_id': replacement['id'],
        'unit': replacement['unit'],
        'quantity': sameUnit ? rows[rowIndex]['quantity'] : null,
        'mapping_status': sameUnit ? 'matched' : 'needs_review',
        'confirmed': sameUnit,
        'adapted_from_food_id': entry.key,
      };
      adaptations.add({
        'from_food_id': entry.key,
        'to_food_id': replacement['id'],
        'role': entry.value['role'],
      });
    }
    draft['ingredient_rows'] = rows;
    draft['adaptations'] = adaptations;
    await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) => CompatibilityCheckingPage(
          draft: draft,
          adaptedCount: selected.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    final suggestions = records(
      widget.result['substitutions'],
    ).where((item) => records(item['candidates']).isNotEmpty).toList();
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('suggested_substitutions'))),
      body: PageBody(
        children: [
          SocialImportHeader(
            eyebrow: context.t('adaptation_step'),
            title: context.t('make_fit'),
            subtitle: context.t('substitution_review_support'),
          ),
          for (final suggestion in suggestions) ...[
            Text(
              _foodName(context, foods, suggestion['food_id']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final candidate in records(suggestion['candidates'])) ...[
              _SubstitutionCard(
                originalId: '${suggestion['food_id']}',
                candidate: candidate,
                selected:
                    selected['${suggestion['food_id']}']?['food']?['id'] ==
                    candidate['food']?['id'],
                onSelected: () => setState(() {
                  final original = '${suggestion['food_id']}';
                  if (selected[original]?['food']?['id'] ==
                      candidate['food']?['id']) {
                    selected.remove(original);
                  } else {
                    selected[original] = candidate;
                  }
                }),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
          ],
          if (suggestions.isEmpty)
            InformationPanel(
              child: Text(context.t('no_suitable_substitution_body')),
            ),
          const SizedBox(height: 12),
          AsyncAction(
            key: const Key('apply_substitutions'),
            label: context.t('apply_substitutions', {'count': selected.length}),
            enabled: selected.isNotEmpty,
            action: apply,
          ),
          const SizedBox(height: 10),
          AsyncAction(
            label: context.t('edit_manually'),
            secondary: true,
            action: () async {
              await Navigator.push<Json>(
                context,
                MaterialPageRoute(
                  builder: (_) => IngredientMappingPage(draft: widget.draft),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubstitutionCard extends StatelessWidget {
  const _SubstitutionCard({
    required this.originalId,
    required this.candidate,
    required this.selected,
    required this.onSelected,
  });
  final String originalId;
  final Json candidate;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final food = Map<String, dynamic>.from(candidate['food'] as Map);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: EatMeIcon(
                        EatMeGlyph.refreshCw,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelOf(food['name'], context),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.t('substitution_role_${candidate['role']}'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    EatMeIcon(
                      selected
                          ? EatMeGlyph.circleCheck
                          : EatMeGlyph.circleAlert,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: context.t(
                        candidate['at_home'] == true
                            ? 'already_at_home'
                            : 'shopping_required',
                      ),
                      icon: candidate['at_home'] == true
                          ? EatMeGlyph.refrigerator
                          : EatMeGlyph.shoppingBasket,
                    ),
                    StatusBadge(
                      label: context.t(selected ? 'selected' : 'choose'),
                      emphasis: selected,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
