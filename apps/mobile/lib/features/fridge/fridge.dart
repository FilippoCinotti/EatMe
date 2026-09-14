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

class FridgePage extends ConsumerStatefulWidget {
  const FridgePage({super.key});
  @override
  ConsumerState<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends ConsumerState<FridgePage> {
  String location = 'all', search = '', sort = 'expiry';
  @override
  Widget build(BuildContext context) {
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
    final today = DateUtils.dateOnly(DateTime.now());
    final dueSoon = items
        .where(
          (batch) =>
              batch.usable &&
              batch.expiryDate != null &&
              batch.expiryDate!.difference(today).inDays >= 0 &&
              batch.expiryDate!.difference(today).inDays <= 3,
        )
        .length;
    final expiring = items
        .where(
          (batch) =>
              batch.usable &&
              batch.expiryDate != null &&
              batch.expiryDate!.difference(today).inDays >= 0 &&
              batch.expiryDate!.difference(today).inDays <= 3,
        )
        .toList();
    return Scaffold(
      body: PageBody(
        onRefresh: () => ref.read(appProvider.notifier).refresh(),
        children: [
          EditorialHeader(
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
          SearchPill(
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
          if (dueSoon > 0) ...[
            SectionHeading(
              title: context.t('use_these_first'),
              actionLabel: context.t('view_all'),
              onAction: () => context.push('/expiry'),
            ),
            HorizontalFoodRail(
              children: [
                for (final batch in expiring)
                  FoodPhotoCard(
                    id: batch.food.id,
                    photoId: batch.food.photoId,
                    title: localized(batch.food.name, context.language),
                    subtitle: '${batch.quantity} ${batch.food.unit}',
                    imageHeight: 125,
                    badge: StatusBadge(
                      label: expiryLabel(context, batch),
                      icon: EatMeGlyph.clock,
                      urgent: batch.expiryDate!.difference(today).inDays == 0,
                      warning: batch.expiryDate!.difference(today).inDays > 0,
                    ),
                    onTap: () => sheet(context, BatchSheet(batch: batch)),
                  ),
              ],
            ),
          ],
          SectionHeading(
            title: context.t('all_foods'),
            actionLabel: context.t('sort_$sort'),
            onAction: () =>
                setState(() => sort = sort == 'expiry' ? 'name' : 'expiry'),
          ),
          if (items.isEmpty)
            EmptyMessage(
              title: context.t('empty_fridge'),
              body: context.t('empty_fridge_body'),
              action: FilledButton(
                onPressed: state.offline
                    ? null
                    : () => showAddFoodMethods(context, location: location),
                child: Text(context.t('add_food')),
              ),
            ),
          AdaptivePhotoGrid(
            children: [
              for (final batch in items)
                FoodPhotoCard(
                  id: batch.food.id,
                  photoId: batch.food.photoId,
                  title: localized(batch.food.name, context.language),
                  subtitle:
                      '${batch.quantity} ${batch.food.unit} · ${context.t(batch.location)}',
                  badge: StatusBadge(
                    label: expiryLabel(context, batch),
                    urgent: !batch.usable,
                    warning:
                        batch.usable &&
                        batch.expiryDate != null &&
                        batch.expiryDate!.difference(today).inDays <= 3,
                    icon: batch.usable
                        ? EatMeGlyph.clock
                        : EatMeGlyph.triangleAlert,
                  ),
                  onTap: () => sheet(context, BatchSheet(batch: batch)),
                  onAction: () => sheet(context, BatchSheet(batch: batch)),
                  actionLabel: context.t('manage_food'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
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
        FoodImage(
          id: batch.food.id,
          photoId: batch.food.photoId,
          height: 200,
          radius: 22,
        ),
        const SizedBox(height: 20),
        Text(
          localized(batch.food.name, context.language),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: expiryLabel(context, batch), warning: !batch.usable),
        if (batch.recalls.isNotEmpty) ...[
          StatusNote(text: context.t('recalled_batch'), warning: true),
          for (final recall in batch.recalls)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(recall['url'] as String),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(context.t('read_source')),
            ),
        ] else if (!batch.usable)
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
              label: context.t('edit_batch_details'),
              secondary: true,
              enabled: !offline,
              action: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BatchDetailsPage(batch: batch),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
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
              isExpanded: true,
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
