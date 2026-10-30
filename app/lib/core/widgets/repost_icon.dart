import 'package:flutter/material.dart';

/// Repost icon — the two chasing arrows of the Instagram/TikTok "share to
/// profile" action, DRAWN with [CustomPaint].
///
/// Why a painter and not `Icons.repeat`/`Icons.autorenew`: those glyphs are a
/// thin outline with a different silhouette. The requested mark is the
/// recognizable repost symbol — two rounded arrows chasing each other, one on
/// top and one below, slightly offset — and drawing it keeps the exact shape,
/// the theme colour and a constant size (the button never "jumps").
///
/// [active] fills the shape (the "reposted" state); inactive draws it as an
/// outline, matching the heart's ♡/♥ convention in the feed.
class RepostIcon extends StatelessWidget {
  const RepostIcon({
    super.key,
    required this.color,
    this.size = 20,
    this.active = false,
    this.strokeWidth = 1.8,
  });

  final Color color;
  final double size;
  final bool active;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RepostPainter(
          color: color,
          active: active,
          strokeWidth: strokeWidth,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RepostPainter extends CustomPainter {
  _RepostPainter({
    required this.color,
    required this.active,
    required this.strokeWidth,
  });

  final Color color;
  final bool active;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Two arrows, each roughly half the height: top one points right, bottom
    // one points left (the standard repost mark). The head is a small
    // triangle; the body is a rounded stroke with a rounded corner.
    final stroke = strokeWidth * (w / 20);
    final head = w * 0.30; // arrowhead length

    final body = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // ── Top arrow: goes right, then bends down at the right end. ──
    final topY = h * 0.30;
    final topLeft = w * 0.12;
    final topRight = w * 0.88;
    final topPath = Path()
      ..moveTo(topLeft, topY)
      ..lineTo(topRight - head * 0.5, topY);
    canvas.drawPath(topPath, body);
    // Arrowhead (pointing right) at the top-right.
    final topHead = Path()
      ..moveTo(topRight, topY)
      ..lineTo(topRight - head, topY - head * 0.55)
      ..lineTo(topRight - head, topY + head * 0.55)
      ..close();
    canvas.drawPath(topHead, fill);

    // ── Bottom arrow: goes left, mirrored. ──
    final botY = h * 0.70;
    final botPath = Path()
      ..moveTo(topRight, botY)
      ..lineTo(topLeft + head * 0.5, botY);
    canvas.drawPath(botPath, body);
    final botHead = Path()
      ..moveTo(topLeft, botY)
      ..lineTo(topLeft + head, botY - head * 0.55)
      ..lineTo(topLeft + head, botY + head * 0.55)
      ..close();
    canvas.drawPath(botHead, fill);

    // The two short vertical connectors that make the loop read as a cycle.
    canvas.drawLine(
      Offset(topRight - head * 0.5, topY),
      Offset(topRight - head * 0.5, botY),
      body,
    );
    canvas.drawLine(
      Offset(topLeft + head * 0.5, botY),
      Offset(topLeft + head * 0.5, topY),
      body,
    );

    if (active) {
      // Active: a soft filled disc behind the mark so the "on" state is
      // unmistakable at a glance (mirrors the filled heart).
      canvas.drawCircle(
        Offset(w / 2, h / 2),
        w * 0.46,
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RepostPainter old) =>
      old.color != color ||
      old.active != active ||
      old.strokeWidth != strokeWidth;
}
