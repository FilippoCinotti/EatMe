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

class CookingPage extends ConsumerStatefulWidget {
  const CookingPage({
    super.key,
    required this.recipeId,
    required this.servings,
  });
  final String recipeId;
  final int servings;
  @override
  ConsumerState<CookingPage> createState() => _CookingPageState();
}

class _CookingPageState extends ConsumerState<CookingPage> {
  late Future<Recipe> future = load();
  Timer? timer;
  int step = 0, remaining = 0;
  bool confirmation = false;
  Future<Recipe> load() async => Recipe.fromJson(
    await ref.read(apiProvider).request('GET', '/recipes/${widget.recipeId}'),
  );
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
    setState(() => remaining = 300);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => remaining--);
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
    if (confirmation)
      return ConfirmCookingPage(
        recipeId: widget.recipeId,
        servings: widget.servings,
      );
    return Scaffold(
      appBar: AppBar(title: Text(context.t('cooking_mode'))),
      body: FutureBuilder<Recipe>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return PageBody(
              children: [
                StatusNote(text: context.t('network_error'), warning: true),
                FilledButton(
                  onPressed: () => setState(() => future = load()),
                  child: Text(context.t('retry')),
                ),
              ],
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
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
              const SizedBox(height: 40),
              Text(
                steps[step],
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),
              OutlinedButton.icon(
                onPressed: toggleTimer,
                icon: const Icon(Icons.timer_outlined),
                label: Text(
                  remaining == 0
                      ? context.t('five_min_timer')
                      : '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() {
                  if (step == steps.length - 1) {
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
  });
  final String recipeId;
  final int servings;
  @override
  ConsumerState<ConfirmCookingPage> createState() => _ConfirmCookingPageState();
}

class _ConfirmCookingPageState extends ConsumerState<ConfirmCookingPage> {
  final mutation = Mutation();
  final Map<String, String> overrides = {};
  int leftovers = 0;
  late Future<Json> future = load();
  Json get request => {
    'recipe_id': widget.recipeId,
    'servings': widget.servings,
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
    if (value != null && mounted)
      setState(() {
        overrides[ingredient['food_id'] as String] = value;
        future = load();
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('confirm_cooking'))),
    body: FutureBuilder<Json>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError)
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
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
                  'diet_rules_version': plan['diet_rules_version'],
                  'batch_versions': {
                    for (final a in (plan['allocations'] as List))
                      a['batch_id'] as String: a['version'] as int,
                  },
                  'leftover_servings': leftovers,
                };
                await mutation.send(
                  ref.read(apiProvider),
                  'POST',
                  '/cooking/confirm',
                  data,
                );
                await ref.read(appProvider.notifier).refresh();
                if (context.mounted) {
                  context.go('/fridge');
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
