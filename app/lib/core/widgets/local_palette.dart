import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_palette.dart';

/// Scopes a LOCAL palette to a subtree.
///
/// The app's design tokens resolve through [AppColors]' ACTIVE palette, which
/// is global. This widget lets ONE subtree (the profile header of another
/// user) render in that user's published theme while the rest of the app keeps
/// the viewer's theme. It swaps the active palette before building [child] and
/// restores the viewer's palette right after, so nothing outside leaks.
///
/// [AppColors.setActive] is synchronous and the palette is read during build,
/// so the restore is safe inside the same frame.
class LocalPalette extends StatelessWidget {
  const LocalPalette({
    super.key,
    required this.palette,
    required this.child,
  });

  final YazzokiPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewer = AppColors.activePalette;
    AppColors.setActive(palette);
    try {
      return child;
    } finally {
      AppColors.setActive(viewer);
    }
  }
}
