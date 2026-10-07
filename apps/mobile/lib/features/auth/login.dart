import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'welcome/landing.dart';

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
      return WelcomeLanding(
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
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
      _SocialSignInButton(
        key: const ValueKey('google-sign-in'),
        label: context.t('continue_google'),
        provider: OAuthProvider.google,
        action: () => api.oauth(OAuthProvider.google),
      ),
      const SizedBox(height: 10),
      _SocialSignInButton(
        key: const ValueKey('apple-sign-in'),
        label: context.t('continue_apple'),
        provider: OAuthProvider.apple,
        action: () => api.oauth(OAuthProvider.apple),
      ),
    ],
  );
}

class _SocialSignInButton extends StatefulWidget {
  const _SocialSignInButton({
    super.key,
    required this.label,
    required this.provider,
    required this.action,
  });

  final String label;
  final OAuthProvider provider;
  final Future<void> Function() action;

  @override
  State<_SocialSignInButton> createState() => _SocialSignInButtonState();
}

class _SocialSignInButtonState extends State<_SocialSignInButton> {
  bool busy = false;

  Future<void> run() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.action();
    } catch (error) {
      if (!mounted) return;
      final code = error is ApiFailure
          ? error.code
          : error is AuthException
          ? 'authentication_failed'
          : 'unknown_error';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t(code))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = widget.provider == OAuthProvider.google;
    final background = google ? Colors.white : Colors.black;
    final foreground = google ? const Color(0xff1f1f1f) : Colors.white;
    return Material(
      color: background,
      shape: StadiumBorder(
        side: BorderSide(
          color: google
              ? const Color(0xff747775)
              : Colors.white.withValues(alpha: .18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : run,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          )
                        : google
                        ? const _GoogleMark(size: 20)
                        : const Icon(
                            Icons.apple,
                            size: 24,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GoogleMarkPainter());
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .2;
    final arcRect = rect.deflate(stroke * .52);
    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(const Color(0xff4285f4), -.15, 1.72);
    arc(const Color(0xff34a853), 1.57, 1.55);
    arc(const Color(0xfffbbc05), 3.12, .78);
    arc(const Color(0xffea4335), 3.90, 1.42);

    final blue = Paint()
      ..color = const Color(0xff4285f4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * .54, size.height * .5),
      Offset(size.width * .91, size.height * .5),
      blue,
    );
    canvas.drawLine(
      Offset(size.width * .84, size.height * .5),
      Offset(size.width * .84, size.height * .7),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
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
