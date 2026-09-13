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
    final dietNames = state.diets
        .where((d) => ids.contains(d.id))
        .map((d) => localized(d.name, context.language))
        .join(' · ');
    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile'))),
      body: PageBody(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.person_outline,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            state.profile['name'] as String? ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const IconBadge(Icons.eco_outlined),
            title: Text(context.t('diet')),
            subtitle: Text(
              dietNames.isEmpty ? context.t('no_diet') : dietNames,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const IconBadge(Icons.shield_outlined),
            title: Text(context.t('allergies_intolerances')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('household')),
            subtitle: Text(
              context.t('portions', {
                'count': state.profile['household_size'] as int? ?? 1,
              }),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit'),
          ),
          SectionHeading(title: context.t('your_kitchen')),
          for (final item in [
            ('household', '/household', Icons.group_outlined),
            ('preferences', '/preferences', Icons.tune),
            ('notifications', '/notifications', Icons.notifications_none),
            ('insights', '/insights', Icons.insights_outlined),
            (
              'subscriptions',
              '/subscriptions',
              Icons.workspace_premium_outlined,
            ),
            ('offline_sync', '/sync', Icons.sync),
            ('evidence_library', '/evidence', Icons.library_books_outlined),
          ])
            Card(child: ListTile(
              leading: IconBadge(item.$3),
              title: Text(context.t(item.$1)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.$2),
            )),
          const SizedBox(height: 28),
          Text(
            context.t('preferences'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          DropdownButtonFormField<ThemeMode>(
            initialValue: state.theme,
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('privacy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
          const Divider(),
          const SizedBox(height: 24),
          AsyncAction(
            label: context.t('logout'),
            secondary: true,
            action: () => ref.read(appProvider.notifier).logout(),
          ),
          const SizedBox(height: 16),
          if (state.isDemo) StatusNote(text: context.t('development_catalog')),
        ],
      ),
    );
  }
}

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(context.t('privacy'))),
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
