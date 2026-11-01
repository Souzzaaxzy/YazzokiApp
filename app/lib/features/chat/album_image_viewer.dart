import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/api_config.dart';
import '../../models/conversation.dart';

/// Full-screen viewer for the PHOTOS of an album.
///
/// Swipes horizontally between the images, shows the caption underneath (when
/// the album carries one) and a small position counter. Videos inside an album
/// are opened by the caller with the app's video player, so this screen only
/// deals with images.
class AlbumImageViewer extends StatefulWidget {
  const AlbumImageViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.caption,
  });

  final List<AlbumItem> items;
  final int initialIndex;
  final String? caption;

  @override
  State<AlbumImageViewer> createState() => _AlbumImageViewerState();
}

class _AlbumImageViewerState extends State<AlbumImageViewer> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Only the IMAGES are paged; a video tile is skipped here (the caller opens
  /// videos with the player).
  late final List<AlbumItem> _images =
      widget.items.where((i) => !i.isVideo).toList();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Nada para mostrar.', style: AppTextStyles.caption),
        ),
      );
    }
    // The tapped tile may have been a video, which is not in `_images`; clamp
    // so the viewer always opens on a real page.
    final start = _index.clamp(0, _images.length - 1);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          '${start + 1} de ${_images.length}',
          style: AppTextStyles.caption.copyWith(color: Colors.white70),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _images.length,
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: ApiConfig.resolveUrl(_images[i].url),
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Text('Não foi possível abrir a imagem.',
                          style: AppTextStyles.caption),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.caption != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppDimensions.spaceLg,
                AppDimensions.spaceMd,
                AppDimensions.spaceLg,
                MediaQuery.paddingOf(context).bottom + AppDimensions.spaceMd,
              ),
              color: Colors.black54,
              child: Text(
                widget.caption!,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
