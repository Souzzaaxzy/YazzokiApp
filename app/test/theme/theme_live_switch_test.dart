import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/app.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/features/auth/login/login_screen.dart';
import 'package:yazzoki/features/splash/splash_screen.dart';

/// Regression: switching the theme must repaint the WHOLE app immediately —
/// no restart, no navigation, no reload. The single source of truth is
/// [ThemeController.instance]; the root [YazzokiApp] listens to it, swaps the
/// active palette and rebuilds the MaterialApp in the same frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MaterialApp materialApp(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  Color scaffoldColor(WidgetTester tester) =>
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
      Colors.transparent;

  testWidgets('trocar o tema troca o acento em TODA a UI, sem reiniciar',
      (tester) async {
    final controller = ThemeController.instance;
    controller.setThemeId('washi');
    controller.setMode(YazzokiThemeMode.dark);
    addTearDown(() {
      controller.setThemeId(kDefaultThemeId);
      controller.setMode(YazzokiThemeMode.dark);
    });

    await tester.pumpWidget(const YazzokiApp());
    await tester.pump();

    expect(AppColors.activePalette, themeById('washi').dark);
    expect(scaffoldColor(tester), themeById('washi').dark.scaffold);

    // Change the THEME (same brightness): palette + widgets update now.
    controller.setThemeId('sakura');
    await tester.pump();
    expect(AppColors.activePalette, themeById('sakura').dark);
    expect(scaffoldColor(tester), themeById('sakura').dark.scaffold);

    // Change the BRIGHTNESS of the same theme.
    controller.setMode(YazzokiThemeMode.light);
    await tester.pump();
    expect(AppColors.activePalette, themeById('sakura').light);
    expect(scaffoldColor(tester), themeById('sakura').light.scaffold);
  });

  testWidgets('dark → light → dark aplica na hora', (tester) async {
    final controller = ThemeController.instance;
    controller.setThemeId(kDefaultThemeId);
    controller.setMode(YazzokiThemeMode.dark);
    addTearDown(() => controller.setMode(YazzokiThemeMode.dark));

    await tester.pumpWidget(const YazzokiApp());
    await tester.pump();
    expect(materialApp(tester).themeMode, ThemeMode.dark);
    expect(AppColors.activePalette, themeById(kDefaultThemeId).dark);

    controller.setMode(YazzokiThemeMode.light);
    await tester.pump();
    expect(materialApp(tester).themeMode, ThemeMode.light);
    expect(AppColors.activePalette, themeById(kDefaultThemeId).light);
    expect(scaffoldColor(tester), themeById(kDefaultThemeId).light.scaffold);
  });

  testWidgets('system mode follows the phone brightness live', (tester) async {
    final controller = ThemeController.instance;
    addTearDown(() {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      controller.setMode(YazzokiThemeMode.dark);
    });
    controller.setMode(YazzokiThemeMode.system);

    await tester.pumpWidget(const YazzokiApp());
    await tester.pump();
    expect(materialApp(tester).themeMode, ThemeMode.system);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pump();
    expect(AppColors.activePalette,
        themeById(controller.themeId).light);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    await tester.pump();
    expect(AppColors.activePalette,
        themeById(controller.themeId).dark);
  });

  testWidgets('uma tela empurrada (login) também segue a troca',
      (tester) async {
    final controller = ThemeController.instance;
    controller.setThemeId(kDefaultThemeId);
    controller.setMode(YazzokiThemeMode.dark);
    addTearDown(() => controller.setMode(YazzokiThemeMode.dark));

    await tester.pumpWidget(const YazzokiApp());
    await tester.pump(const Duration(milliseconds: splashDurationMs));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoginScreen), findsOneWidget);

    controller.setThemeId('ai');
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(scaffoldColor(tester), themeById('ai').dark.scaffold);
  });
}
