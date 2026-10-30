import 'package:flutter/material.dart';

import '../../core/services/theme_controller.dart';

/// Resolves which palette is ACTIVE for a given preference + platform
/// brightness. Pure function so the resolution rule is unit-testable.
YazzokiPalette effectivePalette(YazzokiThemeMode mode, Brightness platform) {
  return switch (mode) {
    YazzokiThemeMode.dark => YazzokiPalette.dark,
    YazzokiThemeMode.light => YazzokiPalette.light,
    YazzokiThemeMode.system =>
      platform == Brightness.dark ? YazzokiPalette.dark : YazzokiPalette.light,
  };
}

/// Per-theme color tokens for the mood-dependent part of the Yazzoki
/// identity (brand accents are shared and stay in [AppColors]).
///
/// `dark` is the classic look: ink-black night paper, off-white ink text and
/// a cold ice-blue accent. `light` is the day variant — warm off-white
/// (washi) paper, ink-black text, beige borders and the same ice-blue accent,
/// with borders/shadows tuned for a bright background (not an inversion).
class YazzokiPalette {
  const YazzokiPalette({
    required this.scaffold,
    required this.surface,
    required this.surfaceDeep,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.navBar,
    required this.glowAlpha,
  });

  final Color scaffold;
  final Color surface;
  final Color surfaceDeep;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color navBar;

  /// Alpha of the glow emphasis: strong on dark, subtle on light.
  final double glowAlpha;

  static const dark = YazzokiPalette(
    scaffold: Color(0xFF12100C),
    surface: Color(0xFF1B1813),
    surfaceDeep: Color(0xFF241F18),
    border: Color(0xFF3A3226),
    text: Color(0xFFF4EFE6),
    textMuted: Color(0xFFC9B48C),
    navBar: Color(0xF21B1813),
    glowAlpha: 1.0,
  );

  static const light = YazzokiPalette(
    scaffold: Color(0xFFF5F1E8),
    surface: Color(0xFFFFFFFF),
    surfaceDeep: Color(0xFFEAE3D5),
    border: Color(0xFFD8C6A6),
    text: Color(0xFF14120E),
    textMuted: Color(0xFF6B6152),
    navBar: Color(0xF2FFFFFF),
    glowAlpha: 0.2,
  );
}
