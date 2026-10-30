import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Centralized Yazzoki design tokens.
///
/// Brand colors are theme-independent statics. Mood-dependent tokens
/// (backgrounds, surfaces, text) resolve through the currently ACTIVE
/// palette, swapped by [setActive] when the theme resolves (dark/light).
/// Widgets keep reading `AppColors.x` exactly as before — the palette swap
/// rebuilds the tree because [ThemeController] notifies the root.
class AppColors {
  AppColors._();

  // Active palette (theme-dependent). Defaults to dark.
  static YazzokiPalette _active = YazzokiPalette.dark;

  static void setActive(YazzokiPalette palette) {
    if (_active != palette) _active = palette;
  }

  /// Currently active palette (used by tests to verify theme resolution).
  static YazzokiPalette get activePalette => _active;

  // Brand accents — same across themes.
  /// Ice blue ("azul cor de gelo") — the signature Yazzoki accent.
  static const Color primaryBlue = Color(0xFF7FA9CE);
  static const Color electricBlue = Color(0xFF9DC4E4);
  /// Muted moss/jade for success states.
  static const Color success = Color(0xFF7C9A6D);
  /// Shu-iro vermillion for errors and destructive actions.
  static const Color error = Color(0xFFB4553F);
  /// Warm beige, used for borders, dividers and secondary accents.
  static const Color beige = Color(0xFFD8C6A6);

  // Theme-dependent tokens.
  static Color get absoluteBlack => _active.scaffold;
  static Color get bluishBlack => _active.surface;
  static Color get nightBlue => _active.surfaceDeep;
  static Color get deepBlue => _active.border;
  static Color get techWhite => _active.text;
  static Color get holographicBlue => _active.textMuted;
  static Color get cardSurface => _active.surface;
  static Color get scaffoldBackground => _active.scaffold;
  static Color get navBarBackground => _active.navBar;

  // Glow presets. Translucent ice blue; softer on the light theme.
  static Color get glowSmall => primaryBlue.withValues(alpha: 0.45 * _active.glowAlpha);
  static Color get glowMedium => primaryBlue.withValues(alpha: 0.55 * _active.glowAlpha);
  static Color get glowStrong => electricBlue.withValues(alpha: 0.75 * _active.glowAlpha);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, Color(0xFF4E7BA6)],
  );

  static LinearGradient get deepGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_active.surfaceDeep, _active.scaffold],
      );

  static const LinearGradient akameGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricBlue, Color(0xFFC7DDF0)],
  );
}
