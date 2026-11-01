import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/data/theme_store.dart';

/// In-memory ThemeStore: stands in for secure storage so persistence is
/// exercised through the real ThemeController code path.
class _MemoryThemeStore implements ThemeStore {
  String themeId = '';
  String mode = '';
  bool apply = false;
  bool? icons;

  @override
  Future<SavedTheme> readAll() async {
    var m = YazzokiThemeMode.dark;
    for (final x in YazzokiThemeMode.values) {
      if (x.name == mode) m = x;
    }
    return SavedTheme(
      themeId: themeId,
      mode: m,
      applyToProfile: apply,
      showIcons: icons ?? true,
    );
  }

  @override
  Future<void> writeAll({
    required String themeId,
    required YazzokiThemeMode mode,
    required bool applyToProfile,
    required bool showIcons,
  }) async {
    this.themeId = themeId;
    this.mode = mode.name;
    apply = applyToProfile;
    icons = showIcons;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController', () {
    testWidgets('defaults to the catalog theme + dark before load',
        (tester) async {
      final controller = ThemeController.debug(_MemoryThemeStore());
      expect(controller.mode, YazzokiThemeMode.dark);
      expect(controller.materialMode, ThemeMode.dark);
      expect(controller.themeId, kDefaultThemeId);
      expect(controller.applyToProfile, isFalse);
      // The decorated look is the default: icons ON.
      expect(controller.showIcons, isTrue);
    });

    testWidgets('setMode/setThemeId persist across a controller restart',
        (tester) async {
      final store = _MemoryThemeStore();
      final a = ThemeController.debug(store);
      await a.load();
      await a.setMode(YazzokiThemeMode.light);
      await a.setThemeId('sakura');
      await a.setApplyToProfile(true);
      await a.setShowIcons(false);
      expect(a.mode, YazzokiThemeMode.light);
      expect(a.themeId, 'sakura');

      // Simulate an app restart: a new controller on the SAME store.
      final b = ThemeController.debug(store);
      await b.load();
      expect(b.mode, YazzokiThemeMode.light);
      expect(b.themeId, 'sakura');
      expect(b.applyToProfile, isTrue);
      expect(b.showIcons, isFalse);
    });

    testWidgets('a preference saved before the Icons option keeps them ON',
        (tester) async {
      final store = _MemoryThemeStore()..icons = null; // key never written
      final controller = ThemeController.debug(store);
      await controller.load();
      expect(controller.showIcons, isTrue);
    });

    testWidgets('toggling the icons notifies and is local-only',
        (tester) async {
      final store = _MemoryThemeStore();
      final controller = ThemeController.debug(store);
      await controller.load();
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.setShowIcons(false);
      expect(notified, 1);
      expect(controller.showIcons, isFalse);
      expect(store.icons, isFalse);
    });

    testWidgets('an unknown theme id falls back to the default',
        (tester) async {
      final controller = ThemeController.debug(_MemoryThemeStore());
      await controller.load();
      await controller.setThemeId('tema-que-nao-existe');
      // Ignored: a retired theme must never leave the app without a palette.
      expect(controller.themeId, kDefaultThemeId);
    });

    testWidgets('notifies listeners on changes', (tester) async {
      final controller = ThemeController.debug(_MemoryThemeStore());
      await controller.load();
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.setMode(YazzokiThemeMode.light);
      await controller.setThemeId('sumi');
      expect(notified, greaterThan(1));
    });
  });

  group('Palette resolution', () {
    test('dark preference always resolves to the dark half', () {
      expect(effectivePalette('washi', YazzokiThemeMode.dark, Brightness.dark),
          themeById('washi').dark);
      expect(effectivePalette('washi', YazzokiThemeMode.dark, Brightness.light),
          themeById('washi').dark);
    });

    test('light preference always resolves to the light half', () {
      expect(effectivePalette('ai', YazzokiThemeMode.light, Brightness.dark),
          themeById('ai').light);
    });

    test('system follows the platform brightness', () {
      expect(
          effectivePalette('matcha', YazzokiThemeMode.system, Brightness.dark),
          themeById('matcha').dark);
      expect(
          effectivePalette('matcha', YazzokiThemeMode.system, Brightness.light),
          themeById('matcha').light);
    });

    test('the SAME theme id gives different palettes per brightness', () {
      final dark =
          effectivePalette('sakura', YazzokiThemeMode.dark, Brightness.dark);
      final light =
          effectivePalette('sakura', YazzokiThemeMode.light, Brightness.dark);
      expect(dark.scaffold, isNot(light.scaffold));
      expect(dark, isNot(light));
    });

    test('unknown theme id falls back to the default theme', () {
      expect(effectivePalette('nope', YazzokiThemeMode.dark, Brightness.dark),
          themeById(kDefaultThemeId).dark);
    });

    test('every theme is distinct (no two share the same light scaffold)', () {
      final seen = <int>{};
      for (final t in yazzokiThemes) {
        expect(seen.add(t.light.scaffold.hashCode), isTrue,
            reason: 'tema ${t.id} repete a cor de fundo de outro');
      }
    });

    testWidgets('AppColors tokens follow the active palette', (tester) async {
      AppColors.setActive(themeById('washi').dark);
      final darkBg = AppColors.scaffoldBackground;
      final darkText = AppColors.techWhite;

      AppColors.setActive(themeById('washi').light);
      expect(AppColors.scaffoldBackground, isNot(darkBg));
      expect(AppColors.techWhite, isNot(darkText));

      // The accent FOLLOWS the theme (this is what makes themes visible).
      AppColors.setActive(themeById('sakura').light);
      final sakuraAccent = AppColors.primaryBlue;
      AppColors.setActive(themeById('matcha').light);
      expect(AppColors.primaryBlue, isNot(sakuraAccent));

      AppColors.setActive(themeById(kDefaultThemeId).dark);
    });
  });
}
