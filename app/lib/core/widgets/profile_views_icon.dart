import 'package:flutter/material.dart';

/// "Visualizações do perfil" icon — TWO chevrons (a "double step") drawn with
/// [CustomPaint].
///
/// Why a painter and not a Material glyph: the requested mark is the
/// two-arrow "see more" symbol, and drawing it keeps the exact silhouette,
/// the theme colour and a constant size (the button never shifts). It reads
/// as "someone stepped through your profile".
class ProfileViewsIcon extends StatelessWidget {
  const ProfileViewsIcon({
    super.key,
    required this.color,
    this.size = 22,
    this.strokeWidth = 1.9,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProfileViewsPainter(color: color, strokeWidth: strokeWidth),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ProfileViewsPainter extends CustomPainter {
  _ProfileViewsPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = strokeWidth * (w / 22);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Two chevrons "»", one behind the other (the double-step).
    final head = w * 0.26;
    for (var i = 0; i < 2; i++) {
      final x = w * (0.22 + i * 0.34);
      final path = Path()
        ..moveTo(x, h * 0.22)
        ..lineTo(x + head, h * 0.5)
        ..lineTo(x, h * 0.78);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileViewsPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
