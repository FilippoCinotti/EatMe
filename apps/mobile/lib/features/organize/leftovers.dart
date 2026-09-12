import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import 'leftover_remix.dart';

class LeftoversPage extends ConsumerStatefulWidget {
  const LeftoversPage({super.key});
  @override
  ConsumerState<LeftoversPage> createState() => _LeftoversState();
}

class _LeftoversState extends ResourceState<LeftoversPage> {
  @override
  String get path => '/leftovers';
  @override
  Widget build(BuildContext context) {
    final items = records(
      data?['items'],
    ).where((i) => (i['remaining'] as int) > 0).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('leftovers'))),
      body: content([
        Text(
          context.t('another_good_meal'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: context.t('leftover_dates_notice')),
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
                      AsyncAction(label: context.t('remix_leftovers'), secondary: true, action: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LeftoverRemixPage(item: item)));
                        await load();
                      }),
                      for (final action in ['consume', 'discard'])
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
                            if (amount != null)
                              await command({
                                'action': action,
                                'id': item['id'],
                                'expected_version': item['version'],
                                'servings': int.tryParse(amount) ?? 0,
                              });
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
                          if (date != null)
                            await command({
                              'action': 'date',
                              'id': item['id'],
                              'expected_version': item['version'],
                              'user_use_date': isoDay(date),
                            });
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
