import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import 'shopping_estimate.dart';
import '../../core/share_text.dart';

class ShoppingPage extends ConsumerStatefulWidget {
  const ShoppingPage({super.key});
  @override
  ConsumerState<ShoppingPage> createState() => _ShoppingState();
}

class _ShoppingState extends ResourceState<ShoppingPage> {
  @override
  String get path => '/shopping';

  /// Generated rows store the English catalog name; show catalog foods in the
  /// app language. A name the user typed for a food stays as written.
  String itemLabel(Json item) {
    final label = item['label'] as String;
    final food = ref
        .read(appProvider)
        .foods
        .where((food) => food.id == item['food_id'])
        .firstOrNull;
    if (food == null || label != localized(food.name, 'en')) return label;
    return localized(food.name, context.language);
  }

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
              const SizedBox(height: 8),
              Text(
                context.t('purchase_estimate_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in candidates)
                        EatMeToggleRow(
                          title: itemLabel(item),
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
    // One atomic request: every line gets an estimated date from typical
    // shelf life, which the user can still edit from Fridge.
    final result = await command({
      'action': 'purchase_many',
      'location': 'fridge',
      'estimate_expiry': true,
      'items': [
        for (final item in candidates.where(
          (item) => selected.contains(item['id']),
        ))
          {'id': item['id'], 'expected_version': item['version']},
      ],
    });
    await ref.read(appProvider.notifier).refresh();
    if (!mounted) return;
    final count = (result['purchased'] as List? ?? const []).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('purchased_summary', {'count': count}))),
    );
  }

  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Food? itemFood(Json item) => ref
      .read(appProvider)
      .foods
      .where((food) => food.id == item['food_id'])
      .firstOrNull;

  String categoryOf(Json item) {
    final category = '${item['category'] ?? itemFood(item)?.group ?? 'other'}';
    final strings = Localizations.of<EatMeStrings>(context, EatMeStrings)!;
    return strings.values.containsKey('food_group_$category')
        ? category
        : 'other';
  }

  ShoppingEstimate? estimate(Json item) => ShoppingEstimate.forQuantity(
    itemFood(item)?.group ?? '${item['category'] ?? 'other'}',
    '${item['unit']}',
    item['quantity'],
  );

  String money(int cents) {
    final separator = const {'en', 'zh'}.contains(context.language) ? '.' : ',';
    return '€ ${(cents ~/ 100)}$separator${(cents % 100).toString().padLeft(2, '0')}';
  }

  String exportList(List<Json> items) {
    final categories = items.map(categoryOf).toSet().toList()..sort();
    final known = items.map(estimate).whereType<ShoppingEstimate>().toList();
    final total = known.fold<int>(0, (sum, price) => sum + price.cents);
    final lines = <String>[];
    for (final category in categories) {
      lines.add(context.t('food_group_$category'));
      for (final item in items.where((i) => categoryOf(i) == category)) {
        final price = estimate(item);
        final label = price == null
            ? context.t('shopping_price_unavailable')
            : context.t('shopping_line_estimate', {
                'price': money(price.cents),
              });
        lines.add(
          "${item['checked'] == true ? '✓' : '☐'} ${itemLabel(item)} — ${item['quantity']} ${item['unit']} · $label",
        );
      }
      lines.add('');
    }
    final totalLabel = context.t(
      known.length == items.length
          ? 'shopping_total_estimated'
          : 'shopping_total_partial',
    );
    lines.add('$totalLabel: ${known.isEmpty ? '—' : money(total)}');
    if (known.length < items.length) {
      lines.add(
        context.t('shopping_unpriced_count', {
          'count': items.length - known.length,
        }),
      );
    }
    lines.add(context.t('shopping_estimate_basis'));
    return lines.join('\n');
  }

  Widget _build(BuildContext context) {
    ref.watch(appProvider);
    final items = records(data?['items']);
    final categories = items.map(categoryOf).toSet().toList()..sort();
    final checked = items.where((i) => i['checked'] == true).length;
    final estimates = items.map(estimate).toList();
    final known = estimates.whereType<ShoppingEstimate>().toList();
    final total = known.fold<int>(0, (sum, price) => sum + price.cents);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
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
                    exportList(items),
                  ),
          ),
        ],
      ),
      body: content([
        EatMeTabStrip(
          values: [
            ('plan', context.t('my_plan')),
            ('dinners', context.t('with_friends')),
            ('shopping', context.t('shopping_list')),
          ],
          selected: 'shopping',
          onSelected: (value) {
            if (value == 'plan') context.go('/plan');
            if (value == 'dinners') context.go('/plan/dinners');
          },
        ),
        const SizedBox(height: 20),
        InformationPanel(
          tinted: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('shopping_intro'), style: text.titleMedium),
              const SizedBox(height: 16),
              Text(
                context.t(
                  known.length == items.length
                      ? 'shopping_total_estimated'
                      : 'shopping_total_partial',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                known.isEmpty ? '—' : money(total),
                key: const ValueKey('shopping-total'),
                style: text.headlineSmall?.copyWith(
                  fontFamily: 'EatMeDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('shopping_estimate_basis'),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (known.length < items.length) ...[
                const SizedBox(height: 6),
                Text(
                  context.t('shopping_unpriced_count', {
                    'count': items.length - known.length,
                  }),
                  style: text.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                context.t('shopping_progress', {
                  'done': checked,
                  'total': items.length,
                }),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: items.isEmpty ? 0 : checked / items.length,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AsyncAction(label: context.t('add_food'), icon: Icons.add, action: add),
        if (items.any(
          (item) => item['checked'] == true && item['food_id'] != null,
        )) ...[
          const SizedBox(height: 8),
          AsyncAction(
            key: const ValueKey('did-the-shopping'),
            label: context.t('did_the_shopping'),
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
          const SizedBox(height: 24),
          Text(context.t('food_group_$category'), style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            context.t('shopping_progress', {
              'done': items
                  .where(
                    (i) => categoryOf(i) == category && i['checked'] == true,
                  )
                  .length,
              'total': items.where((i) => categoryOf(i) == category).length,
            }),
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final item in items.where((i) => categoryOf(i) == category))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _itemCard(context, item),
            ),
        ],
      ]),
    );
  }

  Widget _itemCard(BuildContext context, Json item) {
    final food = itemFood(item);
    final price = estimate(item);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InformationPanel(
      tinted: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodImage(
                id: '${item['food_id'] ?? ''}',
                photoId: food?.photoId,
                imageUrl: food?.imageUrl,
                width: 56,
                height: 56,
                radius: 12,
                fallback: Icons.shopping_bag_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemLabel(item),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: item['checked'] == true
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['quantity']} ${item['unit']}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price == null
                          ? context.t('shopping_price_unavailable')
                          : context.t('shopping_line_estimate', {
                              'price': money(price.cents),
                            }),
                      style: text.bodySmall?.copyWith(
                        color: price == null
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (price != null)
                      Text(
                        context.t('shopping_unit_reference', {
                          'price': money(price.referenceCents),
                          'unit': price.referenceUnit == 'pcs'
                              ? context.t('shopping_each')
                              : price.referenceUnit,
                        }),
                        style: text.bodySmall?.copyWith(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  semanticLabel: itemLabel(item),
                  value: item['checked'] == true,
                  onChanged: updating
                      ? null
                      : (value) async {
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
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item['checked'] == true)
                  AsyncAction(
                    label: context.t('put_in_fridge'),
                    secondary: true,
                    action: () => purchase(item),
                  ),
                AsyncAction(
                  label: context.t('edit'),
                  icon: Icons.edit_outlined,
                  iconOnly: true,
                  secondary: true,
                  action: () async {
                    final amount = await askText(
                      context,
                      context.t('quantity'),
                      initial: '${item['quantity']}',
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
                  icon: Icons.delete_outline,
                  iconOnly: true,
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
          ),
        ],
      ),
    );
  }
}
