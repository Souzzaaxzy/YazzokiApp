import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Centralized Yazzoki design tokens.
///
/// EVERY mood-dependent token resolves through the currently ACTIVE palette,
/// which is swapped by [setActive] when the theme + brightness resolve. That
/// is what lets the whole app (and a visitor viewing someone else's profile)
/// re-skin without touching a single widget.
///
/// [error] and [success] are deliberately FIXED across themes: semantic colour
/// must not change meaning with decoration (a "success" that turns green in
/// one theme and red in another is a bug, not a feature).
class AppColors {
  AppColors._();

  // Active palette. Defaults to the catalog's first theme (dark half) so a
  // widget built before the controller resolves still has sane colours.
  static YazzokiPalette _active = yazzokiThemes.first.dark;

  static void setActive(YazzokiPalette palette) {
    _active = palette;
  }

  /// Currently active palette (used by tests to verify theme resolution).
  static YazzokiPalette get activePalette => _active;

  // ── Semantic colours: FIXED, never themed. ──
  static const Color success = Color(0xFF7C9A6D);
  static const Color error = Color(0xFFC0392B);

  // ── Theme-dependent tokens ──
  static Color get absoluteBlack => _active.scaffold;
  static Color get bluishBlack => _active.surface;
  static Color get nightBlue => _active.surfaceDeep;
  static Color get deepBlue => _active.border;
  static Color get techWhite => _active.text;
  static Color get holographicBlue => _active.textMuted;
  static Color get cardSurface => _active.surface;
  static Color get scaffoldBackground => _active.scaffold;
  static Color get navBarBackground => _active.navBar;

  /// Primary accent — used for FILLS (buttons, badges, selected chips).
  static Color get primaryBlue => _active.accent;

  /// Secondary accent — the softer/lighter end of the same accent family.
  static Color get electricBlue => _active.accentInk;

  /// The accent as TEXT/icon over a surface (contrast-safe variant).
  static Color get accentInk => _active.accentInk;

  /// Fill of the outgoing chat bubble (white text always clears 4.5:1).
  static Color get bubbleOut => _active.bubble;

  // Glow presets: the theme's own glow colour, so it never fights the accent.
  static Color get glowSmall =>
      _active.glow.withValues(alpha: 0.40 * _active.glowAlpha);
  static Color get glowMedium =>
      _active.glow.withValues(alpha: 0.50 * _active.glowAlpha);
  static Color get glowStrong =>
      _active.glow.withValues(alpha: 0.70 * _active.glowAlpha);

  // Gradients (derived from the active accent so they follow the theme).
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _active.accent,
          Color.lerp(_active.accent, const Color(0xFF000000), 0.35)!,
        ],
      );

  static LinearGradient get deepGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_active.surfaceDeep, _active.scaffold],
      );

  static LinearGradient get akameGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _active.accentInk,
          Color.lerp(_active.accentInk, const Color(0xFFFFFFFF), 0.35)!,
        ],
      );
}
