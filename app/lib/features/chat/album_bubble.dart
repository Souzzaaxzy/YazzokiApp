import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/api_config.dart';
import '../../models/conversation.dart';

/// An ALBUM message rendered as a grid inside the chat bubble.
///
/// Layout follows the count, the way people expect from a photo set: one big
/// tile for 2–3 (with the rest stacked beside it), a 2×2 for 4, and a 3-column
/// grid beyond that. The tiles are square and share the bubble's rounded
/// corners, so an album still reads as ONE message.
class AlbumBubble extends StatelessWidget {
  const AlbumBubble({
    super.key,
    required this.items,
    this.maxWidth = 260,
    this.onTapItem,
  });

  final List<AlbumItem> items;
  final double maxWidth;

  /// Opens the viewer at [index].
  final void Function(int index)? onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final count = items.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: SizedBox(
        width: maxWidth,
        height: _heightFor(count, maxWidth),
        child: _grid(count),
      ),
    );
  }

  /// The grid's height keeps the tiles square-ish without ever exceeding the
  /// bubble width.
  double _heightFor(int count, double width) {
    if (count <= 1) return width;
    if (count == 2) return width * 0.62;
    if (count == 3) return width * 0.62;
    if (count == 4) return width;
    return width * (count <= 6 ? 0.9 : 1.2);
  }

  Widget _grid(int count) {
    if (count == 2) {
      return Row(children: [
        Expanded(child: _tile(0)),
        const SizedBox(width: 2),
        Expanded(child: _tile(1)),
      ]);
    }
    if (count == 3) {
      // One tall tile on the left, two stacked on the right.
      return Row(children: [
        Expanded(child: _tile(0)),
        const SizedBox(width: 2),
        Expanded(
          child: Column(children: [
            Expanded(child: _tile(1)),
            const SizedBox(height: 2),
            Expanded(child: _tile(2)),
          ]),
        ),
      ]);
    }
    if (count == 4) {
      return Column(children: [
        Expanded(
            child: Row(children: [
          Expanded(child: _tile(0)),
          const SizedBox(width: 2),
          Expanded(child: _tile(1)),
        ])),
        const SizedBox(height: 2),
        Expanded(
            child: Row(children: [
          Expanded(child: _tile(2)),
          const SizedBox(width: 2),
          Expanded(child: _tile(3)),
        ])),
      ]);
    }
    // 5+: a 3-column grid, the last row partial.
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: count,
      itemBuilder: (context, i) => _tile(i),
    );
  }

  Widget _tile(int i) {
    final item = items[i];
    return GestureDetector(
      onTap: onTapItem == null ? null : () => onTapItem!(i),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: ApiConfig.resolveUrl(item.previewUrl),
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.cardSurface),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.cardSurface,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.deepBlue, size: 18),
            ),
          ),
          if (item.isVideo)
            const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white70, size: 28),
            ),
          // The count badge on the LAST tile of a big album, so the bubble
          // tells how many are inside without opening it.
          if (i == items.length - 1 && items.length > 4)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${items.length - 1}',
                  style: AppTextStyles.label.copyWith(fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
