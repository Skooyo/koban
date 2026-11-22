import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The face of Mon, the coin mascot.
enum MonFace { idle, worry, happy }

/// Mon: a plain gold koban oval with dot eyes.
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
  static const _gold = Color(0xFFF2C94C);
  // The darker edge keeps the coin visible on the light theme, where gold on white is 1.5:1.
  static const _edge = Color(0xFFC99A22);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 110);

    canvas.save();
    canvas.translate(50, 56);
    canvas.rotate(-10 * math.pi / 180);
    final body = Rect.fromCenter(center: Offset.zero, width: 64, height: 92);
    canvas.drawOval(body.shift(const Offset(0, 2.5)), Paint()..color = _edge);
    canvas.drawOval(body, Paint()..color = _gold);
    canvas.restore();

    final dot = Paint()..color = _ink;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const l = 39.0, r = 61.0, y = 58.0;

    switch (face) {
      case MonFace.idle:
        canvas.drawCircle(const Offset(l, y), 3.6, dot);
        canvas.drawCircle(const Offset(r, y), 3.6, dot);
        canvas.drawLine(const Offset(46, 70), const Offset(54, 70), line);
      case MonFace.happy:
        canvas.drawPath(
          Path()
            ..moveTo(l - 5, y + 2)
            ..relativeQuadraticBezierTo(5, -7, 10, 0)
            ..moveTo(r - 5, y + 2)
            ..relativeQuadraticBezierTo(5, -7, 10, 0)
            ..moveTo(44, 68)
            ..relativeQuadraticBezierTo(6, 6, 12, 0),
          line,
        );
      case MonFace.worry:
        canvas.drawCircle(const Offset(l, y), 3.6, dot);
        canvas.drawCircle(const Offset(r, y), 3.6, dot);
        canvas.drawPath(
          Path()
            ..moveTo(l - 6, y - 6)
            ..relativeLineTo(9, -4)
            ..moveTo(r + 6, y - 6)
            ..relativeLineTo(-9, -4)
            ..moveTo(43, 71)
            ..relativeQuadraticBezierTo(2.3, -3, 4.6, 0)
            ..relativeQuadraticBezierTo(2.3, 3, 4.6, 0)
            ..relativeQuadraticBezierTo(2.3, -3, 4.6, 0),
          line,
        );
    }
  }

  @override
  bool shouldRepaint(_MonPainter old) => old.face != face;
}
