import 'package:flutter/material.dart';

/// Grid icon — the "posts" tab mark: four rounded squares, DRAWN with
/// [CustomPaint].
///
/// Why a painter and not `Icons.grid_view_rounded`: the request is a clean,
/// monochrome mark that follows the tab's active/inactive colour exactly and
/// never depends on the icon set (or risks a colourful system emoji). The
/// size is fixed, so switching tabs never shifts the layout.
class GridIcon extends StatelessWidget {
  const GridIcon({
    super.key,
    required this.color,
    this.size = 20,
    this.strokeWidth = 1.6,
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
        painter: _GridPainter(color: color, strokeWidth: strokeWidth),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = strokeWidth * (w / 20);
    final gap = w * 0.14;
    final cell = (w - gap) / 2 - stroke / 2;
    final radius = Radius.circular(cell * 0.28);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    // Four equal rounded squares (2×2), inset by half the stroke so the
    // outline never clips at the edges.
    final inset = stroke / 2;
    final left = inset;
    final top = inset;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final rect = Rect.fromLTWH(
          left + col * (cell + gap),
          top + row * (cell + gap),
          cell,
          cell,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
