import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'fridge.dart';

class ExpiryPage extends ConsumerStatefulWidget {
  const ExpiryPage({super.key});
  @override
  ConsumerState<ExpiryPage> createState() => _ExpiryState();
}
class _ExpiryState extends ConsumerState<ExpiryPage> {
  String location = 'all';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final batches = state.inventory.where((b) => location == 'all' || b.location == location).toList()..sort((a,b) => (a.expiryDate ?? DateTime(9999)).compareTo(b.expiryDate ?? DateTime(9999)));
    final groups = <String,List<Batch>>{};
    for (final batch in batches) {
      final label = batch.expiryDate == null ? context.t('date_unknown') : MaterialLocalizations.of(context).formatFullDate(batch.expiryDate!);
      groups.putIfAbsent(label, () => []).add(batch);
    }
    return Scaffold(appBar: AppBar(title: Text(context.t('expiry_view'))), body: PageBody(onRefresh: () => ref.read(appProvider.notifier).refresh(), children: [
      Wrap(spacing: 8, children: [for (final v in ['all','fridge','freezer','pantry']) ChoiceChip(label: Text(context.t(v == 'all' ? 'food_group_all' : v)), selected: location == v, onSelected: (_) => setState(() => location = v))]),
      if (batches.isEmpty) EmptyMessage(title: context.t('empty_fridge'), body: context.t('empty_fridge_body')),
      for (final group in groups.entries) ...[
        SectionHeading(title: '${group.key} (${group.value.length})'),
        for (final batch in group.value) Card(child: ListTile(leading: FoodMark(food: batch.food), title: Text(localized(batch.food.name, context.language)), subtitle: Text('${batch.quantity} ${batch.food.unit}\n${expiryLabel(context, batch)}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => sheet(context, BatchSheet(batch: batch)))),
      ],
    ]));
  }
}

Future<void> showAddFoodMethods(BuildContext context, {String location = 'fridge'}) async {
  final method = await showModalBottomSheet<String>(context: context, useSafeArea: true, showDragHandle: true, builder: (context) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
    Text(context.t('add_food'), style: Theme.of(context).textTheme.headlineMedium),
    for (final item in [('scan_and_import', Icons.camera_alt_outlined, 'scan'),('scan_barcode', Icons.view_week_outlined, 'barcode'),('search_food', Icons.search, 'search'),('custom_food', Icons.add, 'custom')]) ListTile(leading: IconBadge(item.$2), title: Text(context.t(item.$1)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(context,item.$3)),
  ]));
  if (!context.mounted || method == null) return;
  if (method == 'search') { await sheet(context, AddFoodSheet(location: location == 'all' ? 'fridge' : location)); }
  else { await context.push(method == 'scan' ? '/scanning' : method == 'barcode' ? '/barcode' : '/custom-food'); }
}
