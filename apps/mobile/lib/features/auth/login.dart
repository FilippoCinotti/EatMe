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
      return _WelcomeLanding(
        onStart: () => setState(() {
          welcome = false;
          register = true;
        }),
        onLogin: () => setState(() {
          welcome = false;
          register = false;
        }),
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
          if (!EatMeApi.development && EatMeApi.oauthEnabled) ...[
            _SocialAuthBlock(api: api),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(context.t('or_continue_with_email')),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
          ],
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
              const SizedBox(height: 14),
              InformationPanel(
                tinted: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => accepted = !accepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox.adaptive(
                        value: accepted,
                        onChanged: (value) =>
                            setState(() => accepted = value == true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(context.t('accept_terms_privacy')),
                        ),
                      ),
                    ],
                  ),
                ),
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
          if (EatMeApi.development)
            StatusNote(text: context.t('development_login')),
        ],
      ),
    );
  }
}

class _WelcomeLanding extends StatelessWidget {
  const _WelcomeLanding({required this.onStart, required this.onLogin});

  final VoidCallback onStart;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 760;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              compact ? 10 : 18,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  minHeight:
                      constraints.maxHeight -
                      (compact ? 30 : 38) -
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const EatMeWordmark(large: true),
                      SizedBox(height: compact ? 12 : 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(
                          context.t('lifestyle_tagline'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 24),
                      FoodImage(
                        id: '913a438b-0805-543d-8719-c0253f8f103a',
                        height: compact ? 190 : 220,
                        radius: 26,
                      ),
                      SizedBox(height: compact ? 18 : 22),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Text(
                          context.t('welcome_promise'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            textStyle: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          onPressed: onStart,
                          child: Text(context.t('start_now')),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        onPressed: onLogin,
                        child: Text(context.t('already_account')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _SocialAuthBlock extends StatelessWidget {
  const _SocialAuthBlock({required this.api});
  final EatMeApi api;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.t('social_first_support'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 14),
      AsyncAction(
        label: context.t('continue_google'),
        action: () => api.oauth(OAuthProvider.google),
      ),
      const SizedBox(height: 10),
      AsyncAction(
        label: context.t('continue_apple'),
        secondary: true,
        action: () => api.oauth(OAuthProvider.apple),
      ),
    ],
  );
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
