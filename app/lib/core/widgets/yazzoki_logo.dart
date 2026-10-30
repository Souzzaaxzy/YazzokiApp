import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';

/// Official Yazzoki brand name (single source of truth for the wordmark).
const String kAppName = 'Yazzoki';

/// The Yazzoki lockup: the brush-stroke emblem above the wordmark, rendered
/// in the app's mincho display face. Used on the login screen and anywhere a
/// full brand mark is wanted (the feed/search bars use the wordmark alone).
///
/// The emblem is a raster asset, so it is tinted via [ColorFilter] to follow
/// the active palette — dark ink on the light theme, off-white on the dark.
class YazzokiLogo extends StatelessWidget {
  const YazzokiLogo({
    super.key,
    this.height = 88,
    this.showWordmark = true,
    this.wordmarkSize = 34,
  });

  /// Height of the emblem image.
  final double height;

  /// Whether to render the wordmark below the emblem.
  final bool showWordmark;

  /// Font size of the wordmark.
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    final emblem = Image.asset(
      'assets/brand/logo_ink.png',
      height: height,
      fit: BoxFit.contain,
      color: AppColors.techWhite,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    if (!showWordmark) return emblem;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        emblem,
        const SizedBox(height: AppDimensions.spaceMd),
        Text(
          kAppName,
          style: AppTextStyles.display.copyWith(fontSize: wordmarkSize),
        ),
      ],
    );
  }
}
