import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../app/theme/app_colors.dart';
import '../services/theme_controller.dart';

/// Scatters the ACTIVE theme's motif icon over a background.
///
/// The icon is small, evenly spaced and repeated across the whole surface — a
/// decorative pattern, not a single centred watermark. The grid is regular
/// (the same spacing everywhere, like a stencil) with a small deterministic
/// jitter and rotation per cell, so it reads as printed paper rather than a
/// spreadsheet.
///
/// It is purely decorative: it never takes a tap. It listens to
/// [ThemeController], so switching the theme or the brightness re-tints it in
/// place, and [ThemeController.showIcons] turns it off entirely (colours only).
class ThemePatternBackground extends StatefulWidget {
  const ThemePatternBackground({
    super.key,
    this.cellSize = 96,
    this.opacity = 0.20,
    this.rotation = 0.35,
    this.controller,
  });

  /// Target spacing between icons, in logical pixels.
  final double cellSize;

  /// Peak opacity of an icon. Kept low: this sits under real content.
  final double opacity;

  /// Maximum rotation applied to an icon, in radians.
  final double rotation;

  /// Theme source. Defaults to the global [ThemeController.instance]; tests
  /// inject their own so they never touch secure storage.
  final ThemeController? controller;

  @override
  State<ThemePatternBackground> createState() => _ThemePatternBackgroundState();
}

class _ThemePatternBackgroundState extends State<ThemePatternBackground> {
  /// Decoded icons, keyed by theme id. Decoding is async, so the first frame
  /// of a theme paints nothing and the next one paints the pattern — cheaper
  /// than blocking the first build.
  static final Map<String, ui.Image> _cache = {};

  ui.Image? _icon;
  String? _themeId;

  ThemeController get _controller =>
      widget.controller ?? ThemeController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onThemeChanged);
    _sync();
  }

  @override
  void dispose() {
    _controller.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    if (_controller.themeId != _themeId) _sync();
    setState(() {}); // showIcons / brightness may have changed
  }

  void _sync() {
    final id = _controller.themeId;
    _themeId = id;
    final cached = _cache[id];
    if (cached != null) {
      _icon = cached;
      return;
    }
    _icon = null;
    _load(id);
  }

  Future<void> _load(String id) async {
    final data = await rootBundle.load(themeIconAsset(id));
    final image = await decodeImageFromList(data.buffer.asUint8List());
    _cache[id] = image;
    if (!mounted || _themeId != id) return;
    setState(() => _icon = image);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    // The IgnorePointer wrapper is ALWAYS present, even before the icon has
    // decoded: "this layer never takes a tap" has to hold at every moment,
    // not only once the async decode lands. (It also keeps the widget tree
    // stable across the load, instead of swapping the whole subtree.)
    final ready = icon != null && _controller.showIcons;
    return IgnorePointer(
      child: ready
          ? CustomPaint(
              painter: _ThemePatternPainter(
                icon: icon,
                colour: AppColors.electricBlue,
                cellSize: widget.cellSize,
                opacity: widget.opacity,
                rotation: widget.rotation,
              ),
              size: Size.infinite,
            )
          : const SizedBox.expand(),
    );
  }
}

class _ThemePatternPainter extends CustomPainter {
  _ThemePatternPainter({
    required this.icon,
    required this.colour,
    required this.cellSize,
    required this.opacity,
    required this.rotation,
  });

  final ui.Image icon;
  final Color colour;
  final double cellSize;
  final double opacity;
  final double rotation;

  /// Deterministic pseudo-random in [0,1) from a cell index. The pattern must
  /// be stable across repaints — a real RNG would make it crawl every frame.
  double _noise(int n) {
    final x = math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || cellSize <= 0) return;

    // Widen the cell so a whole number of columns fits the width: no
    // half-icon slivers at the right edge.
    final cols = math.max(1, (size.width / cellSize).round());
    final cell = size.width / cols;
    final rows = (size.height / cell).ceil() + 1;

    final src =
        Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        // Offset every other row by half a cell: a brick pattern reads as
        // texture, a plain grid reads as a table.
        final cx = c * cell +
            (r.isOdd ? cell * 0.5 : 0) +
            (_noise(idx) - 0.5) * cell * 0.22;
        final cy = r * cell + (_noise(idx + 977) - 0.5) * cell * 0.22;
        final side = cell * (0.58 + _noise(idx + 613) * 0.22);

        paint.color = colour
            .withValues(alpha: opacity * (0.62 + _noise(idx + 421) * 0.38));
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate((_noise(idx + 313) - 0.5) * 2 * rotation);
        canvas.drawImageRect(
          icon,
          src,
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ThemePatternPainter old) =>
      old.icon != icon ||
      old.colour != colour ||
      old.cellSize != cellSize ||
      old.opacity != opacity ||
      old.rotation != rotation;
}

/// The motif icon asset for a theme id.
String themeIconAsset(String themeId) => 'assets/icons/theme_$themeId.png';
