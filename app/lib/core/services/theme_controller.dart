import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../data/theme_store.dart';

/// User-selectable brightness preference ("dark/light/system").
enum YazzokiThemeMode { dark, light, system }

/// Global theme controller: holds the user's THEME (catalog id), their
/// brightness preference and whether that theme is applied to their PUBLIC
/// profile; persists them via [ThemeStore] and notifies the root app.
///
/// `system` follows platform brightness changes (a [WidgetsBindingObserver]
/// emits [notifyListeners] when Android flips dark/light), so the app
/// re-resolves and follows the phone.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._({ThemeStore? store}) : _store = store ?? ThemeStore() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final ThemeController instance = ThemeController._();

  /// Test-only entry point with an injectable (in-memory) store.
  @visibleForTesting
  factory ThemeController.debug(ThemeStore store) =>
      ThemeController._(store: store);

  final ThemeStore _store;

  String _themeId = kDefaultThemeId;
  YazzokiThemeMode _mode = YazzokiThemeMode.dark;
  bool _applyToProfile = false;
  bool _showIcons = true;

  /// The selected catalog theme id (see [yazzokiThemes]).
  String get themeId => _themeId;

  /// The resolved theme object for the current id.
  YazzokiTheme get theme => themeById(_themeId);

  YazzokiThemeMode get mode => _mode;

  /// Whether the chosen theme is also shown to OTHER users on the profile.
  bool get applyToProfile => _applyToProfile;

  /// Whether the theme's motif icons are scattered over the background.
  /// OFF keeps the colours only (a flat, plain surface).
  bool get showIcons => _showIcons;

  ThemeMode get materialMode => switch (_mode) {
        YazzokiThemeMode.dark => ThemeMode.dark,
        YazzokiThemeMode.light => ThemeMode.light,
        YazzokiThemeMode.system => ThemeMode.system,
      };

  /// Platform brightness changed -> re-resolve the effective theme so
  /// `system` follows the phone live.
  @override
  void didChangePlatformBrightness() {
    notifyListeners();
  }

  /// Loads the persisted preferences. Called once by Services.init().
  Future<void> load() async {
    try {
      final saved = await _store.readAll();
      _themeId =
          isValidThemeId(saved.themeId) ? saved.themeId : kDefaultThemeId;
      _mode = saved.mode;
      _applyToProfile = saved.applyToProfile;
      _showIcons = saved.showIcons;
    } catch (_) {
      _themeId = kDefaultThemeId;
      _mode = YazzokiThemeMode.dark;
      _applyToProfile = false;
      _showIcons = true;
    }
    notifyListeners();
  }

  /// Changes the brightness preference and persists it.
  Future<void> setMode(YazzokiThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await _persist();
  }

  /// Changes the catalog theme and persists it. Unknown ids are ignored (a
  /// retired theme must never leave the app without a palette).
  Future<void> setThemeId(String themeId) async {
    if (!isValidThemeId(themeId)) return;
    _themeId = themeId;
    notifyListeners();
    await _persist();
  }

  /// Toggles "apply my theme to other users' view of my profile". The CALLER
  /// syncs it to the server; the controller only owns the local preference.
  Future<void> setApplyToProfile(bool value) async {
    _applyToProfile = value;
    notifyListeners();
    await _persist();
  }

  /// Toggles the scattered background icons. Local only — the other users see
  /// whatever THEIR own preference is, never ours.
  Future<void> setShowIcons(bool value) async {
    _showIcons = value;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _store.writeAll(
        themeId: _themeId,
        mode: _mode,
        applyToProfile: _applyToProfile,
        showIcons: _showIcons,
      );
    } catch (_) {
      // Persistence is best-effort: the in-memory choice already applied.
    }
  }
}
