import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

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
    if (food == null || !mounted) return;
    final amount = await askText(context, '${context.t('quantity')} (${food.unit})', initial: food.unit == 'pcs' ? '1' : '100', numeric: true);
    if (amount == null) return;
    await command({'action': 'add', 'food_id': food.id, 'quantity': amount});
  }
  Future<void> purchase(Json item) async {
    await command({'action': 'purchase', 'id': item['id'], 'expected_version': item['version'], 'location': 'fridge'});
    await ref.read(appProvider.notifier).refresh();
  }
  @override
  Widget build(BuildContext context) {
    final items = records(data?['items']);
    final checked = items.where((i) => i['checked'] == true).length;
    return Scaffold(appBar: AppBar(title: Text(context.t('shopping_list'))), body: content([
      Text(context.t('shopping_intro'), style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text(context.t('shopping_progress', {'done': checked, 'total': items.length})),
      const SizedBox(height: 20),
      AsyncAction(label: context.t('add_food'), action: add),
      if (items.isEmpty) EmptyMessage(title: context.t('shopping_empty'), body: context.t('shopping_empty_body')),
      for (final item in items) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: item['checked'] == true,
          title: Text(item['label'] as String), subtitle: Text('${item['quantity']} ${item['unit']}'),
          onChanged: (value) async {
            try { await command({'action': 'check', 'id': item['id'], 'expected_version': item['version'], 'checked': value}); }
            catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('retry')))); }
          }),
        Wrap(spacing: 8, children: [
          if (item['checked'] == true) AsyncAction(label: context.t('put_in_fridge'), action: () => purchase(item)),
          AsyncAction(label: context.t('edit'), secondary: true, action: () async {
            final amount = await askText(context, context.t('quantity'), initial: item['quantity'] as String, numeric: true);
            if (amount != null) await command({'action': 'edit', 'id': item['id'], 'expected_version': item['version'], 'quantity': amount});
          }),
          AsyncAction(label: context.t('delete'), secondary: true, action: () async { await command({'action': 'delete', 'id': item['id'], 'expected_version': item['version']}); }),
        ]),
      ]))),
    ]));
  }
}
