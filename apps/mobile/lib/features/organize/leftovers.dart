import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import '../../core/api.dart';
import '../../core/state.dart';
import 'leftover_remix.dart';

class LeftoversPage extends ConsumerStatefulWidget {
  const LeftoversPage({super.key});
  @override
  ConsumerState<LeftoversPage> createState() => _LeftoversState();
}

class _LeftoversState extends ResourceState<LeftoversPage> {
  @override
  String get path => '/leftovers';
  String tab = 'available';
  @override
  Widget build(BuildContext context) {
    final items = records(
      data?['items'],
    ).where((i) => (i['remaining'] as int) > 0).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('leftovers')),
        actions: [
          IconButton(
            tooltip: context.t('add_leftovers'),
            icon: const Icon(Icons.add),
            onPressed: () => guard(() async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const AddLeftoversPage()),
              );
              await load();
            }),
          ),
        ],
      ),
      body: content([
        Text(
          context.t('another_good_meal'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: context.t('leftover_dates_notice')),
        Wrap(
          spacing: 8,
          children: [
            for (final value in ['available', 'reuse'])
              ChoiceChip(
                label: Text(context.t('leftovers_$value')),
                selected: tab == value,
                onSelected: (_) => setState(() => tab = value),
              ),
          ],
        ),
        if (items.isEmpty)
          EmptyMessage(
            title: context.t('no_leftovers'),
            body: context.t('leftover_empty_body'),
          ),
        for (final item in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FoodImage(
                    id: item['recipe_id'] as String? ?? '',
                    height: 130,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    labelOf(item['recipe_title'], context),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${item['remaining']} ${context.t('servings')} · ${context.t(item['location'] as String)}',
                  ),
                  if (item['user_use_date'] != null)
                    Text(
                      '${context.t('your_use_date')}: ${item['user_use_date']}',
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (tab == 'reuse')
                        AsyncAction(
                          label: context.t('remix_leftovers'),
                          secondary: true,
                          action: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => LeftoverRemixPage(item: item),
                              ),
                            );
                            await load();
                          },
                        ),
                      for (final action
                          in (tab == 'available'
                              ? ['consume', 'discard']
                              : <String>[]))
                        AsyncAction(
                          label: context.t(action),
                          secondary: action == 'discard',
                          action: () async {
                            final amount = await askText(
                              context,
                              context.t('servings'),
                              initial: '1',
                              numeric: true,
                            );
                            if (amount != null) {
                              await command({
                                'action': action,
                                'id': item['id'],
                                'expected_version': item['version'],
                                'servings': int.tryParse(amount) ?? 0,
                              });
                            }
                          },
                        ),
                      AsyncAction(
                        label: context.t('move'),
                        secondary: true,
                        action: () async {
                          await command({
                            'action': 'move',
                            'id': item['id'],
                            'expected_version': item['version'],
                            'location': item['location'] == 'fridge'
                                ? 'freezer'
                                : 'fridge',
                          });
                        },
                      ),
                      AsyncAction(
                        label: context.t('your_use_date'),
                        secondary: true,
                        action: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null) {
                            await command({
                              'action': 'date',
                              'id': item['id'],
                              'expected_version': item['version'],
                              'user_use_date': isoDay(date),
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

class AddLeftoversPage extends ConsumerStatefulWidget {
  const AddLeftoversPage({super.key});
  @override
  ConsumerState<AddLeftoversPage> createState() => _AddLeftoversState();
}

class _AddLeftoversState extends ResourceState<AddLeftoversPage> {
  @override
  String get path => '/recipes';
  String? recipeId;
  String location = 'fridge';
  int servings = 1;
  DateTime prepared = DateUtils.dateOnly(DateTime.now());
  DateTime? useDate;
  bool confirmed = false, saved = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('add_leftovers'))),
    body: content([
      StatusNote(text: context.t('external_leftovers_notice')),
      if (records(data?['items']).isEmpty)
        StatusNote(text: context.t('create_recipe_first')),
      DropdownButtonFormField<String>(
        initialValue: recipeId,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.t('recipe')),
        items: records(data?['items'])
            .map(
              (r) => DropdownMenuItem(
                value: r['id'] as String,
                child: Text(
                  labelOf(r['title'], context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() {
          recipeId = v;
          confirmed = false;
        }),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        initialValue: servings,
        decoration: InputDecoration(labelText: context.t('servings')),
        items: List.generate(
          20,
          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
        ),
        onChanged: (v) => setState(() => servings = v!),
      ),
      DropdownButtonFormField<String>(
        initialValue: location,
        decoration: InputDecoration(labelText: context.t('storage')),
        items: ['fridge', 'freezer']
            .map((v) => DropdownMenuItem(value: v, child: Text(context.t(v))))
            .toList(),
        onChanged: (v) => setState(() => location = v!),
      ),
      ListTile(
        title: Text(context.t('preparation_date')),
        subtitle: Text(isoDay(prepared)),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: prepared,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted)
            {
            setState(() {
              prepared = date;
              if (useDate != null && useDate!.isBefore(date)) useDate = null;
            });
            }
        },
      ),
      ListTile(
        title: Text(context.t('your_use_date')),
        subtitle: Text(
          useDate == null ? context.t('optional') : isoDay(useDate!),
        ),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: useDate ?? DateTime.now(),
            firstDate: prepared,
            lastDate: DateTime(2100),
          );
          if (date != null && mounted) setState(() => useDate = date);
        },
      ),
      if (useDate != null)
        TextButton(
          onPressed: () => setState(() => useDate = null),
          child: Text(context.t('remove_date')),
        ),
      if (recipeId != null) ...[
        SectionHeading(title: context.t('ingredients')),
        for (final ingredient in records(
          records(
            data?['items'],
          ).firstWhere((r) => r['id'] == recipeId)['ingredients'],
        ))
          Text(
            labelOf(
              ref
                      .read(appProvider)
                      .foods
                      .where((f) => f.id == ingredient['food_id'])
                      .firstOrNull
                      ?.name ??
                  {},
              context,
            ),
          ),
      ],
      CheckboxListTile(
        value: confirmed,
        title: Text(context.t('confirm_leftover_ingredients')),
        onChanged: (v) => setState(() => confirmed = v ?? false),
      ),
      AsyncAction(
        label: context.t('save'),
        enabled: recipeId != null && confirmed,
        action: () async {
          if (saved) {
            await ref.read(appProvider.notifier).refresh();
            if (context.mounted) Navigator.pop(context);
            return;
          }
          await mutation.send(ref.read(apiProvider), 'POST', '/leftovers', {
            'action': 'create',
            'recipe_id': recipeId,
            'servings': servings,
            'prepared_at': isoDay(prepared),
            'location': location,
            'user_use_date': useDate == null ? null : isoDay(useDate!),
            'ingredients_confirmed': confirmed,
          });
          saved = true;
          await ref.read(appProvider.notifier).refresh();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ]),
  );
}
