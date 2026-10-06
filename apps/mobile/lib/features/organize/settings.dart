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
  double? selectedMinutes;
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
            _ControlLabel(
              label: context.t('appearance'),
              child: EatMeTabStrip(
                values: [
                  for (final theme in ThemeMode.values)
                    (theme.name, context.t(theme.name)),
                ],
                selected: ref.watch(appProvider).theme.name,
                onSelected: (value) => ref
                    .read(appProvider.notifier)
                    .setTheme(ThemeMode.values.byName(value)),
              ),
            ),
            const SizedBox(height: 16),
            _ControlLabel(
              label: context.t('language'),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: context.language == 'zh'
                    ? 'zh-Hans'
                    : context.language,
                items: [
                  for (final language in [
                    'en',
                    'it',
                    'es',
                    'fr',
                    'de',
                    'zh-Hans',
                  ])
                    DropdownMenuItem(
                      value: language,
                      child: Text(context.t('language_$language')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(appProvider.notifier).setLocale(value);
                  }
                },
              ),
            ),
          ],
        ),
        Text(
          context.t('make_it_yours'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          children: [
            _ControlLabel(
              label: context.t('budget_preference'),
              child: EatMeTabStrip(
                values: [
                  for (final value in ['any', 'medium', 'low'])
                    (value, context.t('budget_$value')),
                ],
                selected: prefs['budget'] as String? ?? 'any',
                onSelected: (value) => update('budget', value),
              ),
            ),
            StatusNote(text: context.t('budget_notice')),
            for (final name in [
              'learning',
              'analytics',
              'ai_consent',
              'seasonal',
            ])
              EatMeToggleRow(
                value: prefs[name] == true,
                title: context.t('pref_$name'),
                subtitle: context.t('pref_${name}_body'),
                onChanged: data == null ? null : (v) => update(name, v),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          children: [
            Text(
              context.t('cooking_skill'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in ['beginner', 'confident', 'advanced'])
                  ChoiceChip(
                    avatar: Text(
                      {
                        'beginner': '🥚',
                        'confident': '🍳',
                        'advanced': '👨‍🍳',
                      }[level]!,
                    ),
                    label: Text(context.t(level)),
                    selected: (prefs['skill'] ?? 'beginner') == level,
                    onSelected: data == null
                        ? null
                        : (_) => update('skill', level),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '${context.t('cooking_time')} · ${(selectedMinutes ?? (prefs['max_minutes'] as num? ?? 30).toDouble()).round()} min',
            ),
            Row(
              children: [
                const Text('🐇', style: TextStyle(fontSize: 26)),
                Expanded(
                  child: Slider(
                    min: 30,
                    max: 240,
                    divisions: 7,
                    value:
                        (selectedMinutes ??
                                (prefs['max_minutes'] as num? ?? 30).toDouble())
                            .clamp(30, 240),
                    label:
                        '${(selectedMinutes ?? (prefs['max_minutes'] as num? ?? 30).toDouble()).round()} min',
                    onChanged: data == null
                        ? null
                        : (v) => setState(() => selectedMinutes = v),
                    onChangeEnd: (v) async {
                      await update('max_minutes', v.round());
                      if (mounted) setState(() => selectedMinutes = null);
                    },
                  ),
                ),
                const Text('🐢', style: TextStyle(fontSize: 26)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.t('preferred_cuisines'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cuisine in {
                  'italian',
                  'mediterranean',
                  'french',
                  'indian',
                  'japanese',
                  'chinese',
                  'mexican',
                  'thai',
                  'middle_eastern',
                  'american',
                  ...List<String>.from(prefs['cuisines'] as List? ?? []),
                })
                  FilterChip(
                    label: Text(
                      (Localizations.of<EatMeStrings>(
                            context,
                            EatMeStrings,
                          )!.values['cuisine_$cuisine']) ??
                          cuisine,
                    ),
                    selected: (prefs['cuisines'] as List? ?? []).contains(
                      cuisine,
                    ),
                    onSelected: data == null
                        ? null
                        : (active) {
                            final values = List<String>.from(
                              prefs['cuisines'] as List? ?? [],
                            );
                            active
                                ? values.add(cuisine)
                                : values.remove(cuisine);
                            update('cuisines', values);
                          },
                  ),
              ],
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

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      child,
    ],
  );
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
          title: context.t('notification_controls'),
          children: [
            EatMeToggleRow(
              value: prefs['enabled'] == true,
              title: context.t('enable_reminders'),
              icon: EatMeGlyph.bell,
              onChanged: data == null ? null : (v) => update({'enabled': v}),
            ),
            StatusNote(text: context.t('notification_privacy')),
          ],
        ),
        SettingsGroup(
          title: context.t('notification_categories'),
          children: [
            for (final category in [
              'expiry',
              'plans',
              'shopping',
              'household',
              'recalls',
            ])
              EatMeToggleRow(
                title: context.t('notify_$category'),
                value: categories.contains(category),
                onChanged: data == null
                    ? null
                    : (v) async {
                        if (v) {
                          categories.add(category);
                        } else {
                          categories.remove(category);
                        }
                        await update({'categories': categories});
                      },
              ),
            for (final setting in ['quiet_start', 'quiet_end', 'daily_cap'])
              SettingRow(
                title: context.t(setting),
                icon: setting == 'daily_cap'
                    ? EatMeGlyph.settings
                    : EatMeGlyph.clock,
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
          SettingRow(
            icon: EatMeGlyph.bell,
            title: context.t('notify_${item['category']}'),
            subtitle: '${item['created_at']}'.substring(0, 10),
            trailing: item['read_at'] == null
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
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
  String moneyLabel() {
    final values = records(data?['money_saved']?['amounts']);
    if (values.isEmpty) return '—';
    const symbols = {'EUR': '€', 'USD': r'$', 'GBP': '£', 'CHF': 'CHF '};
    return values
        .map(
          (item) =>
              '${symbols[item['currency']] ?? '${item['currency']} '}${item['value']}',
        )
        .join(' · ');
  }

  void methodology() {
    final method = Map<String, dynamic>.from(
      data?['savings_method'] as Map? ?? {},
    );
    final source = Map<String, dynamic>.from(
      method['factor_source'] as Map? ?? {},
    );
    sheet(
      context,
      ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        children: [
          Text(
            context.t('how_savings_calculated'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(context.t('savings_method_body')),
          const SizedBox(height: 20),
          SettingsGroup(
            children: [
              SettingRow(
                title: context.t('money_method_title'),
                subtitle: context.t('money_method_body'),
                icon: EatMeGlyph.shoppingBasket,
              ),
              SettingRow(
                title: context.t('co2_method_title'),
                subtitle: context.t('co2_method_body'),
                icon: EatMeGlyph.leaf,
              ),
              SettingRow(
                title: context.t('estimate_limits_title'),
                subtitle: context.t('estimate_limits_body'),
                icon: EatMeGlyph.info,
              ),
            ],
          ),
          if ('${source['url'] ?? ''}'.startsWith('https://'))
            OutlinedButton(
              onPressed: () => launchUrl(
                Uri.parse('${source['url']}'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(context.t('read_factor_source')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carbon = data?['carbon_saved'] as Map?;
    final method = data?['savings_method'] as Map? ?? {};
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('insights'))),
      body: content([
        Text(
          context.t('small_habits'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.t('insights_support'),
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        EatMeTabStrip(
          values: [
            for (final value in ['overview', 'impact', 'alerts', 'tips'])
              (value, context.t('insights_$value')),
          ],
          selected: tab,
          onSelected: (value) => setState(() => tab = value),
        ),
        const SizedBox(height: 24),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InformationPanel(
                tinted: false,
                child: SettingRow(
                  title: localized(batch.food.name, context.language),
                  subtitle: expiryLabel(context, batch),
                  icon: EatMeGlyph.clockAlert,
                  onTap: () => context.push('/expiry'),
                ),
              ),
            ),
          AsyncAction(
            label: context.t('notifications'),
            secondary: true,
            action: () async => context.push('/notifications'),
          ),
        ],
        if (tab == 'tips') ...[
          StatusNote(text: context.t('practical_tips')),
          TextButton(
            onPressed: () => context.push('/plan'),
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
          Row(
            children: [
              for (final metric in ['cooked_meals', 'different_recipes']) ...[
                Expanded(
                  child: _InsightMetric(
                    value: '${data?[metric] ?? 0}',
                    label: context.t(metric),
                  ),
                ),
                if (metric == 'cooked_meals') const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SettingsGroup(
            title: context.t('recorded_activity'),
            children: [
              for (final entry
                  in (data?['inventory_event_counts'] as Map? ?? {}).entries)
                SettingRow(
                  title: context.t('event_${entry.key}'),
                  icon: EatMeGlyph.history,
                  trailing: StatusBadge(label: '${entry.value}'),
                ),
            ],
          ),
          for (final unit
              in (data?['recorded_quantities'] as Map? ?? {}).entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InformationPanel(
                tinted: false,
                child: Text(
                  '${context.t('recorded_use')}: ${unit.value['used']} ${unit.key} · ${context.t('discarded_amount')}: ${unit.value['discarded']} ${unit.key}',
                ),
              ),
            ),
          StatusNote(text: context.t('recorded_quantities_notice')),
        ],
        if (tab == 'impact') ...[
          Text(
            context.t('estimated_savings'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.t('estimated_savings_support'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _ImpactMetric(
                  icon: EatMeGlyph.shoppingBasket,
                  value: moneyLabel(),
                  label: context.t('estimated_food_value'),
                  available: data?['money_saved'] != null,
                ),
                _ImpactMetric(
                  icon: EatMeGlyph.leaf,
                  value: carbon == null ? '—' : '${carbon['value']} kg CO₂e',
                  label: context.t('estimated_co2e'),
                  available: carbon != null,
                ),
              ];
              if (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(16) > 21) {
                return Column(
                  children: [
                    cards.first,
                    const SizedBox(height: 12),
                    cards.last,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cards.first),
                  const SizedBox(width: 12),
                  Expanded(child: cards.last),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          InformationPanel(
            tinted: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('estimate_coverage'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('eligible_events_count', {
                    'count': method['eligible_events'] ?? 0,
                  }),
                ),
                if (carbon != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    context.t('factor_coverage_mass', {
                      'covered': carbon['covered_quantity_g'] ?? '0',
                      'eligible': carbon['eligible_quantity_g'] ?? '0',
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          AsyncAction(
            label: context.t('how_savings_calculated'),
            secondary: true,
            action: () async => methodology(),
          ),
        ],
        const SizedBox(height: 18),
        StatusNote(text: context.t('insights_method')),
      ]),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => InformationPanel(
    tinted: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontFamily: 'EatMeSans'),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    ),
  );
}

class _ImpactMetric extends StatelessWidget {
  const _ImpactMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.available,
  });
  final EatMeGlyph icon;
  final String value, label;
  final bool available;

  @override
  Widget build(BuildContext context) => InformationPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EatMeIcon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 16),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(label),
        if (!available) ...[
          const SizedBox(height: 8),
          Text(
            context.t('savings_unavailable'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
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
