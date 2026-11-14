import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The face of Mon, the coin mascot.
enum MonFace { idle, worry, happy }

/// Mon. It draws `mon_idle.xml`, `mon_worry.xml` and `mon_happy.xml` of 0.1.1.
/// Without a [semanticLabel], screen readers skip Mon.
class Mon extends StatelessWidget {
  const Mon(this.face, {super.key, required this.size, this.semanticLabel});

  final MonFace face;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(painter: _MonPainter(face)),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(label: label, image: true, child: paint);
  }
}

class _MonPainter extends CustomPainter {
  _MonPainter(this.face);

  final MonFace face;

  static const _ink = Color(0xFF2A2106);

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 110);
    // The whole coin leans by -12 degrees around (50, 58).
    _rotated(canvas, -12, 50, 58, () {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 58), width: 68, height: 92),
        _fill(const Color(0xFFC99A22)),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 56), width: 68, height: 92),
        _fill(const Color(0xFFF2C94C)),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 56), width: 56, height: 79),
        _stroke(const Color(0xFFD9AE35), 2, cap: StrokeCap.butt),
      );

      final grooves = Path()
        ..moveTo(29, 30)
        ..relativeLineTo(42, 0)
        ..moveTo(25, 37)
        ..relativeLineTo(50, 0)
        ..moveTo(24, 79)
        ..relativeLineTo(52, 0)
        ..moveTo(27, 86)
        ..relativeLineTo(46, 0)
        ..moveTo(32, 93)
        ..relativeLineTo(36, 0);
      canvas.drawPath(grooves, _stroke(const Color(0xFFE3B93E), 1.6));

      // The shine leans by -20 degrees around its center.
      _rotated(canvas, -20, 37, 31, () {
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(37, 31), width: 14, height: 22),
          _fill(const Color(0xFFFFF3C4).withValues(alpha: 0.55)),
        );
      });

      final features = Path();
      switch (face) {
        case MonFace.idle:
          features
            ..moveTo(33, 52)
            ..relativeLineTo(12, 0)
            ..moveTo(55, 52)
            ..relativeLineTo(12, 0)
            ..moveTo(34.5, 52)
            ..relativeQuadraticBezierTo(4.5, 6, 9, 0)
            ..moveTo(56.5, 52)
            ..relativeQuadraticBezierTo(4.5, 6, 9, 0)
            ..moveTo(46, 68)
            ..relativeLineTo(8, 0);
        case MonFace.worry:
          for (final x in const [39.0, 61.0]) {
            canvas.drawOval(
              Rect.fromCenter(center: Offset(x, 53), width: 6.4, height: 6.4),
              _fill(_ink),
            );
          }
          features
            ..moveTo(33, 45.5)
            ..relativeLineTo(9, 3)
            ..moveTo(67, 45.5)
            ..relativeLineTo(-9, 3)
            ..moveTo(44, 69)
            ..relativeQuadraticBezierTo(2, -2.5, 4, 0)
            ..relativeQuadraticBezierTo(2, 2.5, 4, 0)
            ..relativeQuadraticBezierTo(2, -2.5, 4, 0);
        case MonFace.happy:
          features
            ..moveTo(34, 55)
            ..relativeQuadraticBezierTo(5, -7, 10, 0)
            ..moveTo(56, 55)
            ..relativeQuadraticBezierTo(5, -7, 10, 0)
            ..moveTo(45, 66)
            ..relativeQuadraticBezierTo(5, 5, 10, 0);
      }
      canvas.drawPath(features, _stroke(_ink, 2.6));
    });
  }

  void _rotated(
    Canvas canvas,
    double degrees,
    double px,
    double py,
    VoidCallback draw,
  ) {
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-px, -py);
    draw();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MonPainter old) => old.face != face;
}
