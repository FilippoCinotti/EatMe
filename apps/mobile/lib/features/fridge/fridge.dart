import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'batch_details.dart';
import 'expiry.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../onboarding/first_access_tour.dart';
import '../organize/shared.dart';

class FridgePage extends ConsumerStatefulWidget {
  const FridgePage({super.key});
  @override
  ConsumerState<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends ConsumerState<FridgePage> {
  String location = 'all', search = '', sort = 'expiry', expiryFilter = 'all';
  final selectedBatchIds = <String>{};
  final bulkRemove = Mutation();
  bool selecting = false, removing = false;

  Future<void> removeSelected() async {
    if (removing || selectedBatchIds.isEmpty) return;
    final state = ref.read(appProvider);
    if (state.offline) return;
    final batches = state.inventory
        .where((batch) => selectedBatchIds.contains(batch.id))
        .toList();
    if (batches.isEmpty || batches.length != selectedBatchIds.length) {
      setState(() => selectedBatchIds.clear());
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('inventory_remove_selected')),
        content: Text(context.t('inventory_remove_confirmation', {
          'count': batches.length,
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('inventory_remove_selected')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || ref.read(appProvider).offline) {
      return;
    }
    setState(() => removing = true);
    try {
      await bulkRemove.send(
        ref.read(apiProvider),
        'POST',
        '/inventory/bulk-remove',
        {
          'items': [
            for (final batch in batches)
              {'id': batch.id, 'expected_version': batch.version},
          ],
        },
      );
      await ref.read(appProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        selectedBatchIds.clear();
        selecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('inventory_removed_count', {
            'count': batches.length,
          })),
        ),
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(error.code))),
      );
    } finally {
      if (mounted) setState(() => removing = false);
    }
  }

  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Widget _build(BuildContext context) {
    final state = ref.watch(appProvider);
    final items = state.inventory
        .where(
          (b) =>
              (location == 'all' || b.location == location) &&
              localized(
                b.food.name,
                context.language,
              ).toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    items.sort(
      (a, b) => sort == 'name'
          ? localized(
              a.food.name,
              context.language,
            ).compareTo(localized(b.food.name, context.language))
          : (a.expiryDate ?? DateTime(9999)).compareTo(
              b.expiryDate ?? DateTime(9999),
            ),
    );
    bool isExpired(Batch batch) =>
        !batch.usable ||
        (batch.expiryKind == 'use_by' && (expiryDays(batch) ?? 0) < 0);
    final expired = items.where(isExpired).length;
    final dueSoon = items.where((b) {
      final days = expiryDays(b);
      return days != null && days >= 0 && days <= 3;
    }).length;
    final visible = items.where((b) {
      final days = expiryDays(b);
      return expiryFilter == 'all' ||
          (expiryFilter == 'expired' && isExpired(b)) ||
          (expiryFilter == 'soon' && days != null && days >= 0 && days <= 3);
    }).toList();
    return Scaffold(
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          KeyedSubtree(
            key: FirstAccessTourTargets.fridgeHeader,
            child: EditorialHeader(
              eyebrow: context.t('fridge_eyebrow'),
              title: context.t('fridge_editorial'),
              subtitle: context.t('fridge_support'),
              actions: [
                RoundAction(
                  icon: EatMeGlyph.plus,
                  label: context.t('add_food'),
                  primary: true,
                  onPressed: state.offline
                      ? null
                      : () => showAddFoodMethods(context, location: location),
                ),
              ],
            ),
          ),
          KeyedSubtree(
            key: FirstAccessTourTargets.fridgeSearch,
            child: SearchPill(
              hint: context.t('inventory_search_hint'),
              onChanged: (s) => setState(() => search = s),
              onFilter: () => sheet(
                context,
                ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  children: [
                    Text(
                      context.t('sort'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final value in ['expiry', 'name'])
                      SettingRow(
                        title: context.t('sort_$value'),
                        icon: value == 'expiry'
                            ? EatMeGlyph.clockAlert
                            : EatMeGlyph.listFilter,
                        trailing: sort == value
                            ? EatMeIcon(
                                EatMeGlyph.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() => sort = value);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in ['all', 'fridge', 'freezer', 'pantry'])
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                    context.t(value == 'all' ? 'food_group_all' : value),
                  ),
                  selected: location == value,
                  onSelected: (_) => setState(() => location = value),
                ),
            ],
          ),
          if (state.offline)
            StatusNote(text: context.t('offline_inventory'), warning: true),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: FirstAccessTourTargets.fridgeFilters,
            child: RecipeActionRow(
              primary: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: expiryFilter == 'soon'
                      ? BorderSide(color: Theme.of(context).colorScheme.primary)
                      : BorderSide.none,
                ),
                onPressed: () => setState(
                  () => expiryFilter = expiryFilter == 'soon' ? 'all' : 'soon',
                ),
                icon: const EatMeIcon(EatMeGlyph.clockAlert),
                label: Text('${context.t('expiry_soon_short')} · $dueSoon'),
              ),
              secondary: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: expiryFilter == 'expired'
                      ? BorderSide(color: Theme.of(context).colorScheme.primary)
                      : BorderSide.none,
                ),
                onPressed: () => setState(
                  () => expiryFilter = expiryFilter == 'expired'
                      ? 'all'
                      : 'expired',
                ),
                icon: const EatMeIcon(EatMeGlyph.triangleAlert),
                label: Text('${context.t('expiry_expired')} · $expired'),
              ),
            ),
          ),
          SectionHeading(
            title: context.t(
              expiryFilter == 'expired'
                  ? 'expiry_expired'
                  : expiryFilter == 'soon'
                  ? 'expiry_soon_short'
                  : 'all_foods',
            ),
            actionLabel: context.t('sort_$sort'),
            onAction: () =>
                setState(() => sort = sort == 'expiry' ? 'name' : 'expiry'),
          ),
          if (visible.isNotEmpty || selecting)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  key: const ValueKey('inventory-select-mode'),
                  onPressed: removing || state.offline
                      ? null
                      : () => setState(() {
                          selecting = !selecting;
                          selectedBatchIds.clear();
                        }),
                  icon: Icon(selecting ? Icons.close : Icons.checklist_rounded),
                  label: Text(
                    context.t(
                      selecting ? 'inventory_cancel_selection' : 'inventory_select',
                    ),
                  ),
                ),
                if (selecting) ...[
                  TextButton(
                    key: const ValueKey('inventory-select-all'),
                    onPressed: removing || state.offline || visible.isEmpty
                        ? null
                        : () => setState(() {
                            final visibleIds = visible.map((b) => b.id).toSet();
                            if (selectedBatchIds.containsAll(visibleIds)) {
                              selectedBatchIds.removeAll(visibleIds);
                            } else {
                              selectedBatchIds.addAll(visibleIds);
                            }
                          }),
                    child: Text(context.t('inventory_select_all')),
                  ),
                  Text(context.t('inventory_selected_count', {
                    'count': selectedBatchIds.length,
                  })),
                  FilledButton.icon(
                    key: const ValueKey('inventory-bulk-remove'),
                    onPressed:
                        selectedBatchIds.isEmpty || state.offline || removing
                        ? null
                        : removeSelected,
                    icon: removing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(context.t('inventory_remove_selected')),
                  ),
                ],
              ],
            ),
          if (visible.isEmpty)
            EmptyMessage(
              title: context.t(
                items.isEmpty ? 'empty_fridge' : 'expiry_no_matches',
              ),
              body: context.t('empty_fridge_body'),
              action: FilledButton(
                onPressed: state.offline
                    ? null
                    : () => showAddFoodMethods(context, location: location),
                child: Text(context.t('add_food')),
              ),
            ),
          for (final batch in visible)
            CompactBatchRow(
              key: ValueKey('inventory-batch-${batch.id}'),
              batch: batch,
              onTap: () => sheet(context, BatchSheet(batch: batch)),
              selecting: selecting,
              selected: selectedBatchIds.contains(batch.id),
              onSelected: selecting && !removing && !state.offline
                  ? (value) => setState(() {
                      if (value) {
                        selectedBatchIds.add(batch.id);
                      } else {
                        selectedBatchIds.remove(batch.id);
                      }
                    })
                  : null,
            ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: FirstAccessTourTargets.fridgeTools,
            child: SettingsGroup(
              children: [
                SettingRow(
                  title: context.t('expiry_view'),
                  icon: EatMeGlyph.clockAlert,
                  onTap: () => context.push('/expiry'),
                ),
                if (['all', 'fridge'].contains(location) && !state.offline)
                  SettingRow(
                    title: context.t('leftovers'),
                    icon: EatMeGlyph.packageOpen,
                    onTap: () => context.push('/leftovers'),
                  ),
                SettingRow(
                  title: context.t('scan_and_import'),
                  icon: EatMeGlyph.scanLine,
                  onTap: () => context.push('/scanning'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({super.key, this.location = 'fridge', this.initialFood});
  final Food? initialFood;
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
  late Food? food = widget.initialFood;
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
          Text(
            context.t('storage'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          EatMeTabStrip(
            values: [
              for (final value in ['fridge', 'freezer', 'pantry'])
                (value, context.t(value)),
            ],
            selected: location,
            onSelected: (value) => setState(() => location = value),
          ),
          const SizedBox(height: 16),
          SettingRow(
            icon: EatMeGlyph.calendar,
            title: context.t('package_date'),
            subtitle: date == null
                ? context.t('optional')
                : MaterialLocalizations.of(context).formatCompactDate(date!),
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
          if (date == null &&
              food!.estimatedExpiry(location, DateTime.now()) != null)
            StatusNote(
              key: const ValueKey('estimated-expiry-hint'),
              text: context.t('estimated_expiry_hint', {
                'date': MaterialLocalizations.of(context).formatCompactDate(
                  food!.estimatedExpiry(location, DateTime.now())!,
                ),
              }),
            ),
          if (date != null) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
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
                // Without a package date the API estimates one from typical
                // shelf life; it is stored as an estimate, never a safety date.
                if (date == null) 'estimate_expiry': true,
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
  final removal = Mutation();
  bool busy = false;

  /// A failed write leaves the sheet, cached state and selected location
  /// unchanged. Server-side expected_version checks prevent stale updates.
  Future<void> run(Future<void> Function() operation) async {
    if (busy || ref.read(appProvider).offline) return;
    setState(() => busy = true);
    try {
      await operation();
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t(error.code))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('unknown_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> apply(String action, {String? destination}) async {
    final batch = widget.batch;
    await mutation.send(
      ref.read(apiProvider),
      'PATCH',
      '/inventory/${batch.id}',
      {
        'action': action,
        'expected_version': batch.version,
        if (action == 'consumed' || action == 'discarded')
          'quantity': batch.quantity,
        if (action == 'moved') 'location': destination,
      },
    );
    await ref.read(appProvider.notifier).refresh();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> move() async {
    if (busy || ref.read(appProvider).offline) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (menu) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in [
                ('fridge', Icons.kitchen_outlined),
                ('freezer', Icons.ac_unit),
                ('pantry', Icons.inventory_2_outlined),
              ])
                ListTile(
                  key: ValueKey('batch-move-${option.$1}'),
                  leading: Icon(option.$2),
                  title: Text(context.t(option.$1)),
                  selected: widget.batch.location == option.$1,
                  trailing: widget.batch.location == option.$1
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(menu, option.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted ||
        selected == null ||
        selected == widget.batch.location) {
      return;
    }
    await run(() => apply('moved', destination: selected));
  }

  Future<bool> confirm(String message, String action) async {
    final response = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-batch-delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return response == true;
  }

  Future<void> deleteBatch() async {
    if (!await confirm(
      context.t('inventory_delete_confirm'),
      context.t('inventory_delete_item'),
    )) {
      return;
    }
    if (!mounted) return;
    await run(() async {
      await removal.send(
        ref.read(apiProvider),
        'POST',
        '/inventory/bulk-remove',
        {
          'items': [
            {
              'id': widget.batch.id,
              'expected_version': widget.batch.version,
            },
          ],
        },
      );
      await ref.read(appProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> more() async {
    if (busy || ref.read(appProvider).offline) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (menu) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('batch-mark-opened'),
                leading: const Icon(Icons.lock_open_outlined),
                title: Text(context.t('opened_today')),
                onTap: () => Navigator.pop(menu, 'opened'),
              ),
              ListTile(
                key: const ValueKey('batch-discard'),
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(context.t('discard_food')),
                onTap: () => Navigator.pop(menu, 'discarded'),
              ),
              ListTile(
                key: const ValueKey('batch-delete'),
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.t('inventory_delete_item'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(menu, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'opened') {
      await run(() => apply('opened'));
    } else if (choice == 'discarded') {
      final approved = await confirm(
        context.t('inventory_discard_confirm'),
        context.t('discard_food'),
      );
      if (mounted && approved) await run(() => apply('discarded'));
    } else if (choice == 'delete') {
      await deleteBatch();
    }
  }

  Future<void> edit() async {
    if (busy || ref.read(appProvider).offline) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BatchDetailsPage(batch: widget.batch),
      ),
    );
    // The editor refreshes the inventory before returning a success marker.
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final scheme = Theme.of(context).colorScheme;
    final expiry = batchExpiryStatus(batch);
    final offline = ref.watch(appProvider).offline;
    final enabled = !busy && !offline;
    final statusColor = expiry == BatchExpiryStatus.expired || !batch.usable
        ? scheme.errorContainer
        : expiry == BatchExpiryStatus.soon
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final statusText = expiry == BatchExpiryStatus.expired || !batch.usable
        ? scheme.onErrorContainer
        : expiry == BatchExpiryStatus.soon
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;
    return RepaintBoundary(
      key: const ValueKey('batch-detail-capture'),
      child: ListView(
      key: const ValueKey('batch-detail-sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FoodImage(
              id: batch.food.id,
              photoId: batch.food.photoId,
              imageUrl: batch.food.imageUrl,
              width: 104,
              height: 104,
              radius: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localized(batch.food.name, context.language),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${batch.quantity} ${batch.food.unit} · ${context.t(batch.location)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          relativeExpiryLabel(context, batch),
                          key: const ValueKey('batch-expiry-badge'),
                          softWrap: true,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BatchInfo(
                icon: Icons.event_outlined,
                title: batch.expiryKind == 'estimated'
                    ? context.t('estimated_label')
                    : context.t('expiry_date'),
                value: expiryLabel(context, batch),
              ),
            ),
            Container(width: 1, height: 44, color: scheme.outlineVariant),
            const SizedBox(width: 12),
            Expanded(
              child: _BatchInfo(
                icon: Icons.scale_outlined,
                title: context.t('quantity'),
                value: '${batch.quantity} ${batch.food.unit}',
              ),
            ),
          ],
        ),
        if (batch.recalls.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BatchNoticeCard(text: context.t('recalled_batch'), warning: true),
          for (final recall in batch.recalls)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(recall['url'] as String),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(context.t('read_source')),
            ),
        ] else if (!batch.usable) ...[
          const SizedBox(height: 10),
          _BatchNoticeCard(text: context.t('use_by_passed'), warning: true),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: AsyncAction(
            label: context.t('mark_consumed'),
            enabled: enabled && batch.usable,
            action: () => run(() => apply('consumed')),
          ),
        ),
        const SizedBox(height: 20),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 10),
        Text(
          context.t('manage_food'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _BatchAction(
                label: context.t('inventory_edit'),
                icon: Icons.edit_outlined,
                enabled: enabled,
                onPressed: edit,
              ),
            ),
            Expanded(
              child: _BatchAction(
                label: context.t('move_food'),
                icon: Icons.swap_horiz_rounded,
                enabled: enabled,
                onPressed: move,
              ),
            ),
            Expanded(
              child: _BatchAction(
                label: context.t('inventory_more'),
                icon: Icons.more_horiz,
                enabled: enabled,
                onPressed: more,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 17,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.t('manual_source'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

class _BatchInfo extends StatelessWidget {
  const _BatchInfo({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BatchAction extends StatelessWidget {
  const _BatchAction({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: ValueKey('batch-action-$label'),
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          softWrap: true,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _BatchNoticeCard extends StatelessWidget {
  const _BatchNoticeCard({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: warning ? scheme.errorContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 18,
            color: warning ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: warning
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
