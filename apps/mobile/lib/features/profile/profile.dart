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
    return Scaffold(body: PageBody(children: [
      EditorialHeader(eyebrow: context.t('profile_eyebrow'), title: context.t('profile_editorial'), subtitle: context.t('profile_support')),
      InformationPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primary, child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onPrimary, size: 28)), const SizedBox(width: 16), Expanded(child: Text(name.isEmpty ? context.t('profile') : name, style: Theme.of(context).textTheme.headlineMedium))]),
        const SizedBox(height: 20),
        Text(primaryName ?? (dietNames.isEmpty ? context.t('no_diet') : dietNames), style: Theme.of(context).textTheme.titleMedium),
        if (state.profile['household_size'] is int) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.t('portions', {'count': state.profile['household_size'] as int}))),
      ])),
      const SizedBox(height: 24),
      SettingsGroup(children: [
        SettingRow(title: context.t('diet_health'), subtitle: context.t('allergies_intolerances'), icon: Icons.shield_outlined, onTap: () => context.push('/profile/edit')),
        SettingRow(title: context.t('household'), icon: Icons.group_outlined, onTap: () => context.push('/household')),
        SettingRow(title: context.t('preferences'), icon: Icons.tune, onTap: () => context.push('/preferences')),
        SettingRow(title: context.t('notifications'), icon: Icons.notifications_none, onTap: () => context.push('/notifications')),
      ]),
      SectionHeading(title: context.t('your_kitchen')),
      AdaptivePhotoGrid(children: [for (final item in [
        ('meal_planner','/planner',Icons.calendar_month_outlined),
        ('shopping_list','/shopping',Icons.shopping_bag_outlined),
        ('recipe_library','/recipe-library',Icons.menu_book_outlined),
        ('leftovers','/leftovers',Icons.takeout_dining_outlined),
        ('scan_and_import','/scanning',Icons.document_scanner_outlined),
        ('wellbeing','/wellbeing',Icons.favorite_outline),
      ]) ShortcutTile(title: context.t(item.$1), icon: item.$3, onTap: () => context.push(item.$2))]),
      const SizedBox(height: 28),
      SettingsGroup(children: [for (final item in [
        ('privacy','/privacy',Icons.lock_outline),
        ('subscriptions','/subscriptions',Icons.workspace_premium_outlined),
        ('offline_sync','/sync',Icons.sync),
        ('recent_activity','/household-activity',Icons.history),
        ('insights','/insights',Icons.insights_outlined),
        ('evidence_library','/evidence',Icons.library_books_outlined),
      ]) SettingRow(title: context.t(item.$1), icon: item.$3, onTap: () => context.push(item.$2))]),
      AsyncAction(label: context.t('logout'), secondary: true, action: () => ref.read(appProvider.notifier).logout()),
      if (state.isDemo) StatusNote(text: context.t('development_catalog')),
    ]));
  }
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
        Text(
          context.t('privacy_body'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
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
                    child: SingleChildScrollView(child: SelectableText(text)),
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
        const SizedBox(height: 16),
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
        TextButton(
          onPressed: () => context.push('/profile/edit'),
          child: Text(context.t('review_consent')),
        ),
        ...[
          const SizedBox(height: 32),
          AsyncAction(
            label: context.t('delete_account'),
            secondary: true,
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
