import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization.dart';
import '../../core/reminders.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});
  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesState();
}

class _PreferencesState extends ResourceState<PreferencesPage> {
  @override
  String get path => '/preferences';
  Future<void> update(String name, dynamic value) async {
    if (data == null) return;
    await guard(() async {
      await command({
        'expected_version': data!['version'],
        'data': {
          ...Map<String, dynamic>.from(data!['data'] as Map),
          name: value,
        },
      });
      await ref.read(appProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = data?['data'] as Map? ?? {};
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('preferences'))),
      body: content([
        SettingsGroup(
          title: context.t('appearance'),
          children: [
            DropdownButtonFormField<ThemeMode>(
              initialValue: ref.watch(appProvider).theme,
              decoration: InputDecoration(labelText: context.t('appearance')),
              items: ThemeMode.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(context.t(t.name)),
                    ),
                  )
                  .toList(),
              onChanged: (t) => ref.read(appProvider.notifier).setTheme(t!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: context.language,
              decoration: InputDecoration(labelText: context.t('language')),
              items: ['it', 'en']
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(context.t('language_$l')),
                    ),
                  )
                  .toList(),
              onChanged: (l) => ref.read(appProvider.notifier).setLocale(l!),
            ),
          ],
        ),
        Text(
          context.t('make_it_yours'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SettingsGroup(
          children: [
            DropdownButtonFormField<String>(
              initialValue: prefs['budget'] as String? ?? 'any',
              decoration: InputDecoration(
                labelText: context.t('budget_preference'),
              ),
              items: ['any', 'medium', 'low']
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(context.t('budget_$v')),
                    ),
                  )
                  .toList(),
              onChanged: (v) => update('budget', v),
            ),
            StatusNote(text: context.t('budget_notice')),
            for (final name in [
              'learning',
              'analytics',
              'ai_consent',
              'seasonal',
            ])
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: prefs[name] == true,
                title: Text(context.t('pref_$name')),
                subtitle: Text(context.t('pref_${name}_body')),
                onChanged: data == null ? null : (v) => update(name, v),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          children: [
            DropdownButtonFormField<String>(
              initialValue: prefs['skill'] as String? ?? 'beginner',
              decoration: InputDecoration(
                labelText: context.t('cooking_skill'),
              ),
              items: [
                for (final level in ['beginner', 'confident', 'advanced'])
                  DropdownMenuItem(value: level, child: Text(context.t(level))),
              ],
              onChanged: (v) => update('skill', v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: prefs['max_minutes'] as int? ?? 30,
              decoration: InputDecoration(labelText: context.t('cooking_time')),
              items: [
                for (final time in [10, 15, 20, 30, 45, 60, 120])
                  DropdownMenuItem(value: time, child: Text('$time min')),
              ],
              onChanged: (v) => update('max_minutes', v),
            ),
            const SizedBox(height: 24),
            AsyncAction(
              label: context.t('preferred_cuisines'),
              secondary: true,
              action: () async {
                final value = await askText(
                  context,
                  context.t('comma_separated'),
                  initial: (prefs['cuisines'] as List? ?? []).join(', '),
                );
                if (value != null) {
                  await update(
                    'cuisines',
                    value
                        .split(',')
                        .map((v) => v.trim())
                        .where((v) => v.isNotEmpty)
                        .toList(),
                  );
                }
              },
            ),
          ],
        ),
      ]),
    );
  }
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsState();
}

class _NotificationsState extends ResourceState<NotificationsPage> {
  @override
  String get path => '/notifications';
  Future<void> update(Json changes) async {
    if (data == null) return;
    await guard(() async {
      if (changes['enabled'] == true) await Reminders.requestPermission();
      await command({
        'action': 'preferences',
        'expected_version': data!['version'],
        'preferences': {
          ...Map<String, dynamic>.from(data!['preferences'] as Map),
          ...changes,
        },
      });
      final app = ref.read(appProvider);
      final plans = await ref.read(apiProvider).request('GET', '/plans');
      await Reminders.schedule(
        Map<String, dynamic>.from(data!['preferences'] as Map),
        app.inventory,
        records(plans['items']),
        app.profile['settings']['timezone'] as String,
        app.locale?.languageCode ?? 'en',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = data?['preferences'] as Map? ?? {};
    final categories = List<String>.from(prefs['categories'] as List? ?? []);
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('notifications'))),
      body: content([
        SettingsGroup(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs['enabled'] == true,
              title: Text(context.t('enable_reminders')),
              onChanged: data == null ? null : (v) => update({'enabled': v}),
            ),
            StatusNote(text: context.t('notification_privacy')),
            for (final category in [
              'expiry',
              'plans',
              'shopping',
              'household',
              'recalls',
            ])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('notify_$category')),
                value: categories.contains(category),
                onChanged: (v) async {
                  if (v == true) {
                    categories.add(category);
                  } else {
                    categories.remove(category);
                  }
                  await update({'categories': categories});
                },
              ),
            for (final setting in ['quiet_start', 'quiet_end', 'daily_cap'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t(setting)),
                trailing: Text('${prefs[setting] ?? ''}'),
                onTap: () async {
                  final value = await askText(
                    context,
                    context.t(setting),
                    initial: '${prefs[setting]}',
                    numeric: true,
                  );
                  if (value != null) {
                    await update({setting: int.tryParse(value) ?? 0});
                  }
                },
              ),
          ],
        ),

        for (final item in records(data?['items']))
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: Text(context.t('notify_${item['category']}')),
            subtitle: Text('${item['created_at']}'.substring(0, 10)),
            trailing: item['read_at'] == null
                ? const Icon(Icons.circle, size: 8)
                : null,
            onTap: () async {
              await guard(() async {
                await command({'action': 'read', 'id': item['id']});
              });
            },
          ),
      ]),
    );
  }
}

class EvidencePage extends ConsumerStatefulWidget {
  const EvidencePage({super.key});
  @override
  ConsumerState<EvidencePage> createState() => _EvidenceState();
}

class _EvidenceState extends ResourceState<EvidencePage> {
  String query = '';
  @override
  String get path => '/evidence?q=${Uri.encodeQueryComponent(query)}';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('evidence_library'))),
    body: content([
      TextField(
        decoration: InputDecoration(
          labelText: context.t('search_evidence'),
          prefixIcon: const Icon(Icons.search),
        ),
        onSubmitted: (v) {
          query = v;
          load();
        },
      ),
      const SizedBox(height: 20),
      if (records(data?['items']).isEmpty)
        EmptyMessage(
          title: context.t('evidence_unknown'),
          body: context.t('evidence_unknown_body'),
        ),
      for (final item in records(data?['items']))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(item['claim'] as String),
                StatusNote(
                  text:
                      '${item['publisher']} · ${item['published_date']} · ${item['strength']}',
                ),
                Text('${context.t('review_due')}: ${item['review_due']}'),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(item['url'] as String),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(context.t('read_source')),
                ),
              ],
            ),
          ),
        ),
    ]),
  );
}

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});
  @override
  ConsumerState<InsightsPage> createState() => _InsightsState();
}

class _InsightsState extends ResourceState<InsightsPage> {
  String tab = 'overview';
  @override
  String get path => '/insights';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('insights'))),
    body: content([
      Text(
        context.t('small_habits'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 8,
        children: [
          for (final value in ['overview', 'alerts', 'tips'])
            ChoiceChip(
              label: Text(context.t('insights_$value')),
              selected: tab == value,
              onSelected: (_) => setState(() => tab = value),
            ),
        ],
      ),
      if (tab == 'alerts') ...[
        for (final batch
            in ref
                .watch(appProvider)
                .inventory
                .where(
                  (b) =>
                      b.expiryDate != null &&
                      b.expiryDate!.difference(DateTime.now()).inDays <= 3,
                ))
          Card(
            child: ListTile(
              leading: FoodMark(food: batch.food),
              title: Text(localized(batch.food.name, context.language)),
              subtitle: Text(expiryLabel(context, batch)),
              onTap: () => context.push('/expiry'),
            ),
          ),
        TextButton(
          onPressed: () => context.push('/notifications'),
          child: Text(context.t('notifications')),
        ),
      ],
      if (tab == 'tips') ...[
        StatusNote(text: context.t('practical_tips')),
        TextButton(
          onPressed: () => context.push('/planner'),
          child: Text(context.t('meal_planner')),
        ),
        TextButton(
          onPressed: () => context.push('/leftovers'),
          child: Text(context.t('leftovers')),
        ),
        TextButton(
          onPressed: () => context.push('/wellbeing'),
          child: Text(context.t('wellbeing')),
        ),
      ],
      if (tab == 'overview') ...[
        for (final metric in ['cooked_meals', 'different_recipes'])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data?[metric] ?? 0}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Text(context.t(metric)),
                ],
              ),
            ),
          ),
        for (final entry
            in (data?['inventory_event_counts'] as Map? ?? {}).entries)
          ListTile(
            title: Text(context.t('event_${entry.key}')),
            trailing: Text('${entry.value}'),
          ),
        for (final unit in (data?['recorded_quantities'] as Map? ?? {}).entries)
          ListTile(
            title: Text(context.t('recorded_use')),
            subtitle: Text(
              '${unit.value['used']} ${unit.key} · ${context.t('discarded_amount')}: ${unit.value['discarded']} ${unit.key}',
            ),
          ),
        StatusNote(text: context.t('recorded_quantities_notice')),
        StatusNote(text: context.t('insights_method')),
      ],
    ]),
  );
}

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});
  @override
  ConsumerState<SyncPage> createState() => _SyncState();
}

class _SyncState extends ConsumerState<SyncPage> {
  List<Json> pending = [];
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final rows = await ref.read(apiProvider).cache?.pending() ?? [];
    if (mounted && context.mounted) setState(() => pending = rows);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('offline_sync'))),
    body: PageBody(
      children: [
        StatusNote(text: context.t('sync_notice')),
        AsyncAction(
          label: context.t('sync_now'),
          action: () async {
            await ref.read(apiProvider).sync();
            await load();
            await ref.read(appProvider.notifier).refresh();
          },
        ),
        for (final item in pending)
          Card(
            child: ListTile(
              title: Text(context.t('sync_operation')),
              subtitle: Text(context.t(item['status'] as String)),
              trailing: IconButton(
                tooltip: context.t('discard_change'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref
                      .read(apiProvider)
                      .discardPending(item['key'] as String);
                  await load();
                },
              ),
            ),
          ),
        if (pending.isEmpty) StatusNote(text: context.t('all_changes_synced')),
      ],
    ),
  );
}
