import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../organize/shared.dart';

class CookingPage extends ConsumerStatefulWidget {
  const CookingPage({
    super.key,
    required this.recipeId,
    required this.servings,
    this.participants,
  });
  final String recipeId;
  final int servings;
  final List<String>? participants;
  @override
  ConsumerState<CookingPage> createState() => _CookingPageState();
}

class _CookingPageState extends ConsumerState<CookingPage> {
  late Future<Recipe> future = load();
  Json preview = {};
  Timer? timer;
  DateTime? timerEnd;
  final scrollController = ScrollController();
  int step = 0, remaining = 0, durationMinutes = 5;
  bool confirmation = false;
  final Map<int, int> customTimers = {};
  Future<Recipe> load() async {
    final api = ref.read(apiProvider);
    preview = await api.request(
      'POST',
      '/cooking/preview',
      body: {
        'recipe_id': widget.recipeId,
        'servings': widget.servings,
        if (widget.participants != null) 'participants': widget.participants,
      },
    );
    return Recipe.fromJson(
      await api.request(
        'GET',
        '/recipes/${widget.recipeId}',
        allowCache: false,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
  }

  @override
  void dispose() {
    timer?.cancel();
    scrollController.dispose();
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  void showStep(int next) {
    setState(() => step = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.jumpTo(0);
    });
  }

  Future<void> editTimer(BuildContext context, int? suggestedTimer) async {
    final value = await askText(
      context,
      context.t('timer_minutes'),
      initial: suggestedTimer == null ? '' : '$suggestedTimer',
      numeric: true,
    );
    if (value == null) return;
    final minutes = int.tryParse(value);
    if (minutes == null || minutes < 1 || minutes > 180) {
      throw const ApiFailure('invalid_timer');
    }
    if (mounted) setState(() => customTimers[step] = minutes);
  }

  void toggleTimer([int? requestedMinutes]) {
    if (remaining > 0) {
      timer?.cancel();
      setState(() => remaining = 0);
      return;
    }
    final minutes = requestedMinutes ?? durationMinutes;
    timerEnd = DateTime.now().add(Duration(minutes: minutes));
    setState(() {
      durationMinutes = minutes;
      remaining = minutes * 60;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(
        () => remaining =
            ((timerEnd!.difference(DateTime.now()).inMilliseconds + 999) ~/
                    1000)
                .clamp(0, durationMinutes * 60),
      );
      if (remaining == 0) {
        t.cancel();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.t('timer_done'))));
      }
    });
  }

  String stepTitle(String instruction) {
    final firstClause = instruction.split(RegExp(r'[,.!;:]')).first.trim();
    final words = firstClause.split(RegExp(r'\s+'));
    return words.take(5).join(' ');
  }

  List<Json> ingredientsForStep(String instruction) {
    final normalized = instruction.toLowerCase();
    final ingredients = records(preview['ingredients']);
    final matches = ingredients.where((item) {
      final rawName = item['food']?['name'];
      if (rawName is! Map) return false;
      final name = localized(
        Map<String, dynamic>.from(rawName),
        context.language,
      ).toLowerCase();
      if (normalized.contains(name)) return true;
      return name
          .split(RegExp(r'\s+'))
          .where((word) => word.length > 3)
          .any(normalized.contains);
    }).toList();
    if (matches.isNotEmpty) return matches.take(3).toList();
    return step == 0 ? ingredients.take(3).toList() : const [];
  }

  void showAllSteps(List<String> steps) => sheet(
    context,
    ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          context.t('cooking_all_steps'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < steps.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 18, child: Text('${index + 1}')),
            title: Text(steps[index]),
            selected: index == step,
            onTap: () {
              Navigator.pop(context);
              showStep(index);
            },
          ),
      ],
    ),
  );

  void showIngredients() => sheet(
    context,
    ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          context.t('cooking_ingredients_for', {'count': widget.servings}),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final raw in (preview['ingredients'] as List? ?? []))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              localized(
                Map<String, dynamic>.from(raw['food']['name'] as Map),
                context.language,
              ),
            ),
            subtitle: Text('${raw['quantity'] ?? '—'} ${raw['food']['unit']}'),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Widget _build(BuildContext context) {
    if (confirmation) {
      return ConfirmCookingPage(
        recipeId: widget.recipeId,
        servings: widget.servings,
        participants: widget.participants,
      );
    }
    return FutureBuilder<Recipe>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: EatMeAppBar(title: Text(context.t('cooking_mode'))),
            body: PageBody(
              children: [
                StatusNote(text: context.t('network_error'), warning: true),
                FilledButton(
                  onPressed: () => setState(() => future = load()),
                  child: Text(context.t('retry')),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: EatMeAppBar(title: Text(context.t('cooking_mode'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final recipe = snapshot.data!;
        final steps = recipe.instructions(context.language);
        if (steps.isEmpty) {
          return Scaffold(
            appBar: EatMeAppBar(title: Text(context.t('cooking_mode'))),
            body: PageBody(
              children: [
                StatusNote(text: context.t('recipe_steps_unavailable')),
              ],
            ),
          );
        }
        final suggestedTimer =
            customTimers[step] ?? recipe.timerMinutes(context.language, step);
        final currentIngredients = ingredientsForStep(steps[step]);
        return Scaffold(
          appBar: EatMeAppBar(
            title: Text(context.t('cooking_mode')),
            actions: [
              IconButton(
                tooltip: context.t('cooking_all_steps'),
                onPressed: () => showAllSteps(steps),
                icon: const Icon(Icons.format_list_numbered_rounded),
              ),
            ],
          ),
          bottomNavigationBar: RecipeActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step < steps.length - 1) ...[
                  Text(
                    context.t('next_step_preview', {
                      'step': stepTitle(steps[step + 1]).toLowerCase(),
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: OutlinedButton(
                        onPressed: step > 0 ? () => showStep(step - 1) : null,
                        child: const EatMeIcon(
                          EatMeGlyph.chevronLeft,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (step == steps.length - 1) {
                            setState(() {
                              timer?.cancel();
                              remaining = 0;
                              confirmation = true;
                            });
                          } else {
                            showStep(step + 1);
                          }
                        },
                        child: Text(
                          context.t(
                            step == steps.length - 1
                                ? 'finished_cooking'
                                : 'next_step',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: PageBody(
            controller: scrollController,
            children: [
              Row(
                children: [
                  FoodImage(
                    id: recipe.id,
                    imageUrl: recipe.imageUrl,
                    width: 64,
                    height: 64,
                    radius: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localized(recipe.title, context.language),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.servings} ${context.t('servings')} · ${recipe.minutes} min',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${step + 1} / ${steps.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (step + 1) / steps.length,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 28),
              Text(
                context.t('step_count', {
                  'current': step + 1,
                  'total': steps.length,
                }).toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stepTitle(steps[step]),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 14),
              Text(
                steps[step],
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 17, height: 1.55),
              ),
              if (currentIngredients.isNotEmpty) ...[
                const SizedBox(height: 22),
                InformationPanel(
                  tinted: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('needed_now').toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in currentIngredients)
                            Chip(
                              avatar: const EatMeIcon(
                                EatMeGlyph.utensils,
                                size: 16,
                              ),
                              label: Text(
                                '${item['quantity'] ?? '—'} ${item['food']['unit'] ?? ''} ${localized(Map<String, dynamic>.from(item['food']['name'] as Map), context.language)}',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: showIngredients,
                        icon: const EatMeIcon(
                          EatMeGlyph.refrigerator,
                          size: 18,
                        ),
                        label: Text(context.t('ingredients')),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              InformationPanel(
                tinted: false,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (remaining > 0) ...[
                      Text(
                        context.t('timer_running'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: remaining / (durationMinutes * 60),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => toggleTimer(),
                          icon: const EatMeIcon(EatMeGlyph.timer),
                          label: Text(context.t('cancel')),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const EatMeIcon(EatMeGlyph.timer, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestedTimer == null
                                      ? context.t('cooking_manual_timer')
                                      : context.t('timer_suggested'),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (suggestedTimer != null)
                                  Text(
                                    '${suggestedTimer.toString().padLeft(2, '0')}:00',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => editTimer(context, suggestedTimer),
                            icon: const EatMeIcon(EatMeGlyph.pencil, size: 19),
                            label: Text(context.t('set_timer')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (suggestedTimer == null)
                        SizedBox(
                          width: double.infinity,
                          child: AsyncAction(
                            label: context.t('set_timer'),
                            action: () => editTimer(context, suggestedTimer),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('cooking-start-timer'),
                            onPressed: () => toggleTimer(suggestedTimer),
                            icon: const EatMeIcon(EatMeGlyph.timer),
                            label: Text(
                              context.t('start_timer_minutes', {
                                'count': suggestedTimer,
                              }),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => showAllSteps(steps),
                  icon: const Icon(
                    Icons.format_list_numbered_rounded,
                    size: 19,
                  ),
                  label: Text(context.t('cooking_all_steps')),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class ConfirmCookingPage extends ConsumerStatefulWidget {
  const ConfirmCookingPage({
    super.key,
    required this.recipeId,
    required this.servings,
    this.participants,
  });
  final String recipeId;
  final int servings;
  final List<String>? participants;
  @override
  ConsumerState<ConfirmCookingPage> createState() => _ConfirmCookingPageState();
}

class _ConfirmCookingPageState extends ConsumerState<ConfirmCookingPage> {
  final mutation = Mutation();
  final Map<String, String> overrides = {};
  int leftovers = 0;
  int? savedLeftovers;
  late Future<Json> future = load();
  Json get request => {
    'recipe_id': widget.recipeId,
    'servings': widget.servings,
    if (widget.participants != null) 'participants': widget.participants,
    'consumption': overrides,
  };
  Future<Json> load() =>
      ref.read(apiProvider).request('POST', '/cooking/preview', body: request);
  Future<void> adjust(Json ingredient) async {
    final controller = TextEditingController(
      text: ingredient['quantity'] as String,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('adjust_consumption')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.t('used_from_fridge'),
            suffixText: ingredient['food']['unit'] as String,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().replaceAll(',', '.'),
            ),
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() {
        overrides[ingredient['food_id'] as String] = value;
        future = load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Widget _build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('confirm_cooking'))),
    body: FutureBuilder<Json>(
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
                child: Text(context.t('refresh_preview')),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plan = snapshot.data!;
        final shortages = (plan['shortages'] as List).isNotEmpty;
        return PageBody(
          children: [
            Text(
              context.t('did_you_make_it'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            Text(context.t('confirm_consumption_hint')),
            const SizedBox(height: 24),
            for (final raw in (plan['ingredients'] as List))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InformationPanel(
                  tinted: false,
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => adjust(Map<String, dynamic>.from(raw as Map)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                                      raw['food']['name'] as Map,
                                    ),
                                    context.language,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  '${raw['quantity']} ${raw['food']['unit']}',
                                ),
                              ],
                            ),
                          ),
                          const EatMeIcon(EatMeGlyph.pencil, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (shortages)
              StatusNote(
                text: context.t('consumption_shortage'),
                warning: true,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: leftovers,
              decoration: InputDecoration(
                labelText: context.t('leftover_servings'),
              ),
              items: List.generate(
                widget.servings + 1,
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text(context.t('portions', {'count': n})),
                ),
              ),
              onChanged: (n) => setState(() => leftovers = n!),
            ),
            if (leftovers > 0)
              StatusNote(text: context.t('leftover_date_unknown')),
            const SizedBox(height: 28),
            AsyncAction(
              label: context.t('confirm_update'),
              enabled: !shortages && !ref.watch(appProvider).offline,
              action: () async {
                final data = <String, dynamic>{
                  ...request,
                  'profile_version': plan['profile_version'],
                  if (widget.participants != null)
                    'participant_versions': plan['participant_versions'],
                  'diet_rules_version': plan['diet_rules_version'],
                  'batch_versions': {
                    for (final a in (plan['allocations'] as List))
                      a['batch_id'] as String: a['version'] as int,
                  },
                  'leftover_servings': leftovers,
                };
                if (savedLeftovers == null) {
                  await mutation.send(
                    ref.read(apiProvider),
                    'POST',
                    '/cooking/confirm',
                    data,
                  );
                  savedLeftovers = leftovers;
                }
                await ref
                    .read(appProvider.notifier)
                    .completeGuiltyPleasureMeal();
                await ref.read(appProvider.notifier).refresh();
                if (context.mounted) {
                  context.go(
                    '/cooking-complete?recipe=${widget.recipeId}&leftovers=$savedLeftovers',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t('fridge_updated'))),
                  );
                }
              },
            ),
            TextButton(
              onPressed: () => context.go(
                '/cooking-complete?recipe=${widget.recipeId}&leftovers=0',
              ),
              child: Text(context.t('skip_fridge_update')),
            ),
            TextButton(
              onPressed: () => setState(() => future = load()),
              child: Text(context.t('refresh_preview')),
            ),
          ],
        );
      },
    ),
  );
}

class CookingCompletePage extends StatelessWidget {
  const CookingCompletePage({
    super.key,
    required this.recipeId,
    required this.leftovers,
  });
  final String recipeId;
  final int leftovers;
  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Widget _build(BuildContext context) => Scaffold(
    appBar: const EatMeAppBar(),
    body: PageBody(
      children: [
        EatMeIcon(
          EatMeGlyph.circleCheck,
          size: 88,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          context.t('cooking_complete'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(context.t('cooking_saved'), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (leftovers > 0) ...[
          StatusNote(
            text: context.t('saved_leftover_count', {'count': leftovers}),
          ),
          FilledButton(
            onPressed: () => context.push('/leftovers'),
            child: Text(context.t('manage_leftovers')),
          ),
        ],
        OutlinedButton(
          onPressed: () => context.push('/recipes/$recipeId'),
          child: Text(context.t('share_recipe')),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/chef'),
          child: Text(context.t('back_home')),
        ),
        TextButton(
          onPressed: () => context.go('/fridge'),
          child: Text(context.t('my_fridge')),
        ),
      ],
    ),
  );
}
