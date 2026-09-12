import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class LeftoverRemixPage extends ConsumerStatefulWidget {
  const LeftoverRemixPage({super.key, required this.item});
  final Json item;
  @override
  ConsumerState<LeftoverRemixPage> createState() => _RemixState();
}

class _RemixState extends ConsumerState<LeftoverRemixPage> {
  final title = TextEditingController(),
      steps = TextEditingController(),
      servings = TextEditingController(text: '1');
  final mutation = Mutation();
  final additions = <Json>[];
  List<String>? participants;
  Json? plan;
  bool prepared = false;
  @override
  void dispose() {
    for (final controller in [title, steps, servings]) {
      controller.dispose();
    }
    super.dispose();
  }

  Json body() => {
    'id': widget.item['id'],
    'expected_version': widget.item['version'],
    'servings': int.tryParse(servings.text) ?? 0,
    if (participants != null) 'participants': participants,
    'recipe': {
      'title': title.text,
      'servings': int.tryParse(servings.text) ?? 0,
      'minutes': 10,
      'ingredients': additions,
      'steps': steps.text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(),
    },
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('remix_leftovers'))),
    body: PageBody(
      children: [
        Text(
          labelOf(widget.item['recipe_title'], context),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        StatusNote(text: context.t('remix_notice')),
        TextField(
          controller: title,
          enabled: plan == null,
          maxLength: 160,
          decoration: InputDecoration(labelText: context.t('recipe_name')),
        ),
        TextField(
          controller: servings,
          enabled: plan == null,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${context.t('reused_servings')} (1–${widget.item['remaining']})',
          ),
        ),
        const SizedBox(height: 16),
        AsyncAction(
          label: context.t('who_is_eating'),
          secondary: true,
          enabled: plan == null,
          action: () async {
            final value = await chooseDiners(
              context,
              ref.read(apiProvider),
              participants,
            );
            if (value != null && mounted) setState(() => participants = value);
          },
        ),
        const SizedBox(height: 16),
        for (final item in additions)
          ListTile(
            title: Text(
              ref
                  .read(appProvider)
                  .foods
                  .where((food) => food.id == item['food_id'])
                  .map(
                    (food) =>
                        '${localized(food.name, context.language)} · ${item['quantity']} ${food.unit}',
                  )
                  .first,
            ),
            trailing: IconButton(
              tooltip: context.t('delete'),
              icon: const Icon(Icons.close),
              onPressed: plan == null
                  ? () => setState(() => additions.remove(item))
                  : null,
            ),
          ),
        AsyncAction(
          label: context.t('additional_ingredient'),
          secondary: true,
          enabled: plan == null,
          action: () async {
            final food = await chooseFood(context, ref.read(appProvider).foods);
            if (food == null || !context.mounted) return;
            final quantity = await askText(
              context,
              '${context.t('quantity')} (${food.unit})',
              numeric: true,
            );
            if (quantity != null && mounted) {
              setState(
                () => additions.add({'food_id': food.id, 'quantity': quantity}),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: steps,
          enabled: plan == null,
          minLines: 3,
          maxLines: 8,
          maxLength: 20000,
          decoration: InputDecoration(
            labelText: context.t('recipe_steps'),
            helperText: context.t('one_step_per_line'),
          ),
        ),
        const SizedBox(height: 16),
        if (plan == null)
          AsyncAction(
            label: context.t('review_remix'),
            enabled: additions.isNotEmpty,
            action: () async {
              final value = await mutation.send(
                ref.read(apiProvider),
                'POST',
                '/leftovers',
                {...body(), 'action': 'transform_preview'},
              );
              if (mounted) setState(() => plan = value);
            },
          )
        else ...[
          if ((plan!['shortages'] as List).isNotEmpty)
            StatusNote(text: context.t('consumption_shortage'), warning: true),
          TextButton(
            onPressed: () => setState(() {
              plan = null;
              prepared = false;
            }),
            child: Text(context.t('edit')),
          ),
          CheckboxListTile(
            value: prepared,
            onChanged: (value) => setState(() => prepared = value == true),
            title: Text(context.t('remix_prepared')),
          ),
          AsyncAction(
            label: context.t('confirm_update'),
            enabled: prepared && (plan!['shortages'] as List).isEmpty,
            action: () async {
              await mutation.send(ref.read(apiProvider), 'POST', '/leftovers', {
                ...body(),
                'action': 'transform',
                'preparation_confirmed': true,
                'participant_versions': plan!['participant_versions'],
                'diet_rules_version': plan!['diet_rules_version'],
                'batch_versions': {
                  for (final item in plan!['allocations'] as List)
                    item['batch_id'] as String: item['version'],
                },
              });
              await ref.read(appProvider.notifier).refresh();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ],
    ),
  );
}
