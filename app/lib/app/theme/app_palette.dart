import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/theme_controller.dart';

/// Resolves which palette is ACTIVE for a theme + brightness preference.
///
/// Pure function so the resolution rule stays unit-testable. `platform` is
/// the VIEWER's brightness: when showing ANOTHER user's profile theme, the
/// light/dark half is always the viewer's choice — never the profile owner's
/// (that would flash a light screen at someone using dark).
YazzokiPalette effectivePalette(
  String themeId,
  YazzokiThemeMode mode,
  Brightness platform,
) {
  final theme = themeById(themeId);
  final wantDark = switch (mode) {
    YazzokiThemeMode.dark => true,
    YazzokiThemeMode.light => false,
    YazzokiThemeMode.system => platform == Brightness.dark,
  };
  return wantDark ? theme.dark : theme.light;
}

/// One selectable theme: a stable id (used as the server `themeId`), a label
/// and its two brightness variants.
class YazzokiTheme {
  const YazzokiTheme({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.light,
    required this.dark,
  });

  /// Stable slug persisted locally AND sent to the server (`washi`).
  final String id;
  final String label;
  final String subtitle;
  final YazzokiPalette light;
  final YazzokiPalette dark;
}

/// Per-theme color tokens. Everything colour-related the UI reads comes from
/// here, so adding a theme is adding ONE entry to [yazzokiThemes].
class YazzokiPalette {
  const YazzokiPalette({
    required this.scaffold,
    required this.surface,
    required this.surfaceDeep,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.navBar,
    required this.accent,
    required this.accentInk,
    required this.bubble,
    required this.glow,
    required this.glowAlpha,
  });

  final Color scaffold;
  final Color surface;
  final Color surfaceDeep;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color navBar;

  /// Fills (buttons, badges, selected chips).
  final Color accent;

  /// The accent as TEXT/icon over the surface. Kept separate from [accent]
  /// on purpose: a mid-tone accent used as small text falls below 4.5:1.
  final Color accentInk;

  /// Fill of the OUTGOING chat bubble. Darkened so white text on it always
  /// clears 4.5:1 — never the raw accent.
  final Color bubble;

  /// Colour of the neon glow, so it never fights a theme's accent.
  final Color glow;

  /// Alpha multiplier for the glow: strong on dark, subtle on light.
  final double glowAlpha;
}

/// ── contrast helpers (keep the catalog honest) ──────────────────

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

/// Relative luminance (WCAG). `Color.r/g/b` are 0..1 in this Flutter, so the
/// channels feed the formula directly.
double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG contrast ratio between two colours (1..21).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Darkens [accent] until white text on it reaches [min] contrast.
Color bubbleFor(Color accent, {double min = 4.5}) {
  var r = accent.r;
  var g = accent.g;
  var b = accent.b;
  for (var i = 0; i < 80; i++) {
    final c = Color.from(alpha: 1, red: r, green: g, blue: b);
    if (contrastRatio(const Color(0xFFFFFFFF), c) >= min) return c;
    r *= 0.94;
    g *= 0.94;
    b *= 0.94;
  }
  return const Color(0xFF000000);
}

/// The 10 selectable themes, in catalog order.
const List<YazzokiTheme> yazzokiThemes = [
  YazzokiTheme(
    id: 'washi',
    label: 'Washi',
    subtitle: 'papel de arroz · azul gelo',
    light: YazzokiPalette(
      scaffold: Color(0xFFF5F1E8),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFEAE3D5),
      border: Color(0xFFD3BF9C),
      text: Color(0xFF14120E),
      textMuted: Color(0xFF6B6152),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFF5B8FC7),
      accentInk: Color(0xFF3A6797),
      bubble: Color(0xFF4A75A4),
      glow: Color(0xFF5B8FC7),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0F0D0A),
      surface: Color(0xFF1B1813),
      surfaceDeep: Color(0xFF141109),
      border: Color(0xFF3A3226),
      text: Color(0xFFFBF8F1),
      textMuted: Color(0xFFCDB68D),
      navBar: Color(0xF20A0908),
      accent: Color(0xFF8FBCE4),
      accentInk: Color(0xFF9DC4E4),
      bubble: Color(0xFF597791),
      glow: Color(0xFF8FBCE4),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'sumi',
    label: 'Sumi',
    subtitle: 'tinta · selo vermelho',
    light: YazzokiPalette(
      scaffold: Color(0xFFFAFAF8),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFEDEDEA),
      border: Color(0xFFDADAD4),
      text: Color(0xFF0A0A0A),
      textMuted: Color(0xFF6A6A66),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFFB42D24),
      accentInk: Color(0xFF9E261E),
      bubble: Color(0xFFB42D24),
      glow: Color(0xFFB42D24),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0A0A0A),
      surface: Color(0xFF161616),
      surfaceDeep: Color(0xFF101010),
      border: Color(0xFF333330),
      text: Color(0xFFF5F5F3),
      textMuted: Color(0xFF9A9A94),
      navBar: Color(0xF20A0A0A),
      accent: Color(0xFFE04B3E),
      accentInk: Color(0xFFE86458),
      bubble: Color(0xFFC54136),
      glow: Color(0xFFE04B3E),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'sakura',
    label: 'Sakura',
    subtitle: 'rosa antigo',
    light: YazzokiPalette(
      scaffold: Color(0xFFFAF3F4),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFF3E7EB),
      border: Color(0xFFE4CDD6),
      text: Color(0xFF2E1E24),
      textMuted: Color(0xFF82666F),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFFC66C88),
      accentInk: Color(0xFFA34866),
      bubble: Color(0xFFA3586F),
      glow: Color(0xFFC66C88),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF140E14),
      surface: Color(0xFF201720),
      surfaceDeep: Color(0xFF1A121A),
      border: Color(0xFF3E2C38),
      text: Color(0xFFF5EBF0),
      textMuted: Color(0xFFA88E9C),
      navBar: Color(0xF2140E14),
      accent: Color(0xFFE08CAA),
      accentInk: Color(0xFFE89EBA),
      bubble: Color(0xFF985E73),
      glow: Color(0xFFE08CAA),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'matcha',
    label: 'Matcha',
    subtitle: 'chá verde',
    light: YazzokiPalette(
      scaffold: Color(0xFFF4F4EC),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFE8E9DC),
      border: Color(0xFFCFD3BC),
      text: Color(0xFF14170F),
      textMuted: Color(0xFF6A7059),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFF6E8F5A),
      accentInk: Color(0xFF4E6B3E),
      bubble: Color(0xFF607D4E),
      glow: Color(0xFF6E8F5A),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0C0F0A),
      surface: Color(0xFF171B13),
      surfaceDeep: Color(0xFF11150E),
      border: Color(0xFF2F3626),
      text: Color(0xFFEEF2E6),
      textMuted: Color(0xFFA8B394),
      navBar: Color(0xF20C0F0A),
      accent: Color(0xFF9CC47E),
      accentInk: Color(0xFFAECF93),
      bubble: Color(0xFF627C4E),
      glow: Color(0xFF9CC47E),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'hinoki',
    label: 'Hinoki',
    subtitle: 'cedro · âmbar',
    light: YazzokiPalette(
      scaffold: Color(0xFFF8F3EC),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFF0E7DA),
      border: Color(0xFFDCC9AE),
      text: Color(0xFF1A140E),
      textMuted: Color(0xFF7A6A55),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFFB5713A),
      accentInk: Color(0xFF8F5729),
      bubble: Color(0xFF9F6332),
      glow: Color(0xFFB5713A),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0F0B07),
      surface: Color(0xFF1A140E),
      surfaceDeep: Color(0xFF14100A),
      border: Color(0xFF3A2C1C),
      text: Color(0xFFF6EFE6),
      textMuted: Color(0xFFBFA98C),
      navBar: Color(0xF20F0B07),
      accent: Color(0xFFD99155),
      accentInk: Color(0xFFE2A268),
      bubble: Color(0xFF9C683C),
      glow: Color(0xFFD99155),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'kogane',
    label: 'Kogane',
    subtitle: 'laca · ouro',
    light: YazzokiPalette(
      scaffold: Color(0xFFFBF8F1),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFF3EDDD),
      border: Color(0xFFDFCFA8),
      text: Color(0xFF14110B),
      textMuted: Color(0xFF776B4E),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFFA8862E),
      accentInk: Color(0xFF85691F),
      bubble: Color(0xFF8A6D25),
      glow: Color(0xFFA8862E),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0B0906),
      surface: Color(0xFF17130C),
      surfaceDeep: Color(0xFF12100A),
      border: Color(0xFF3A2F1A),
      text: Color(0xFFF7F2E4),
      textMuted: Color(0xFFC0AF8A),
      navBar: Color(0xF20B0906),
      accent: Color(0xFFD9B44A),
      accentInk: Color(0xFFE2C266),
      bubble: Color(0xFF89722D),
      glow: Color(0xFFD9B44A),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'ai',
    label: 'Ai',
    subtitle: 'aizome · índigo',
    light: YazzokiPalette(
      scaffold: Color(0xFFF1F3F7),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFE4E9F1),
      border: Color(0xFFC3CEDF),
      text: Color(0xFF0C1220),
      textMuted: Color(0xFF5A6579),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFF2E5B9E),
      accentInk: Color(0xFF234A85),
      bubble: Color(0xFF2E5B9E),
      glow: Color(0xFF2E5B9E),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF080C16),
      surface: Color(0xFF111827),
      surfaceDeep: Color(0xFF0C1220),
      border: Color(0xFF253150),
      text: Color(0xFFE4EAF6),
      textMuted: Color(0xFF93A2BE),
      navBar: Color(0xF2080C16),
      accent: Color(0xFF6E9AD9),
      accentInk: Color(0xFF82A9E2),
      bubble: Color(0xFF5476A7),
      glow: Color(0xFF6E9AD9),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'yuki',
    label: 'Yuki',
    subtitle: 'neve · gelo',
    light: YazzokiPalette(
      scaffold: Color(0xFFF4F7FA),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFE8EFF5),
      border: Color(0xFFC6D6E4),
      text: Color(0xFF0E141B),
      textMuted: Color(0xFF5E6E7E),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFF3E8FB0),
      accentInk: Color(0xFF2E7490),
      bubble: Color(0xFF367D9B),
      glow: Color(0xFF3E8FB0),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0B1018),
      surface: Color(0xFF161E29),
      surfaceDeep: Color(0xFF0F1620),
      border: Color(0xFF2B3A4D),
      text: Color(0xFFE9F2FA),
      textMuted: Color(0xFF9BB0C4),
      navBar: Color(0xF20B1018),
      accent: Color(0xFF7DD3E8),
      accentInk: Color(0xFF92DCEF),
      bubble: Color(0xFF497D8A),
      glow: Color(0xFF7DD3E8),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'tsuki',
    label: 'Tsuki',
    subtitle: 'lua · prata',
    light: YazzokiPalette(
      scaffold: Color(0xFFF2F3F8),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFE6E8F2),
      border: Color(0xFFC9CDDF),
      text: Color(0xFF12141F),
      textMuted: Color(0xFF5F6478),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFF6E7BC4),
      accentInk: Color(0xFF5560A8),
      bubble: Color(0xFF606CAC),
      glow: Color(0xFF6E7BC4),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF090D1A),
      surface: Color(0xFF131928),
      surfaceDeep: Color(0xFF0D1222),
      border: Color(0xFF2A3450),
      text: Color(0xFFE2E8F8),
      textMuted: Color(0xFF97A2C0),
      navBar: Color(0xF2090D1A),
      accent: Color(0xFFA8B4E8),
      accentInk: Color(0xFFBCC6F0),
      bubble: Color(0xFF6A7293),
      glow: Color(0xFFA8B4E8),
      glowAlpha: 1.0,
    ),
  ),
  YazzokiTheme(
    id: 'fuji',
    label: 'Fuji',
    subtitle: 'glicínia',
    light: YazzokiPalette(
      scaffold: Color(0xFFF6F3FA),
      surface: Color(0xFFFFFFFF),
      surfaceDeep: Color(0xFFECE6F5),
      border: Color(0xFFD2C7E4),
      text: Color(0xFF16121E),
      textMuted: Color(0xFF6B5F80),
      navBar: Color(0xF2FFFFFF),
      accent: Color(0xFF7B68B8),
      accentInk: Color(0xFF63509E),
      bubble: Color(0xFF7B68B8),
      glow: Color(0xFF7B68B8),
      glowAlpha: 0.2,
    ),
    dark: YazzokiPalette(
      scaffold: Color(0xFF0D0A14),
      surface: Color(0xFF171320),
      surfaceDeep: Color(0xFF120E1A),
      border: Color(0xFF322842),
      text: Color(0xFFEDE8F6),
      textMuted: Color(0xFFA79BBA),
      navBar: Color(0xF20D0A14),
      accent: Color(0xFFA894E0),
      accentInk: Color(0xFFB8A6E8),
      bubble: Color(0xFF796BA2),
      glow: Color(0xFFA894E0),
      glowAlpha: 1.0,
    ),
  ),
];

/// Default theme id (the classic Yazzoki look).
const String kDefaultThemeId = 'washi';

/// Resolves a theme by id, falling back to the default for an unknown id
/// (a retired theme must never break the UI).
YazzokiTheme themeById(String? id) {
  if (id == null || id.isEmpty) return yazzokiThemes.first;
  for (final t in yazzokiThemes) {
    if (t.id == id) return t;
  }
  return yazzokiThemes.first;
}

/// Whether [id] is a selectable theme (used to validate the server value).
bool isValidThemeId(String? id) {
  if (id == null) return false;
  for (final t in yazzokiThemes) {
    if (t.id == id) return true;
  }
  return false;
}
