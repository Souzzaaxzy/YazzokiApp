import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('dark theme uses Yazzoki ink background', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, AppColors.absoluteBlack);
    });

    test('primary color is the official Yazzoki blue', () {
      final theme = AppTheme.dark;
      expect(theme.colorScheme.primary, AppColors.primaryBlue);
      expect(theme.colorScheme.error, AppColors.error);
    });

    test('input fields have blue focused border', () {
      final theme = AppTheme.dark;
      final input = theme.inputDecorationTheme;
      final focusedBorder = input.focusedBorder;
      expect(focusedBorder, isA<OutlineInputBorder>());
      focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, AppColors.primaryBlue);
    });
  });

  test('AppColors palette matches the official Yazzoki tokens', () {
    expect(AppColors.primaryBlue, const Color(0xFF7FA9CE));
    expect(AppColors.electricBlue, const Color(0xFF9DC4E4));
    expect(AppColors.deepBlue, const Color(0xFF3A3226));
    expect(AppColors.nightBlue, const Color(0xFF241F18));
    expect(AppColors.absoluteBlack, const Color(0xFF12100C));
    expect(AppColors.bluishBlack, const Color(0xFF1B1813));
    expect(AppColors.techWhite, const Color(0xFFF4EFE6));
    expect(AppColors.holographicBlue, const Color(0xFFC9B48C));
    expect(AppColors.success, const Color(0xFF7C9A6D));
    expect(AppColors.error, const Color(0xFFB4553F));
    expect(AppColors.beige, const Color(0xFFD8C6A6));
  });
}
