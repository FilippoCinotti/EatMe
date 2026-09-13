import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class HouseholdPage extends ConsumerStatefulWidget {
  const HouseholdPage({super.key});
  @override
  ConsumerState<HouseholdPage> createState() => _HouseholdState();
}

class _HouseholdState extends ResourceState<HouseholdPage> {
  @override
  String get path => '/households';
  @override
  Widget build(BuildContext context) {
    final members = records(data?['members']);
    final homes = records(data?['items']);
    final current = homes
        .where((h) => h['id'] == data?['current_id'])
        .firstOrNull;
    final userId = ref.watch(appProvider).profile['user_id'];
    final me = members.where((m) => m['user_id'] == userId).firstOrNull;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('household'))),
      body: content([
        Text(
          current?['name'] as String? ?? context.t('your_household'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: context.t('household_privacy')),
        SettingRow(
          icon: EatMeGlyph.history,
          title: context.t('recent_activity'),
          onTap: () => context.push('/household-activity'),
        ),
        SettingsGroup(
          children: [
            for (final member in members)
              _HouseholdMemberRow(
                name: member['name'] as String,
                role: context.t('role_${member['role']}'),
                canManage:
                    current?['role'] == 'owner' && member['user_id'] != userId,
                onRole: (role) async {
                  await guard(() async {
                    await command({
                      'action': role == 'owner' ? 'transfer' : 'role',
                      'role': role,
                      'user_id': member['user_id'],
                    });
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        EatMeToggleRow(
          title: context.t('share_constraints'),
          subtitle: context.t('share_constraints_body'),
          icon: EatMeGlyph.shieldCheck,
          value: me?['share_constraints'] == 1,
          onChanged: (value) async {
            await guard(() async {
              await command({
                'action': 'share_constraints',
                'enabled': value,
                'consent_version': data?['consent_version'],
              });
              await ref.read(appProvider.notifier).hydrate();
            });
          },
        ),
        if (current?['role'] == 'owner') ...[
          if (records(data?['invitations']).isNotEmpty)
            Text(context.t('pending_invitations')),
          for (final invitation in records(data?['invitations']))
            SettingRow(
              icon: EatMeGlyph.clock,
              title: context.t('role_${invitation['role']}'),
              subtitle: '${invitation['expires_at']}'.substring(0, 10),
              trailing: EatMeIconButton(
                glyph: EatMeGlyph.trash2,
                label: context.t('revoke_invitation'),
                onPressed: () => guard(() async {
                  await command({
                    'action': 'revoke',
                    'invitation_id': invitation['id'],
                  });
                }),
              ),
            ),
          AsyncAction(
            label: context.t('invite_member'),
            action: () async {
              final result = await command({
                'action': 'invite',
                'role': 'member',
              });
              if (!mounted || !context.mounted) return;
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.t('invitation_code')),
                  content: SelectableText('${result['token']}'),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: result['token'] as String),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(context.t('copy')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('close')),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AsyncAction(
            label: context.t('rename_household'),
            secondary: true,
            action: () async {
              final name = await askText(context, context.t('household'));
              if (name != null) {
                await command({'action': 'rename', 'name': name});
              }
            },
          ),
        ],
        const SizedBox(height: 16),
        AsyncAction(
          label: context.t('join_household'),
          secondary: true,
          action: () async {
            final token = await askText(context, context.t('invitation_code'));
            if (token != null) {
              await command({'action': 'accept', 'token': token});
              await ref.read(appProvider.notifier).hydrate();
            }
          },
        ),
        const SizedBox(height: 24),
        if (current?['role'] != 'owner')
          AsyncAction(
            label: context.t('leave_household'),
            secondary: true,
            action: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.t('leave_household')),
                  content: Text(context.t('leave_household_body')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.t('leave_household')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await command({'action': 'leave'});
              await ref.read(appProvider.notifier).hydrate();
            },
          ),
        for (final home in homes.where((h) => h['id'] != data?['current_id']))
          SettingRow(
            icon: EatMeGlyph.refreshCw,
            title: home['name'] as String? ?? context.t('your_household'),
            subtitle: context.t('role_${home['role']}'),
            onTap: () async {
              await guard(() async {
                await command({'action': 'switch', 'household_id': home['id']});
                await ref.read(appProvider.notifier).hydrate();
              });
            },
          ),
      ]),
    );
  }
}

class _HouseholdMemberRow extends StatelessWidget {
  const _HouseholdMemberRow({
    required this.name,
    required this.role,
    required this.canManage,
    required this.onRole,
  });

  final String name, role;
  final bool canManage;
  final ValueChanged<String> onRole;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Text(
              initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              icon: const EatMeIcon(EatMeGlyph.ellipsis),
              onSelected: onRole,
              itemBuilder: (context) => [
                for (final role in ['member', 'viewer', 'owner'])
                  PopupMenuItem(
                    value: role,
                    child: Text(context.t('role_$role')),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
