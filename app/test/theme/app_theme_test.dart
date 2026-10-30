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
    expect(AppColors.primaryBlue, const Color(0xFF5B8FC7));
    expect(AppColors.electricBlue, const Color(0xFF8FBCE4));
    expect(AppColors.deepBlue, const Color(0xFF3E362A));
    expect(AppColors.nightBlue, const Color(0xFF17140F));
    expect(AppColors.absoluteBlack, const Color(0xFF000000));
    expect(AppColors.bluishBlack, const Color(0xFF0C0B09));
    expect(AppColors.techWhite, const Color(0xFFFBF8F1));
    expect(AppColors.holographicBlue, const Color(0xFFCDB68D));
    expect(AppColors.success, const Color(0xFF6E9159));
    expect(AppColors.error, const Color(0xFFC0392B));
    expect(AppColors.beige, const Color(0xFFD8C6A6));
    expect(AppColors.sealRed, const Color(0xFFB42D24));
  });
}
