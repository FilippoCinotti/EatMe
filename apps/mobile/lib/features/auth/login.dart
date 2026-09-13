import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  bool register = false,
      verificationSent = false,
      welcome = true,
      obscure = true,
      accepted = false;
  final confirmation = TextEditingController();
  @override
  void dispose() {
    confirmation.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    if (welcome) {
      return Scaffold(
        body: PageBody(
          children: [
            const SizedBox(height: 32),
            const Center(child: EatMeWordmark(large: true)),
            const SizedBox(height: 24),
            Text(
              context.t('lifestyle_tagline'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 28),
            const FoodImage(
              id: '913a438b-0805-543d-8719-c0253f8f103a',
              height: 260,
              radius: 28,
            ),
            const SizedBox(height: 24),
            Text(
              context.t('welcome_promise'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => setState(() {
                welcome = false;
                register = true;
              }),
              child: Text(context.t('start_now')),
            ),
            TextButton(
              onPressed: () => setState(() {
                welcome = false;
                register = false;
              }),
              child: Text(context.t('already_account')),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: PageBody(
        children: [
          EditorialHeader(
            eyebrow: context.t('eatme'),
            title: context.t(register ? 'create_account' : 'welcome_back'),
            subtitle: context.t('lifestyle_tagline'),
            actions: [
              RoundAction(
                icon: EatMeGlyph.chevronLeft,
                label: context.t('back'),
                onPressed: () => setState(() => welcome = true),
              ),
            ],
          ),
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: context.t('email')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    suffixIcon: EatMeIconButton(
                      glyph: obscure ? EatMeGlyph.eye : EatMeGlyph.eyeOff,
                      label: context.t(
                        obscure ? 'show_password' : 'hide_password',
                      ),
                      onPressed: () => setState(() => obscure = !obscure),
                      size: 44,
                      backgroundColor: Colors.transparent,
                    ),
                    labelText: context.t('password'),
                    helperText: context.t('password_hint'),
                  ),
                ),
              ],
            ),
          ),
          if (register) ...[
            const SizedBox(height: 12),
            TextField(
              controller: confirmation,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: context.t('confirm_password'),
              ),
            ),
            if (!EatMeApi.development) ...[
              CheckboxListTile(
                value: accepted,
                title: Text(context.t('accept_terms_privacy')),
                onChanged: (v) => setState(() => accepted = v ?? false),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final link in [
                    ('terms', const String.fromEnvironment('TERMS_URL')),
                    ('privacy', const String.fromEnvironment('PRIVACY_URL')),
                  ])
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(link.$2);
                        if (uri != null && uri.scheme == 'https') {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Text(context.t(link.$1)),
                    ),
                ],
              ),
            ],
          ],
          if (!register && !EatMeApi.development)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await api.resetPassword(email.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t('reset_sent'))),
                    );
                  }
                },
                child: Text(context.t('forgot_password')),
              ),
            ),
          const SizedBox(height: 24),
          AsyncAction(
            label: context.t(register ? 'create_account' : 'login'),
            action: () async {
              if (register && password.text != confirmation.text) {
                throw const ApiFailure('password_mismatch');
              }
              if (register && !EatMeApi.development) {
                if (!accepted) throw const ApiFailure('terms_required');
                if (![
                  const String.fromEnvironment('TERMS_URL'),
                  const String.fromEnvironment('PRIVACY_URL'),
                ].every((v) => Uri.tryParse(v)?.scheme == 'https')) {
                  throw const ApiFailure('legal_configuration_required');
                }
              }
              final signedIn = await api.login(
                email.text.trim(),
                password.text,
                register: register,
              );
              if (signedIn) {
                await ref.read(appProvider.notifier).hydrate();
              } else if (mounted) {
                setState(() => verificationSent = true);
              }
            },
          ),
          TextButton(
            onPressed: () => setState(() => register = !register),
            child: Text(context.t(register ? 'have_account' : 'new_account')),
          ),
          if (verificationSent) StatusNote(text: context.t('verify_email')),
          if (!EatMeApi.development && EatMeApi.oauthEnabled) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(context.t('or_continue_with')),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            AsyncAction(
              label: context.t('google'),
              secondary: true,
              action: () => api.oauth(OAuthProvider.google),
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: context.t('apple'),
              secondary: true,
              action: () => api.oauth(OAuthProvider.apple),
            ),
          ],
          if (EatMeApi.development)
            StatusNote(text: context.t('development_login')),
        ],
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final password = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('reset_password'))),
    body: PageBody(
      children: [
        TextField(
          controller: password,
          obscureText: true,
          decoration: InputDecoration(labelText: context.t('new_password')),
        ),
        const SizedBox(height: 24),
        AsyncAction(
          label: context.t('save'),
          action: () async {
            if (password.text.length < 12) {
              throw const ApiFailure('password_length');
            }
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(password: password.text),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}
