import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization.dart';
import '../../core/api.dart';
import '../../core/data_export.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final settings = Map<String, dynamic>.from(
      state.profile['settings'] as Map? ?? {},
    );
    final ids = (settings['diets'] as List? ?? [])
        .map((d) => d['diet_id'])
        .toSet();
    final primaryName = state.diets
        .where((d) => d.id == settings['primary_diet'])
        .map((d) => localized(d.name, context.language))
        .firstOrNull;
    final dietNames = state.diets
        .where((d) => ids.contains(d.id))
        .map((d) => localized(d.name, context.language))
        .join(' · ');
    final name = state.profile['name'] as String? ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    final themeLabel = context.t(state.theme.name);
    return Scaffold(
      body: PageBody(
        children: [
          EditorialHeader(
            eyebrow: context.t('profile_eyebrow'),
            title: context.t('profile_editorial'),
            subtitle: context.t('profile_support'),
          ),
          InformationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: initials.isEmpty
                          ? EatMeIcon(
                              EatMeGlyph.userRound,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 26,
                            )
                          : Text(
                              initials,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name.isEmpty ? context.t('profile') : name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (primaryName != null || dietNames.isNotEmpty)
                      _ProfilePill(
                        icon: EatMeGlyph.leaf,
                        label: primaryName ?? dietNames,
                      ),
                    if (state.profile['household_size'] is int)
                      _ProfilePill(
                        icon: EatMeGlyph.usersRound,
                        label: context.t('household_members_count', {
                          'count': state.profile['household_size'] as int,
                        }),
                      ),
                    _ProfilePill(
                      icon: state.theme == ThemeMode.dark
                          ? EatMeGlyph.moon
                          : state.theme == ThemeMode.light
                          ? EatMeGlyph.sun
                          : EatMeGlyph.monitor,
                      label: themeLabel,
                    ),
                    _ProfilePill(
                      icon: EatMeGlyph.languages,
                      label: context.language.toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              SettingRow(
                title: context.t('diet_health'),
                subtitle: context.t('allergies_intolerances'),
                icon: EatMeGlyph.shieldCheck,
                onTap: () => context.push('/diet-health'),
              ),
              SettingRow(
                title: context.t('household'),
                icon: EatMeGlyph.usersRound,
                onTap: () => context.push('/household'),
              ),
              SettingRow(
                title: context.t('preferences'),
                icon: EatMeGlyph.slidersHorizontal,
                onTap: () => context.push('/preferences'),
              ),
              SettingRow(
                title: context.t('notifications'),
                icon: EatMeGlyph.bell,
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          SectionHeading(
            title: context.t('your_kitchen'),
            actionLabel: context.t('view_all'),
            onAction: () => sheet(context, const _ProfileToolsSheet()),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tools = [
                ('meal_planner', '/plan', EatMeGlyph.calendarDays),
                ('shopping_list', '/shopping', EatMeGlyph.shoppingBasket),
                ('recipe_library', '/recipe-library', EatMeGlyph.bookOpen),
              ];
              if (constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22) {
                return Column(
                  children: [
                    for (final item in tools) ...[
                      SettingRow(
                        title: context.t(item.$1),
                        icon: item.$3,
                        onTap: () => context.push(item.$2),
                      ),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < tools.length; index++) ...[
                      Expanded(
                        child: ShortcutTile(
                          title: context.t(tools[index].$1),
                          icon: tools[index].$3,
                          onTap: () => context.push(tools[index].$2),
                        ),
                      ),
                      if (index < tools.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          SettingsGroup(
            title: context.t('privacy_and_data'),
            children: [
              SettingRow(
                title: context.t('privacy'),
                subtitle: context.t('privacy_profile_hint'),
                icon: EatMeGlyph.shieldCheck,
                onTap: () => context.push('/privacy'),
              ),
            ],
          ),
          SettingsGroup(
            title: context.t('more'),
            children: [
              for (final item in [
                ('subscriptions', '/subscriptions', EatMeGlyph.badgeCheck),
                ('offline_sync', '/sync', EatMeGlyph.refreshCw),
                ('recent_activity', '/household-activity', EatMeGlyph.history),
                ('insights', '/insights', EatMeGlyph.chartSpline),
                ('evidence_library', '/evidence', EatMeGlyph.libraryBig),
              ])
                SettingRow(
                  title: context.t(item.$1),
                  icon: item.$3,
                  onTap: () => context.push(item.$2),
                ),
            ],
          ),
          AsyncAction(
            label: context.t('logout'),
            secondary: true,
            action: () => ref.read(appProvider.notifier).logout(),
          ),
          if (state.isDemo) StatusNote(text: context.t('development_catalog')),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.icon, required this.label});

  final EatMeGlyph icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainer.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EatMeIcon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}

class _ProfileToolsSheet extends StatelessWidget {
  const _ProfileToolsSheet();

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
    children: [
      Text(
        context.t('your_kitchen'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      for (final item in [
        ('meal_planner', '/plan', EatMeGlyph.calendarDays),
        ('shopping_list', '/shopping', EatMeGlyph.shoppingBasket),
        ('recipe_library', '/recipe-library', EatMeGlyph.bookOpen),
        ('leftovers', '/leftovers', EatMeGlyph.packageOpen),
        ('scan_and_import', '/scanning', EatMeGlyph.scanLine),
        ('wellbeing', '/wellbeing', EatMeGlyph.heartPulse),
      ])
        SettingRow(
          title: context.t(item.$1),
          icon: item.$3,
          onTap: () {
            Navigator.pop(context);
            context.push(item.$2);
          },
        ),
    ],
  );
}

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('privacy'))),
    body: PageBody(
      children: [
        Text(
          context.t('your_data'),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 24),
        InformationPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EatMeIcon(
                EatMeGlyph.shieldCheck,
                color: Theme.of(context).colorScheme.primary,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.t('privacy_body'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          title: context.t('your_data_section'),
          children: [
            AsyncAction(
              label: context.t('export_data'),
              action: () async {
                final data = await ref
                    .read(apiProvider)
                    .request('GET', '/privacy/export');
                final text = const JsonEncoder.withIndent('  ').convert(data);
                if (context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.t('export_data')),
                      content: SizedBox(
                        width: 500,
                        child: SingleChildScrollView(
                          child: SelectableText(text),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.t('close')),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Text(context.t('copy_json')),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: context.t('export_file'),
              secondary: true,
              action: () async {
                final data = await ref
                    .read(apiProvider)
                    .request('GET', '/privacy/export');
                if (context.mounted) await DataExport.share(context, data);
              },
            ),
          ],
        ),
        SettingsGroup(
          title: context.t('account_and_consent'),
          children: [
            SettingRow(
              title: context.t('review_consent'),
              subtitle: context.t('consent_controls_hint'),
              icon: EatMeGlyph.shield,
              onTap: () => context.push('/profile/edit'),
            ),
          ],
        ),
        ...[
          Text(
            context.t('danger_zone'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          AsyncAction(
            label: context.t('delete_account'),
            secondary: true,
            destructive: true,
            action: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.t('delete_account')),
                  content: Text(context.t('delete_confirm')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.t('delete')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              try {
                await ref
                    .read(apiProvider)
                    .request('DELETE', '/profile', body: {'confirm': true});
                await ref.read(appProvider.notifier).deleted();
              } on ApiFailure catch (error) {
                if ([
                  'reauthentication_required',
                  'apple_reauthentication_required',
                ].contains(error.code)) {
                  if (context.mounted) await context.push('/reauthenticate');
                  return;
                }
                rethrow;
              }
            },
          ),
        ],
      ],
    ),
  );
}
