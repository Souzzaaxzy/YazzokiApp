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
    scaffold: Color(0xFF000000),
    surface: Color(0xFF0C0B09),
    surfaceDeep: Color(0xFF17140F),
    border: Color(0xFF3E362A),
    text: Color(0xFFFBF8F1),
    textMuted: Color(0xFFCDB68D),
    navBar: Color(0xF20A0908),
    glowAlpha: 1.0,
  );

  static const light = YazzokiPalette(
    scaffold: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceDeep: Color(0xFFF1ECE0),
    border: Color(0xFFD3BF9C),
    text: Color(0xFF0A0908),
    textMuted: Color(0xFF554D3D),
    navBar: Color(0xF2FFFFFF),
    glowAlpha: 0.2,
  );
}
