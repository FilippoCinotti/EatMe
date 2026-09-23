import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> reconcilePurchased(List<Json> candidates) async {
    final selected = candidates.map((item) => item['id'] as String).toSet();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('add_purchased_to_fridge'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(context.t('purchase_reconciliation_body')),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in candidates)
                        EatMeToggleRow(
                          title: item['label'] as String,
                          subtitle: '${item['quantity']} ${item['unit']}',
                          icon: EatMeGlyph.shoppingBasket,
                          value: selected.contains(item['id']),
                          onChanged: (value) => update(
                            () => value
                                ? selected.add(item['id'] as String)
                                : selected.remove(item['id']),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(sheetContext, true),
                child: Text(
                  context.t('add_selected_to_fridge', {
                    'count': selected.length,
                  }),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(context.t('not_now')),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final item in candidates.where(
      (item) => selected.contains(item['id']),
    )) {
      await purchase(item);
    }
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
            icon: const EatMeIcon(EatMeGlyph.fileText),
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
        EatMeTabStrip(
          values: [
            ('plan', context.t('my_plan')),
            ('dinners', context.t('dinners')),
            ('shopping', context.t('shopping_list')),
          ],
          selected: 'shopping',
          onSelected: (value) {
            if (value == 'plan') context.go('/plan');
            if (value == 'dinners') context.go('/plan/dinners');
          },
        ),
        const SizedBox(height: 14),
        const KitchenLoopBanner(),
        const SizedBox(height: 24),
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
        if (items.any(
          (item) => item['checked'] == true && item['food_id'] != null,
        )) ...[
          const SizedBox(height: 10),
          AsyncAction(
            label: context.t('add_purchased_to_fridge'),
            secondary: true,
            action: () => reconcilePurchased(
              items
                  .where(
                    (item) =>
                        item['checked'] == true && item['food_id'] != null,
                  )
                  .toList(),
            ),
          ),
        ],
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InformationPanel(
                tinted: false,
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
