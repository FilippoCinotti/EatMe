import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'batch_details.dart';
import 'expiry.dart';
import 'inventory_grid.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../../design_system/theme.dart';
import '../onboarding/first_access_tour.dart';

class FridgePage extends ConsumerStatefulWidget {
  const FridgePage({super.key});
  @override
  ConsumerState<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends ConsumerState<FridgePage> {
  String location = 'all', search = '', sort = 'expiry', expiryFilter = 'all';
  final selectedBatchIds = <String>{};
  final collapsedCategories = <String>{};
  final expandedCategories = <String>{};
  final bulkMutation = Mutation();
  bool selecting = false, saving = false;

  void toggleSelection(String id) => setState(() {
    if (!selecting) selecting = true;
    if (!selectedBatchIds.add(id)) selectedBatchIds.remove(id);
  });

  void stopSelection() => setState(() {
    selecting = false;
    selectedBatchIds.clear();
  });

  Future<bool> confirmAction(String title, String message) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(title),
          ),
        ],
      ),
    );
    return answer == true;
  }

  Future<void> runBulk(String action, {String? destination}) async {
    if (saving || selectedBatchIds.isEmpty || ref.read(appProvider).offline) {
      return;
    }
    final batches = ref.read(appProvider).inventory
        .where((batch) => selectedBatchIds.contains(batch.id))
        .toList();
    if (batches.isEmpty || batches.length != selectedBatchIds.length) {
      if (mounted) stopSelection();
      return;
    }
    if (action == 'consumed' && batches.any((b) => !b.usable)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('batch_not_usable'))),
      );
      return;
    }
    if (action == 'delete' || action == 'consumed') {
      final label = context.t(
        action == 'delete'
            ? 'inventory_remove_selected'
            : 'inventory_bulk_consume',
      );
      final message = context.t(
        action == 'delete'
            ? 'inventory_remove_confirmation'
            : 'inventory_bulk_consume_confirmation',
        {'count': batches.length},
      );
      if (!await confirmAction(label, message) || !mounted) return;
    }
    setState(() => saving = true);
    try {
      await bulkMutation.send(
        ref.read(apiProvider),
        'POST',
        action == 'delete'
            ? '/inventory/bulk-remove'
            : '/inventory/bulk-action',
        {
          if (action != 'delete') 'action': action,
          'location': ?destination,
          'items': [
            for (final batch in batches)
              {'id': batch.id, 'expected_version': batch.version},
          ],
        },
      );
      await ref.read(appProvider.notifier).refresh();
      if (!mounted) return;
      stopSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('inventory_bulk_success'))),
      );
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
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> bulkMove() async {
    if (selectedBatchIds.isEmpty || saving) return;
    final destination = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (menu) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in ['fridge', 'freezer', 'pantry'])
              ListTile(
                key: ValueKey('inventory-bulk-move-$value'),
                leading: Icon(
                  value == 'fridge'
                      ? Icons.kitchen_outlined
                      : value == 'freezer'
                      ? Icons.ac_unit
                      : Icons.inventory_2_outlined,
                ),
                title: Text(context.t(value)),
                onTap: () => Navigator.pop(menu, value),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (destination != null && mounted) {
      await runBulk('moved', destination: destination);
    }
  }

  void openFilters() {
    sheet(
      context,
      ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            context.t('sort'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          for (final value in ['expiry', 'name', 'name_desc', 'recent'])
            ListTile(
              key: ValueKey('inventory-sort-$value'),
              title: Text(context.t('inventory_sort_$value')),
              trailing: sort == value ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => sort = value);
                Navigator.pop(context);
              },
            ),
          const Divider(),
          ListTile(
            key: const ValueKey('inventory-select-from-filter'),
            leading: const Icon(Icons.checklist_rounded),
            title: Text(context.t('inventory_select')),
            onTap: () {
              Navigator.pop(context);
              setState(() => selecting = true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RecipeEditorial(builder: _build);

  Widget _build(BuildContext context) {
    final state = ref.watch(appProvider);
    final source = state.inventory
        .where((batch) => location == 'all' || batch.location == location)
        .where((batch) => inventorySearchMatches(batch, search, context))
        .toList();
    final dueSoon = source
        .where((batch) =>
            batchExpiryStatus(batch) == BatchExpiryStatus.soon && batch.usable)
        .length;
    final expired = source
        .where((batch) =>
            batchExpiryStatus(batch) == BatchExpiryStatus.expired ||
            !batch.usable)
        .length;
    final visible = source.where((batch) {
      final status = batchExpiryStatus(batch);
      if (expiryFilter == 'expired') {
        return status == BatchExpiryStatus.expired || !batch.usable;
      }
      if (expiryFilter == 'soon') {
        return status == BatchExpiryStatus.soon && batch.usable;
      }
      return true;
    }).toList();
    final groups = groupInventory(visible, sort, context.language);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final available = width - 40;
                final columns = inventoryColumns(available, scale);
                return RefreshIndicator(
                  onRefresh: () => ref.read(appProvider.notifier).refresh(),
                  child: CustomScrollView(
                    key: const ValueKey('fridge-inventory-scroll'),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              KeyedSubtree(
                                key: FirstAccessTourTargets.fridgeHeader,
                                child: Row(
                                  children: [
                                    const EatMeBrandMark(size: 24),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'EatMe+',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontFamily: 'EatMeDisplay',
                                        ),
                                      ),
                                    ),
                                    RoundAction(
                                      icon: EatMeGlyph.plus,
                                      label: context.t('add_food'),
                                      primary: true,
                                      onPressed: state.offline
                                          ? null
                                          : () => showAddFoodMethods(
                                              context,
                                              location: location,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                context.t('inventory_title'),
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              Text(
                                context.t('inventory_subtitle', {
                                  'count': source.length,
                                  'soon': dueSoon,
                                }),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              KeyedSubtree(
                                key: FirstAccessTourTargets.fridgeSearch,
                                child: SearchPill(
                                  hint: context.t('inventory_search_hint'),
                                  onChanged: (value) => setState(() => search = value),
                                  onFilter: openFilters,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final value in ['all', 'fridge', 'freezer', 'pantry'])
                                      Padding(
                                        padding: const EdgeInsetsDirectional.only(end: 7),
                                        child: ChoiceChip(
                                          showCheckmark: false,
                                          label: Text(context.t(
                                            value == 'all' ? 'food_group_all' : value,
                                          )),
                                          selected: location == value,
                                          onSelected: (_) => setState(() => location = value),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (state.offline) ...[
                                const SizedBox(height: 8),
                                StatusNote(text: context.t('offline_inventory'), warning: true),
                              ],
                              const SizedBox(height: 14),
                              KeyedSubtree(
                                key: FirstAccessTourTargets.fridgeFilters,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _InventoryStatusTile(
                                        label: context.t('expiry_soon_short'),
                                        count: dueSoon,
                                        icon: Icons.watch_later_outlined,
                                        selected: expiryFilter == 'soon',
                                        warning: false,
                                        onTap: () => setState(() {
                                          expiryFilter = expiryFilter == 'soon'
                                              ? 'all'
                                              : 'soon';
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _InventoryStatusTile(
                                        label: context.t('expiry_expired'),
                                        count: expired,
                                        icon: Icons.warning_amber_outlined,
                                        selected: expiryFilter == 'expired',
                                        warning: true,
                                        onTap: () => setState(() {
                                          expiryFilter = expiryFilter == 'expired'
                                              ? 'all'
                                              : 'expired';
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (visible.isNotEmpty || selecting)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    key: const ValueKey('inventory-select-mode'),
                                    onPressed: state.offline || saving
                                        ? null
                                        : selecting
                                        ? stopSelection
                                        : () => setState(() => selecting = true),
                                    icon: Icon(selecting
                                        ? Icons.close
                                        : Icons.checklist_rounded),
                                    label: Text(context.t(selecting
                                        ? 'inventory_cancel_selection'
                                        : 'inventory_select')),
                                  ),
                                ),
                              if (selecting)
                                _selectionToolbar(context, visible, state.offline),
                            ],
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: EmptyMessage(
                              title: context.t(source.isEmpty
                                  ? 'empty_fridge'
                                  : 'expiry_no_matches'),
                              body: context.t('empty_fridge_body'),
                              action: FilledButton(
                                onPressed: state.offline
                                    ? null
                                    : () => showAddFoodMethods(context, location: location),
                                child: Text(context.t('add_food')),
                              ),
                            ),
                          ),
                        ),
                      for (final group in groups) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                            child: _InventoryCategoryHeading(
                              id: group.id,
                              count: group.items.length,
                              collapsed: collapsedCategories.contains(group.id),
                              onTap: () => setState(() {
                                if (!collapsedCategories.add(group.id)) {
                                  collapsedCategories.remove(group.id);
                                }
                              }),
                            ),
                          ),
                        ),
                        if (!collapsedCategories.contains(group.id)) ...[
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final batch = group.items[index];
                                  return InventoryPhotoCard(
                                    key: ValueKey('inventory-batch-${batch.id}'),
                                    batch: batch,
                                    showLocation: location == 'all',
                                    selecting: selecting,
                                    selected: selectedBatchIds.contains(batch.id),
                                    onTap: () {
                                      if (selecting) {
                                        toggleSelection(batch.id);
                                      } else {
                                        sheet(context, BatchSheet(batch: batch));
                                      }
                                    },
                                    onLongPress: () {
                                      if (!state.offline && !saving) {
                                        toggleSelection(batch.id);
                                      }
                                    },
                                  );
                                },
                                childCount: expandedCategories.contains(group.id)
                                    ? group.items.length
                                    : (group.items.length < 4 ? group.items.length : 4),
                                addAutomaticKeepAlives: false,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: inventoryCardHeight(scale),
                              ),
                            ),
                          ),
                          if (group.items.length > 4)
                            SliverToBoxAdapter(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                                  child: TextButton.icon(
                                    key: ValueKey('inventory-expand-${group.id}'),
                                    onPressed: () => setState(() {
                                      if (!expandedCategories.add(group.id)) {
                                        expandedCategories.remove(group.id);
                                      }
                                    }),
                                    icon: Icon(expandedCategories.contains(group.id)
                                        ? Icons.expand_less
                                        : Icons.expand_more),
                                    label: Text(expandedCategories.contains(group.id)
                                        ? context.t('inventory_show_less')
                                        : context.t('inventory_show_more', {
                                            'count': group.items.length - 4,
                                          })),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 126),
                          child: KeyedSubtree(
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
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectionToolbar(
    BuildContext context,
    List<Batch> visible,
    bool offline,
  ) {
    final enabled = !offline && !saving && selectedBatchIds.isNotEmpty;
    final visibleIds = visible.map((batch) => batch.id).toSet();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(context.t('inventory_selected_count', {
            'count': selectedBatchIds.length,
          })),
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('inventory-select-all'),
            onPressed: offline || saving || visible.isEmpty
                ? null
                : () => setState(() {
                    if (selectedBatchIds.containsAll(visibleIds)) {
                      selectedBatchIds.removeAll(visibleIds);
                    } else {
                      selectedBatchIds.addAll(visibleIds);
                    }
                  }),
            child: Text(context.t('inventory_select_all')),
          ),
          OutlinedButton.icon(
            key: const ValueKey('inventory-bulk-move'),
            onPressed: enabled ? bulkMove : null,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(context.t('move_food')),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const ValueKey('inventory-bulk-consume'),
            onPressed: enabled ? () => runBulk('consumed') : null,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(context.t('inventory_bulk_consume')),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey('inventory-bulk-remove'),
            onPressed: enabled ? () => runBulk('delete') : null,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.t('inventory_remove_selected')),
          ),
        ],
      ),
    );
  }
}

class _InventoryStatusTile extends StatelessWidget {
  const _InventoryStatusTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.warning,
    required this.onTap,
  });
  final String label;
  final int count;
  final IconData icon;
  final bool selected, warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = warning ? scheme.error : scheme.primary;
    return Material(
      color: selected
          ? (warning ? scheme.errorContainer : scheme.primaryContainer)
          : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: tint, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                    Text('$count',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: tint,
                        )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryCategoryHeading extends StatelessWidget {
  const _InventoryCategoryHeading({
    required this.id,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });
  final String id;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('inventory-category-$id'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(inventoryCategoryIcon(id), size: 21, color: scheme.primary),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                inventoryCategoryTitle(context, id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text('$count', style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: collapsed ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
            ),
          ],
        ),
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
                value: batch.expiryDate == null
                    ? context.t('date_unknown')
                    : MaterialLocalizations.of(
                        context,
                      ).formatCompactDate(batch.expiryDate!),
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
          height: 52,
          child: FilledButton(
            key: const ValueKey('batch-consume'),
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.paleGreen,
              foregroundColor: Tokens.graphite,
            ),
            onPressed: enabled && batch.usable
                ? () => run(() => apply('consumed'))
                : null,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Tokens.graphite,
                    ),
                  )
                : Text(context.t('mark_consumed')),
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
