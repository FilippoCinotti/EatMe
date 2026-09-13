import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import '../../core/share_text.dart';

class ShoppingPage extends ConsumerStatefulWidget {
  const ShoppingPage({super.key});
  @override
  ConsumerState<ShoppingPage> createState() => _ShoppingState();
}

class _ShoppingState extends ResourceState<ShoppingPage> {
  @override
  String get path => '/shopping';
  Future<void> add() async {
    final food = await chooseFood(context, ref.read(appProvider).foods);
    if (food == null || !mounted || !context.mounted) return;
    final amount = await askText(
      context,
      '${context.t('quantity')} (${food.unit})',
      initial: food.unit == 'pcs' ? '1' : '100',
      numeric: true,
    );
    if (amount == null) return;
    await command({'action': 'add', 'food_id': food.id, 'quantity': amount});
  }

  Future<void> purchase(Json item) async {
    await command({
      'action': 'purchase',
      'id': item['id'],
      'expected_version': item['version'],
      'location': 'fridge',
    });
    await ref.read(appProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = records(data?['items']);
    final categories =
        items.map((i) => i['category'] as String? ?? 'other').toSet().toList()
          ..sort();
    final checked = items.where((i) => i['checked'] == true).length;
    return Scaffold(
      appBar: EatMeAppBar(
        title: Text(context.t('shopping_list')),
        actions: [
          IconButton(
            tooltip: context.t('share'),
            icon: const Icon(Icons.ios_share),
            onPressed: items.isEmpty
                ? null
                : () => shareText(
                    context,
                    context.t('shopping_list'),
                    categories
                        .map(
                          (category) =>
                              '${context.t('food_group_$category')}\n${items.where((i) => (i['category'] ?? 'other') == category).map((i) => "${i['checked'] == true ? '✓' : '☐'} ${i['label']} — ${i['quantity']} ${i['unit']}").join('\n')}',
                        )
                        .join('\n\n'),
                  ),
          ),
        ],
      ),
      body: content([
        Text(
          context.t('shopping_intro'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          context.t('shopping_progress', {
            'done': checked,
            'total': items.length,
          }),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: items.isEmpty ? 0 : checked / items.length,
            minHeight: 5,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(height: 20),
        AsyncAction(label: context.t('add_food'), action: add),
        if (items.isEmpty)
          EmptyMessage(
            title: context.t('shopping_empty'),
            body: context.t('shopping_empty_body'),
          ),
        for (final category in categories) ...[
          SectionHeading(title: context.t('food_group_$category')),
          Text(
            context.t('shopping_progress', {
              'done': items
                  .where(
                    (i) =>
                        (i['category'] ?? 'other') == category &&
                        i['checked'] == true,
                  )
                  .length,
              'total': items
                  .where((i) => (i['category'] ?? 'other') == category)
                  .length,
            }),
          ),
          for (final item in items.where(
            (i) => (i['category'] ?? 'other') == category,
          ))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: FoodImage(
                        id: '${item['food_id'] ?? ''}',
                        width: 48,
                        height: 48,
                        radius: 12,
                        fallback: Icons.shopping_bag_outlined,
                      ),
                      value: item['checked'] == true,
                      title: Text(item['label'] as String),
                      subtitle: Text('${item['quantity']} ${item['unit']}'),
                      onChanged: (value) async {
                        try {
                          await command({
                            'action': 'check',
                            'id': item['id'],
                            'expected_version': item['version'],
                            'checked': value,
                          });
                        } catch (_) {
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.t('retry'))),
                            );
                          }
                        }
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (item['checked'] == true)
                          AsyncAction(
                            label: context.t('put_in_fridge'),
                            action: () => purchase(item),
                          ),
                        AsyncAction(
                          label: context.t('edit'),
                          secondary: true,
                          action: () async {
                            final amount = await askText(
                              context,
                              context.t('quantity'),
                              initial: item['quantity'] as String,
                              numeric: true,
                            );
                            if (amount != null) {
                              await command({
                                'action': 'edit',
                                'id': item['id'],
                                'expected_version': item['version'],
                                'quantity': amount,
                              });
                            }
                          },
                        ),
                        AsyncAction(
                          label: context.t('delete'),
                          secondary: true,
                          action: () async {
                            await command({
                              'action': 'delete',
                              'id': item['id'],
                              'expected_version': item['version'],
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ]),
    );
  }
}
