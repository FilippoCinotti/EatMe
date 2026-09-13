import 'package:flutter/material.dart';

/// EatMe's original two-leaf mark. The same geometry is kept in the bundled
/// SVG source so the brand can be reused outside Flutter without rasterizing.
class EatMeBrandMark extends StatelessWidget {
  const EatMeBrandMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _EatMeBrandPainter(
        color ?? Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _EatMeBrandPainter extends CustomPainter {
  const _EatMeBrandPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()..color = color;
    final mainLeaf = Path()
      ..moveTo(2.2, 15.2)
      ..cubicTo(2.9, 7.4, 9.1, 2.1, 18.4, 1.2)
      ..cubicTo(18.1, 9.8, 13.2, 16.2, 6.3, 18.2)
      ..cubicTo(4.1, 18.8, 2.0, 17.4, 2.2, 15.2)
      ..close();
    final smallLeaf = Path()
      ..moveTo(13.7, 17.2)
      ..cubicTo(14.3, 11.8, 18.0, 8.5, 23.0, 8.2)
      ..cubicTo(22.7, 13.8, 19.5, 17.3, 14.2, 18.5)
      ..close();
    canvas.drawPath(mainLeaf, paint);
    canvas.drawPath(smallLeaf, paint);
    canvas.drawPath(
      Path()
        ..moveTo(4.7, 18.8)
        ..cubicTo(8.0, 14.6, 11.5, 10.6, 16.7, 5.6),
      Paint()
        ..color = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white.withValues(alpha: .48)
            : Colors.black.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EatMeBrandPainter oldDelegate) =>
      oldDelegate.color != color;
}
