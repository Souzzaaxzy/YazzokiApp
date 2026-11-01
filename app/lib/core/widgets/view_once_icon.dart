import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The VIEW-ONCE mark, DRAWN rather than taken from the icon font.
///
/// A stock Material icon would read as "one of the app's generic glyphs"; this
/// is Yazzoki's own mark and matches the app's other hand-drawn pieces
/// ([RepostIcon], [PuzzleIcon], [PlayPauseIcon]): a dashed ring (the media is
/// ephemeral) closing around a single dot (the ONE view).
class ViewOnceIcon extends StatelessWidget {
  const ViewOnceIcon({
    super.key,
    required this.color,
    this.size = 22,
    this.strokeWidth = 2,
    this.on = false,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  /// When true the mark is drawn "armed" (a closed ring, filled dot) — the
  /// toggle is ON. Off draws the same shape with the ring broken open, so the
  /// state reads at a glance without a second glyph.
  final bool on;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ViewOncePainter(
          color: color,
          strokeWidth: strokeWidth,
          on: on,
        ),
      ),
    );
  }
}

class _ViewOncePainter extends CustomPainter {
  _ViewOncePainter({
    required this.color,
    required this.strokeWidth,
    required this.on,
  });

  final Color color;
  final double strokeWidth;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - strokeWidth / 2;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // The ring: a full circle when armed, an open one (a gap) when not —
    // "protected" vs "not protected" without changing the silhouette.
    final gap = on ? 0.0 : math.pi * 0.62;
    const segments = 12;
    final step = (math.pi * 2 - gap) / segments;
    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * (step + gap / segments);
      // Dashes, not a solid ring: it reads as "temporary".
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        step * 0.62,
        false,
        stroke,
      );
    }

    // The single dot: the ONE view.
    final dot = Paint()..color = color;
    final dotR = on ? size.shortestSide * 0.17 : size.shortestSide * 0.13;
    canvas.drawCircle(c, dotR, dot);
  }

  @override
  bool shouldRepaint(_ViewOncePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.on != on;
}
