import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class ReauthenticatePage extends ConsumerStatefulWidget {
  const ReauthenticatePage({super.key});
  @override
  ConsumerState<ReauthenticatePage> createState() => _ReauthenticateState();
}

class _ReauthenticateState extends ConsumerState<ReauthenticatePage> {
  final password = TextEditingController();
  late final account = ref.read(apiProvider).userId;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (ref.read(apiProvider).userId != account) {
      await ref.read(appProvider.notifier).logout();
      throw const ApiFailure('invalid_credentials');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('reauthenticate'))),
    body: PageBody(
      children: [
        Text(context.t('reauthenticate_body')),
        const SizedBox(height: 24),
        TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: context.t('password')),
        ),
        const SizedBox(height: 16),
        AsyncAction(
          label: context.t('login'),
          action: () async {
            final email = Supabase.instance.client.auth.currentUser?.email;
            if (email == null) throw const ApiFailure('invalid_credentials');
            await ref
                .read(apiProvider)
                .login(email, password.text, register: false);
            await verify();
          },
        ),
        if (EatMeApi.oauthEnabled) ...[
          const SizedBox(height: 16),
          AsyncAction(
            label: context.t('apple'),
            secondary: true,
            action: () async {
              await ref.read(apiProvider).oauth(OAuthProvider.apple);
              await verify();
            },
          ),
          const SizedBox(height: 16),
          AsyncAction(
            label: context.t('google'),
            secondary: true,
            action: () => ref.read(apiProvider).oauth(OAuthProvider.google),
          ),
        ],
      ],
    ),
  );
}
