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
    final overlay = dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
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
                                    dark
                                        ? Colors.white
                                        : const Color(0xff202020),
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
                                child: _WelcomeAction(
                                  key: const ValueKey('welcome-start'),
                                  onPressed: onStart,
                                  label: context.t('start_now'),
                                  scale: scale,
                                  foreground: const Color(0xff0f3423),
                                  background: const Color(0xffa0dfb4),
                                  arrow: true,
                                ),
                              ),
                              SizedBox(height: 11 * scale),
                              SizedBox(
                                width: double.infinity,
                                child: _WelcomeAction(
                                  key: const ValueKey('welcome-login'),
                                  onPressed: onLogin,
                                  label: context.t('already_account'),
                                  scale: scale,
                                  foreground: logo,
                                  border: logo,
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

class _WelcomeAction extends StatelessWidget {
  const _WelcomeAction({
    super.key,
    required this.onPressed,
    required this.label,
    required this.scale,
    required this.foreground,
    this.background = Colors.transparent,
    this.border,
    this.arrow = false,
  });

  final VoidCallback onPressed;
  final String label;
  final double scale;
  final Color foreground;
  final Color background;
  final Color? border;
  final bool arrow;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * scale),
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: (arrow ? 54 : 47) * scale,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            child: Row(
              children: [
                SizedBox(width: 24 * scale),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'EatMeSans',
                      color: foreground,
                      fontSize: (arrow ? 19 : 17) * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 24 * scale,
                  height: 24 * scale,
                  child: arrow
                      ? CustomPaint(painter: _ArrowPainter(foreground))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .5)
      ..lineTo(size.width * .86, size.height * .5)
      ..moveTo(size.width * .58, size.height * .22)
      ..lineTo(size.width * .86, size.height * .5)
      ..lineTo(size.width * .58, size.height * .78);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => color != oldDelegate.color;
}
