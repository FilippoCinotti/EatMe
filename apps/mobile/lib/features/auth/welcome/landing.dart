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
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: arrow
          ? CustomPaint(
              painter: _PrimaryActionPainter(
                label: label,
                foreground: foreground,
                background: background,
                scale: scale,
              ),
              child: SizedBox(height: 54 * scale),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: border == null ? null : Border.all(color: border!),
                borderRadius: BorderRadius.circular(16 * scale),
              ),
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
                      SizedBox(width: 24 * scale),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

class _PrimaryActionPainter extends CustomPainter {
  const _PrimaryActionPainter({
    required this.label,
    required this.foreground,
    required this.background,
    required this.scale,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(16 * scale)),
      Paint()..color = background,
    );
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'EatMeSans',
          color: foreground,
          fontSize: 19 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - 96 * scale);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );

    final paint = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arrowSize = 24 * scale;
    canvas.save();
    canvas.translate(size.width - 40 * scale, (size.height - arrowSize) / 2);
    final path = Path()
      ..moveTo(arrowSize * .12, arrowSize * .5)
      ..lineTo(arrowSize * .86, arrowSize * .5)
      ..moveTo(arrowSize * .58, arrowSize * .22)
      ..lineTo(arrowSize * .86, arrowSize * .5)
      ..lineTo(arrowSize * .58, arrowSize * .78);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PrimaryActionPainter oldDelegate) =>
      label != oldDelegate.label ||
      foreground != oldDelegate.foreground ||
      background != oldDelegate.background ||
      scale != oldDelegate.scale;
}
