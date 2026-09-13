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
  Timer? timer;
  DateTime? timerEnd;
  int step = 0, remaining = 0, durationMinutes = 5;
  bool confirmation = false;
  Future<Recipe> load() async {
    final api = ref.read(apiProvider);
    await api.request(
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
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  void toggleTimer() {
    if (remaining > 0) {
      timer?.cancel();
      setState(() => remaining = 0);
      return;
    }
    timerEnd = DateTime.now().add(Duration(minutes: durationMinutes));
    setState(() => remaining = durationMinutes * 60);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('timer_done'))));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (confirmation) {
      return ConfirmCookingPage(
        recipeId: widget.recipeId,
        servings: widget.servings,
        participants: widget.participants,
      );
    }
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('cooking_mode'))),
      body: FutureBuilder<Recipe>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return PageBody(
              children: [
                StatusNote(text: context.t('network_error'), warning: true),
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
          final steps = snapshot.data!.instructions(context.language);
          return PageBody(
            children: [
              Text(
                context.t('step_count', {
                  'current': step + 1,
                  'total': steps.length,
                }),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 16),
              FoodImage(id: widget.recipeId, height: 190, radius: 22),
              const SizedBox(height: 20),
              Text(
                steps[step],
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              if (remaining > 0) ...[
                Center(
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: remaining / (durationMinutes * 60),
                            strokeWidth: 7,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                        ),
                        const Icon(Icons.timer_outlined, size: 32),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (remaining == 0)
                AsyncAction(
                  label: context.t('set_timer'),
                  secondary: true,
                  action: () async {
                    final value = await askText(
                      context,
                      context.t('timer_minutes'),
                      initial: '$durationMinutes',
                      numeric: true,
                    );
                    if (value == null) return;
                    final minutes = int.tryParse(value);
                    if (minutes == null || minutes < 1 || minutes > 180) {
                      throw const ApiFailure('invalid_timer');
                    }
                    if (mounted) setState(() => durationMinutes = minutes);
                  },
                ),
              OutlinedButton.icon(
                onPressed: toggleTimer,
                icon: const Icon(Icons.timer_outlined),
                label: Text(
                  remaining == 0
                      ? context.t('start_timer_minutes', {
                          'count': durationMinutes,
                        })
                      : '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() {
                  if (step == steps.length - 1) {
                    timer?.cancel();
                    remaining = 0;
                    confirmation = true;
                  } else {
                    step++;
                  }
                }),
                child: Text(
                  context.t(
                    step == steps.length - 1 ? 'finished_cooking' : 'next_step',
                  ),
                ),
              ),
              if (step > 0)
                TextButton(
                  onPressed: () => setState(() => step--),
                  child: Text(context.t('previous_step')),
                ),
            ],
          );
        },
      ),
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
  Widget build(BuildContext context) => Scaffold(
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  localized(
                    Map<String, dynamic>.from(raw['food']['name'] as Map),
                    context.language,
                  ),
                ),
                subtitle: Text('${raw['quantity']} ${raw['food']['unit']}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => adjust(Map<String, dynamic>.from(raw as Map)),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: const EatMeAppBar(),
    body: PageBody(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 88,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          context.t('cooking_complete'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
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
