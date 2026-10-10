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
    return Theme(
      data: _compactAuthTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => Scaffold(
          body: PageBody(
            children: [
              Row(
                children: [
                  const EatMeBrandMark(size: 22),
                  const SizedBox(width: 7),
                  Text.rich(
                    const TextSpan(
                      text: 'EatMe',
                      children: [
                        TextSpan(text: '+', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  RoundAction(
                    icon: EatMeGlyph.chevronLeft,
                    label: context.t('back'),
                    onPressed: () => setState(() => welcome = true),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                context.t(register ? 'auth_register_title' : 'welcome_back'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                context.t(
                  register ? 'auth_register_subtitle' : 'auth_login_subtitle',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (!EatMeApi.development && EatMeApi.oauthEnabled) ...[
                _SocialAuthBlock(api: api),
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
              ],
              AutofillGroup(
                child: Column(
                  children: [
                    _AuthField(
                      label: context.t('email'),
                      child: TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          hintText: context.t('auth_email_hint'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AuthField(
                      label: context.t('password'),
                      child: TextField(
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
                          hintText: context.t(
                            register
                                ? 'auth_create_password'
                                : 'auth_password_hint',
                          ),
                          helperText: register
                              ? context.t('password_hint')
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (register) ...[
                const SizedBox(height: 12),
                _AuthField(
                  label: context.t('confirm_password'),
                  child: TextField(
                    controller: confirmation,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      hintText: context.t('auth_repeat_password'),
                    ),
                  ),
                ),
                if (!EatMeApi.development) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox.adaptive(
                        value: accepted,
                        semanticLabel: context.t('accept_terms_privacy'),
                        onChanged: (value) =>
                            setState(() => accepted = value == true),
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 3,
                          children: [
                            Text(
                              context.t('auth_accept_prefix'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            _AuthLegalLink(
                              label: context.t('auth_terms_short'),
                              url: const String.fromEnvironment('TERMS_URL'),
                            ),
                            Text(
                              context.t('auth_privacy_prefix'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            _AuthLegalLink(
                              label: context.t('auth_privacy_short'),
                              url: const String.fromEnvironment('PRIVACY_URL'),
                            ),
                          ],
                        ),
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
              const SizedBox(height: 16),
              AsyncAction(
                label: context.t(register ? 'auth_create_account' : 'login'),
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
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    context.t(
                      register ? 'auth_have_account' : 'auth_new_account',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      register = !register;
                      verificationSent = false;
                    }),
                    child: Text(
                      context.t(register ? 'login' : 'auth_register'),
                    ),
                  ),
                ],
              ),
              if (verificationSent) StatusNote(text: context.t('verify_email')),
              if (EatMeApi.development)
                StatusNote(text: context.t('development_login')),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _compactAuthTheme(ThemeData base) {
  final scheme = base.colorScheme;
  final body = TextStyle(
    fontFamily: 'EatMeSans',
    fontSize: 13,
    height: 1.35,
    color: scheme.onSurface,
  );
  final small = body.copyWith(fontSize: 11, color: scheme.onSurfaceVariant);
  final label = body.copyWith(fontSize: 13, fontWeight: FontWeight.w600);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.15,
      ),
      bodyLarge: body,
      bodyMedium: body.copyWith(fontSize: 12),
      bodySmall: small,
      labelLarge: label,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: body.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: small,
      errorStyle: small.copyWith(color: scheme.error),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        textStyle: WidgetStatePropertyAll(label),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: label.copyWith(fontSize: 11),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _AuthLegalLink extends StatelessWidget {
  const _AuthLegalLink({required this.label, required this.url});
  final String label, url;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.scheme == 'https') {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    },
    child: Text(
      label,
      style: const TextStyle(decoration: TextDecoration.underline),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(code))));
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
          constraints: const BoxConstraints(minHeight: 52),
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
                      fontFamily: 'EatMeSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
