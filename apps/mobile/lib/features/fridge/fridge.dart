import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class FridgePage extends ConsumerStatefulWidget {
  const FridgePage({super.key});
  @override
  ConsumerState<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends ConsumerState<FridgePage> {
  String location = 'fridge', search = '';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final items = state.inventory
        .where(
          (b) =>
              b.location == location &&
              localized(
                b.food.name,
                context.language,
              ).toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('my_fridge')),
        actions: [
          IconButton(
            tooltip: context.t('scan_and_import'),
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => context.push('/scanning'),
          ),

          IconButton(
            tooltip: context.t('add_food'),
            onPressed: state.offline
                ? null
                : () => sheet(context, AddFoodSheet(location: location)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          SegmentedButton<String>(
            segments: ['fridge', 'freezer', 'pantry']
                .map((s) => ButtonSegment(value: s, label: Text(context.t(s))))
                .toList(),
            selected: {location},
            onSelectionChanged: (v) => setState(() => location = v.first),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: context.t('search_food'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (s) => setState(() => search = s),
          ),
          const SizedBox(height: 16),
          if (location == 'fridge' && !state.offline)
            TextButton.icon(
              onPressed: () => context.push('/leftovers'),
              icon: const Icon(Icons.takeout_dining_outlined),
              label: Text(context.t('leftovers')),
            ),
          if (state.offline)
            StatusNote(text: context.t('offline_inventory'), warning: true),
          if (items.isEmpty)
            EmptyMessage(
              title: context.t('empty_fridge'),
              body: context.t('empty_fridge_body'),
              action: FilledButton(
                onPressed: state.offline
                    ? null
                    : () => sheet(context, AddFoodSheet(location: location)),
                child: Text(context.t('add_food')),
              ),
            ),
          for (final batch in items) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: FoodMark(food: batch.food),
              title: Text(localized(batch.food.name, context.language)),
              subtitle: Text(
                '${batch.quantity} ${batch.food.unit}\n${expiryLabel(context, batch)}',
                style: TextStyle(
                  color: batch.usable
                      ? null
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => sheet(context, BatchSheet(batch: batch)),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({super.key, this.location = 'fridge'});
  final String location;
  @override
  ConsumerState<AddFoodSheet> createState() => _AddFoodSheetState();
}

class LeftoversSheet extends ConsumerStatefulWidget {
  const LeftoversSheet({super.key});
  @override
  ConsumerState<LeftoversSheet> createState() => _LeftoversSheetState();
}

class _LeftoversSheetState extends ConsumerState<LeftoversSheet> {
  late Future<Json> future = ref.read(apiProvider).request('GET', '/leftovers');
  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusNote(text: context.t('network_error'), warning: true),
              FilledButton(
                onPressed: () => setState(
                  () => future = ref
                      .read(apiProvider)
                      .request('GET', '/leftovers'),
                ),
                child: Text(context.t('retry')),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final items = snapshot.data!['items'] as List;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.t('leftovers'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (items.isEmpty) StatusNote(text: context.t('leftovers_empty')),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                localized(
                  Map<String, dynamic>.from(item['recipe_title'] as Map),
                  context.language,
                ),
              ),
              subtitle: Text(
                '${context.t('portions', {'count': item['servings'] as int})}\n${context.t('prepared_at', {'date': MaterialLocalizations.of(context).formatCompactDate(DateTime.parse(item['prepared_at'] as String).toLocal())})}',
              ),
              isThreeLine: true,
            ),
          if (items.isNotEmpty)
            StatusNote(text: context.t('leftover_date_unknown')),
        ],
      );
    },
  );
}

class _AddFoodSheetState extends ConsumerState<AddFoodSheet> {
  final amount = TextEditingController();
  final mutation = Mutation();
  Food? food;
  DateTime? date;
  String expiryKind = 'best_before', search = '';
  late String location = widget.location;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      children: [
        Text(
          context.t('add_food'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        if (food == null) ...[
          TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: context.t('search_food')),
            onChanged: (s) => setState(() => search = s),
          ),
          for (final option in foods.where(
            (f) => localized(
              f.name,
              context.language,
            ).toLowerCase().contains(search.toLowerCase()),
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FoodMark(food: option),
              title: Text(localized(option.name, context.language)),
              onTap: () => setState(() => food = option),
            ),
        ] else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FoodMark(food: food!),
            title: Text(localized(food!.name, context.language)),
            trailing: TextButton(
              onPressed: () => setState(() => food = null),
              child: Text(context.t('change')),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.t('quantity'),
              suffixText: food!.unit,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: location,
            decoration: InputDecoration(labelText: context.t('storage')),
            items: ['fridge', 'freezer', 'pantry']
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(context.t(s))),
                )
                .toList(),
            onChanged: (v) => setState(() => location = v!),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('package_date')),
            subtitle: Text(
              date == null
                  ? context.t('optional')
                  : MaterialLocalizations.of(context).formatCompactDate(date!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final chosen = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (chosen != null && mounted) setState(() => date = chosen);
            },
          ),
          if (date != null) ...[
            DropdownButtonFormField<String>(
              initialValue: expiryKind,
              decoration: InputDecoration(labelText: context.t('date_type')),
              items: ['use_by', 'best_before', 'estimated']
                  .map(
                    (k) => DropdownMenuItem(
                      value: k,
                      child: Text(context.t('${k}_label')),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => expiryKind = v!),
            ),
            TextButton(
              onPressed: () => setState(() => date = null),
              child: Text(context.t('remove_date')),
            ),
          ],
          const SizedBox(height: 24),
          AsyncAction(
            label: context.t('add_to_fridge'),
            action: () async {
              final body = <String, dynamic>{
                'food_id': food!.id,
                'quantity': amount.text.trim().replaceAll(',', '.'),
                'location': location,
                'expiry_kind': date == null ? 'unknown' : expiryKind,
                if (date != null)
                  'expiry_date': date!.toIso8601String().substring(0, 10),
              };
              await mutation.send(
                ref.read(apiProvider),
                'POST',
                '/inventory',
                body,
              );
              await ref.read(appProvider.notifier).refresh();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

class BatchSheet extends ConsumerStatefulWidget {
  const BatchSheet({super.key, required this.batch});
  final Batch batch;
  @override
  ConsumerState<BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends ConsumerState<BatchSheet> {
  final mutation = Mutation();
  late final amount = TextEditingController(text: widget.batch.quantity);
  late String location = widget.batch.location;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> apply(String action) async {
    final body = <String, dynamic>{
      'action': action,
      'expected_version': widget.batch.version,
      if (['consumed', 'discarded', 'corrected'].contains(action))
        'quantity': amount.text.trim().replaceAll(',', '.'),
      if (action == 'moved') 'location': location,
    };
    await mutation.send(
      ref.read(apiProvider),
      'PATCH',
      '/inventory/${widget.batch.id}',
      body,
    );
    await ref.read(appProvider.notifier).refresh();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch, offline = ref.watch(appProvider).offline;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      children: [
        Text(
          localized(batch.food.name, context.language),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: expiryLabel(context, batch), warning: !batch.usable),
        if (!batch.usable)
          StatusNote(text: context.t('use_by_passed'), warning: true),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.t('quantity'),
            suffixText: batch.food.unit,
          ),
        ),
        const SizedBox(height: 24),
        AsyncAction(
          label: context.t('mark_consumed'),
          enabled: !offline && batch.usable,
          action: () => apply('consumed'),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(context.t('manage_food')),
          children: [
            AsyncAction(
              label: context.t('correct_quantity'),
              secondary: true,
              enabled: !offline,
              action: () => apply('corrected'),
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: context.t('opened_today'),
              secondary: true,
              enabled: !offline,
              action: () => apply('opened'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: location,
              items: ['fridge', 'freezer', 'pantry']
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s, child: Text(context.t(s))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => location = v!),
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: context.t('move_food'),
              secondary: true,
              enabled: !offline,
              action: () => apply('moved'),
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: context.t('discard_food'),
              secondary: true,
              enabled: !offline,
              action: () => apply('discarded'),
            ),
          ],
        ),
        StatusNote(text: context.t('manual_source')),
      ],
    );
  }
}
