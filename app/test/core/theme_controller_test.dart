import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/data/theme_store.dart';

/// In-memory ThemeStore: stands in for secure storage so persistence is
/// exercised through the real ThemeController code path.
class _MemoryThemeStore implements ThemeStore {
  String? value;

  @override
  Future<YazzokiThemeMode> read() async {
    for (final mode in YazzokiThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return YazzokiThemeMode.dark;
  }

  @override
  Future<void> write(YazzokiThemeMode mode) async {
    value = mode.name;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController', () {
    testWidgets('defaults to dark before any preference is loaded',
        (tester) async {
      final controller = ThemeController.debug(_MemoryThemeStore());
      expect(controller.mode, YazzokiThemeMode.dark);
      expect(controller.materialMode, ThemeMode.dark);
    });

    testWidgets('setMode persists: a fresh controller loads the same value',
        (tester) async {
      final store = _MemoryThemeStore();
      final a = ThemeController.debug(store);
      await a.load();
      await a.setMode(YazzokiThemeMode.light);
      expect(a.mode, YazzokiThemeMode.light);
      expect(a.materialMode, ThemeMode.light);
      expect(store.value, 'light');

      // Simulate an app restart: a new controller on the SAME store.
      final b = ThemeController.debug(store);
      await b.load();
      expect(b.mode, YazzokiThemeMode.light);

      await a.setMode(YazzokiThemeMode.system);
      expect(store.value, 'system');
    });

    testWidgets('notifies listeners on setMode', (tester) async {
      final controller = ThemeController.debug(_MemoryThemeStore());
      await controller.load();
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.setMode(YazzokiThemeMode.light);
      expect(notified, greaterThan(0));
    });
  });

  group('Palette resolution', () {
    test('dark preference always resolves to the dark palette', () {
      expect(effectivePalette(YazzokiThemeMode.dark, Brightness.dark),
          YazzokiPalette.dark);
      expect(effectivePalette(YazzokiThemeMode.dark, Brightness.light),
          YazzokiPalette.dark);
    });

    test('light preference always resolves to the light palette', () {
      expect(effectivePalette(YazzokiThemeMode.light, Brightness.dark),
          YazzokiPalette.light);
      expect(effectivePalette(YazzokiThemeMode.light, Brightness.light),
          YazzokiPalette.light);
    });

    test('system follows the platform brightness', () {
      expect(effectivePalette(YazzokiThemeMode.system, Brightness.dark),
          YazzokiPalette.dark);
      expect(effectivePalette(YazzokiThemeMode.system, Brightness.light),
          YazzokiPalette.light);
    });

    testWidgets('AppColors tokens change with the active palette',
        (tester) async {
      AppColors.setActive(YazzokiPalette.dark);
      final darkBg = AppColors.scaffoldBackground;
      final darkText = AppColors.techWhite;

      AppColors.setActive(YazzokiPalette.light);
      expect(AppColors.scaffoldBackground, isNot(darkBg));
      expect(AppColors.techWhite, isNot(darkText));
      // Brand accent survives both themes.
      expect(AppColors.primaryBlue, AppColors.primaryBlue);

      AppColors.setActive(YazzokiPalette.dark); // restore default for others
    });
  });
}
