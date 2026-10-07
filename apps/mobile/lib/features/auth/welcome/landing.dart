import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization.dart';
import 'artwork.dart';

/// Native, theme-aware implementation of the two approved welcome mockups.
class WelcomeLanding extends StatelessWidget {
  const WelcomeLanding({
    super.key,
    required this.onStart,
    required this.onLogin,
  });

  final VoidCallback onStart;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logo = dark ? const Color(0xff9cddb2) : const Color(0xff34784f);
    final foreground = dark ? const Color(0xfff7f7f7) : const Color(0xff103323);
    final muted = dark ? const Color(0xffd2d6d5) : const Color(0xff515c59);
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: dark
            ? const Color(0xff031e12)
            : const Color(0xfffaf9f4),
      ),
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xff031e12)
            : const Color(0xfffaf9f4),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: dark
                ? const RadialGradient(
                    center: Alignment(0.1, -0.2),
                    radius: 1.2,
                    colors: [Color(0xff052415), Color(0xff031b10)],
                  )
                : null,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.clamp(0.0, 430.0);
                final scale = (width / 390).clamp(0.75, 1.1);
                final sans = TextStyle(
                  fontFamily: 'EatMeSans',
                  color: foreground,
                );
                final primaryStyle = FilledButton.styleFrom(
                  foregroundColor: const Color(0xff0f3423),
                  backgroundColor: const Color(0xffa0dfb4),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 12 * scale,
                  ),
                  minimumSize: Size.fromHeight(54 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                  textStyle: sans.copyWith(
                    fontSize: 19 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                );
                return SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: width,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                          child: Column(
                            children: [
                              SizedBox(height: 36 * scale),
                              Semantics(
                                label: context.t('eatme'),
                                image: true,
                                child: CustomPaint(
                                  key: const ValueKey('welcome-logo'),
                                  size: Size(151 * scale, 84 * scale),
                                  painter: WelcomeArtworkPainter(
                                    dark
                                        ? WelcomeArtwork.logoDark
                                        : WelcomeArtwork.logoLight,
                                    logo,
                                  ),
                                ),
                              ),
                              SizedBox(height: 49 * scale),
                              ExcludeSemantics(
                                child: CustomPaint(
                                  key: const ValueKey('welcome-ingredients'),
                                  size: Size.square(254 * scale),
                                  painter: WelcomeArtworkPainter(
                                    WelcomeArtwork.ingredients,
                                    dark ? Colors.white : const Color(0xff202020),
                                  ),
                                ),
                              ),
                              SizedBox(height: 29 * scale),
                              Text.rich(
                                TextSpan(
                                  text: '${context.t('welcome_more_taste')}\n',
                                  children: [
                                    TextSpan(
                                      text: context.t('welcome_less_waste'),
                                      style: TextStyle(color: logo),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: sans.copyWith(
                                  fontSize: 33 * scale,
                                  fontWeight: FontWeight.w700,
                                  height: 1.09,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              SizedBox(height: 15 * scale),
                              Text(
                                context.t('welcome_personal_recipes'),
                                textAlign: TextAlign.center,
                                style: sans.copyWith(
                                  fontSize: 17 * scale,
                                  height: 1.26,
                                  color: muted,
                                ),
                              ),
                              SizedBox(height: 32 * scale),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  key: const ValueKey('welcome-start'),
                                  style: primaryStyle,
                                  onPressed: onStart,
                                  child: Row(
                                    children: [
                                      SizedBox(width: 24 * scale),
                                      Expanded(
                                        child: Text(
                                          context.t('start_now'),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      ExcludeSemantics(
                                        child: Icon(
                                          Icons.arrow_forward,
                                          size: 24 * scale,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 11 * scale),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  key: const ValueKey('welcome-login'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: logo,
                                    backgroundColor: Colors.transparent,
                                    minimumSize: Size.fromHeight(47 * scale),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16 * scale,
                                      vertical: 12 * scale,
                                    ),
                                    side: BorderSide(color: logo),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        16 * scale,
                                      ),
                                    ),
                                    textStyle: sans.copyWith(
                                      fontSize: 17 * scale,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: onLogin,
                                  child: Text(
                                    context.t('already_account'),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              SizedBox(height: 40 * scale),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
