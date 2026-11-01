import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('dark theme uses the active palette background', () {
      AppColors.setActive(themeById('washi').dark);
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, AppColors.absoluteBlack);
      AppColors.setActive(themeById(kDefaultThemeId).dark);
    });

    test('primary color follows the active accent', () {
      AppColors.setActive(themeById('washi').dark);
      final theme = AppTheme.dark;
      expect(theme.colorScheme.primary, AppColors.primaryBlue);
      expect(theme.colorScheme.error, AppColors.error);
      AppColors.setActive(themeById(kDefaultThemeId).dark);
    });

    test('input fields have an accent focused border', () {
      AppColors.setActive(themeById('washi').dark);
      final theme = AppTheme.dark;
      final focusedBorder = theme.inputDecorationTheme.focusedBorder;
      expect(focusedBorder, isA<OutlineInputBorder>());
      focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, AppColors.primaryBlue);
      AppColors.setActive(themeById(kDefaultThemeId).dark);
    });
  });

  group('Catálogo de temas', () {
    test('tem os 10 temas esperados, com ids estáveis', () {
      expect(yazzokiThemes.length, 10);
      expect(yazzokiThemes.map((t) => t.id).toList(), [
        'washi',
        'sumi',
        'sakura',
        'matcha',
        'hinoki',
        'kogane',
        'ai',
        'yuki',
        'tsuki',
        'fuji',
      ]);
    });

    test('isValidThemeId aceita os ids do catálogo e rejeita o resto', () {
      expect(isValidThemeId('sakura'), isTrue);
      expect(isValidThemeId('nope'), isFalse);
      expect(isValidThemeId(null), isFalse);
      expect(isValidThemeId(''), isFalse);
    });

    test('themeById cai no padrão quando o id é desconhecido', () {
      expect(themeById('nope').id, kDefaultThemeId);
      expect(themeById(null).id, kDefaultThemeId);
      expect(themeById('sumi').id, 'sumi');
    });

    test('semantic colours (error/success) NÃO mudam por tema', () {
      // Mesmo trocando o tema, erro/sucesso seguem os mesmos tokens.
      AppColors.setActive(themeById('sakura').light);
      final e1 = AppColors.error;
      final s1 = AppColors.success;
      AppColors.setActive(themeById('matcha').dark);
      expect(AppColors.error, e1);
      expect(AppColors.success, s1);
      AppColors.setActive(themeById(kDefaultThemeId).dark);
    });

    test('todos os temas passam no contraste mínimo (WCAG AA 4.5:1)', () {
      for (final t in yazzokiThemes) {
        for (final p in [t.light, t.dark]) {
          expect(contrastRatio(p.text, p.scaffold), greaterThanOrEqualTo(4.5),
              reason: '${t.id}: texto/fundo');
          expect(contrastRatio(p.text, p.surface), greaterThanOrEqualTo(4.5),
              reason: '${t.id}: texto/superfície');
          expect(contrastRatio(p.textMuted, p.surface), greaterThanOrEqualTo(4.5),
              reason: '${t.id}: muted/superfície');
          expect(contrastRatio(p.accentInk, p.surface), greaterThanOrEqualTo(4.5),
              reason: '${t.id}: acento-texto/superfície');
          expect(contrastRatio(const Color(0xFFFFFFFF), p.bubble),
              greaterThanOrEqualTo(4.5),
              reason: '${t.id}: texto branco/bolha');
        }
      }
    });
  });
}
