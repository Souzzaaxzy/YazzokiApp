import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/services/theme_controller.dart';

/// The persisted theme preferences.
class SavedTheme {
  const SavedTheme({
    required this.themeId,
    required this.mode,
    required this.applyToProfile,
  });

  final String themeId;
  final YazzokiThemeMode mode;
  final bool applyToProfile;
}

/// Persists the theme preferences (catalog theme id, brightness, and whether
/// the theme is applied to the public profile) next to the auth tokens in the
/// Keystore-backed secure storage.
///
/// Kept as a thin wrapper so it can be faked in widget tests — the same
/// pattern [TokenStore] uses.
class ThemeStore {
  ThemeStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _keyThemeId = 'yazzoki.theme_id';
  static const _keyTheme = 'yazzoki.theme_mode';
  static const _keyApply = 'yazzoki.theme_apply_profile';

  /// Reads the saved preferences. Unknown/absent values fall back to the
  /// classic Yazzoki look (default theme + dark).
  Future<SavedTheme> readAll() async {
    final themeId = await _storage.read(key: _keyThemeId);
    final rawMode = await _storage.read(key: _keyTheme);
    final rawApply = await _storage.read(key: _keyApply);

    var mode = YazzokiThemeMode.dark;
    for (final m in YazzokiThemeMode.values) {
      if (m.name == rawMode) mode = m;
    }
    return SavedTheme(
      themeId: (themeId == null || themeId.isEmpty) ? '' : themeId,
      mode: mode,
      applyToProfile: rawApply == 'true',
    );
  }

  Future<void> writeAll({
    required String themeId,
    required YazzokiThemeMode mode,
    required bool applyToProfile,
  }) async {
    await _storage.write(key: _keyThemeId, value: themeId);
    await _storage.write(key: _keyTheme, value: mode.name);
    await _storage.write(key: _keyApply, value: applyToProfile ? 'true' : 'false');
  }
}
