import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text(context.t('household'))),
      body: content([
        Text(
          current?['name'] as String? ?? context.t('your_household'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: context.t('household_privacy')),
        for (final member in members)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(member['name'] as String),
            subtitle: Text(context.t('role_${member['role']}')),
            trailing: current?['role'] != 'owner' || member['user_id'] == userId
                ? null
                : PopupMenuButton<String>(
                    onSelected: (role) async {
                      await guard(() async {
                        await command({
                          'action': role == 'owner' ? 'transfer' : 'role',
                          'role': role,
                          'user_id': member['user_id'],
                        });
                      });
                    },
                    itemBuilder: (context) => [
                      for (final role in ['member', 'viewer', 'owner'])
                        PopupMenuItem(
                          value: role,
                          child: Text(context.t('role_$role')),
                        ),
                    ],
                  ),
          ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('share_constraints')),
          subtitle: Text(context.t('share_constraints_body')),
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
        for (final home in homes.where((h) => h['id'] != data?['current_id']))
          ListTile(
            title: Text(home['name'] as String? ?? context.t('your_household')),
            subtitle: Text(context.t('role_${home['role']}')),
            trailing: const Icon(Icons.swap_horiz),
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
