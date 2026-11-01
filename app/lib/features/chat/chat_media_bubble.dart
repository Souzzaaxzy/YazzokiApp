import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/api_config.dart';
import '../feed/post_video_preview.dart';
import '../post/video_player_screen.dart';
import '../../models/conversation.dart';
import '../../core/widgets/view_once_icon.dart';
import 'album_bubble.dart';

/// Compact chat media bubble — used by BOTH private conversations and groups.
///
/// * [ChatMessage.isImage]: renders a responsive, crisp image (fills width,
///   preserves aspect, bounded height) and opens an enlarged viewer on tap.
/// * [ChatMessage.isVideo]: renders a muted short autoplay preview (reusing
///   the post Video preview) with a play overlay; tapping opens the fullscreen
///   player (same player used by posts — no second player stack).
class ChatMediaBubble extends StatelessWidget {
  const ChatMediaBubble({
    super.key,
    required this.message,
    this.maxWidth = 260,
    this.onStickerTap,
    this.onViewOnceTap,
    this.onAlbumTap,
    this.onCaptionTap,
  });

  final ChatMessage message;
  final double maxWidth;

  /// Opens a VIEW-ONCE media (full screen, protected). The chat screen owns
  /// the opening because it also has to declare the view to the server and
  /// put up the screenshot shield.
  final VoidCallback? onViewOnceTap;

  /// Opens an ALBUM at the tapped index.
  final void Function(int index)? onAlbumTap;

  /// Tapping the caption (it may be long) opens the full text.
  final VoidCallback? onCaptionTap;

  /// Called when a STICKER message is TAPPED. Favoriting a sticker in the
  /// chat is a simple tap on the sticker itself — never a long press (the
  /// long press keeps opening the normal message menu).
  final VoidCallback? onStickerTap;

  @override
  Widget build(BuildContext context) {
    final constrained = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _content(context),
    );
    return constrained;
  }

  Widget _content(BuildContext context) {
    // VIEW-ONCE that THIS viewer already consumed: the media is gone (the
    // server withheld the URL), so the bubble states that instead of showing
    // a broken image.
    if (message.viewOnce && message.isViewOnceConsumed) {
      return _ConsumedViewOnce(width: maxWidth);
    }
    // A VIEW-ONCE still available: a sealed card. Tapping opens it, which is
    // what consumes it.
    if (message.viewOnce) {
      return _SealedViewOnce(
        width: maxWidth,
        kind: message.isVideo ? 'video' : 'image',
        onTap: onViewOnceTap,
      );
    }
    if (message.isAlbum && (message.album?.isNotEmpty ?? false)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumBubble(
            items: message.album!,
            maxWidth: maxWidth,
            onTapItem: onAlbumTap,
          ),
          if (message.caption != null) _Caption(text: message.caption!, onTap: onCaptionTap),
        ],
      );
    }
    if (message.isSticker && message.stickerUrl != null) {
      return GestureDetector(
        // Toque na própria figurinha = favoritar (sem long press).
        onTap: onStickerTap,
        behavior: HitTestBehavior.opaque,
        child: _StickerBubble(url: ApiConfig.resolveUrl(message.stickerUrl!)),
      );
    }
    if (message.isImage && message.imageUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: GestureDetector(
              onTap: () => _openImageViewer(context),
              child: _ResponsiveChatImage(
                  url: ApiConfig.resolveUrl(message.imageUrl!)),
            ),
          ),
          if (message.caption != null)
            _Caption(text: message.caption!, onTap: onCaptionTap),
        ],
      );
    }
    if (message.isVideo && message.videoUrl != null) {
      final preview = PostVideoPreview(
        videoUrl: ApiConfig.resolveUrl(message.videoUrl!),
        active: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VideoPlayerScreen(
              videoUrl: ApiConfig.resolveUrl(message.videoUrl!),
            ),
          ),
        ),
        maxHeightFraction: 0.5,
      );
      if (message.caption == null) return preview;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          _Caption(text: message.caption!, onTap: onCaptionTap),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  void _openImageViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ImageViewer(url: ApiConfig.resolveUrl(message.imageUrl!)),
      ),
    );
  }
}

/// Fills available width, keeps the natural aspect ratio, bounded height —
/// the SAME responsive logic used for post photos so chat images look sharp.
class _ResponsiveChatImage extends StatefulWidget {
  const _ResponsiveChatImage({required this.url});

  final String url;

  @override
  State<_ResponsiveChatImage> createState() => _ResponsiveChatImageState();
}

class _ResponsiveChatImageState extends State<_ResponsiveChatImage> {
  double? _aspectRatio;

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.paddingOf(context);
    final availableHeight =
        MediaQuery.sizeOf(context).height - safeArea.top - safeArea.bottom;
    final minHeight = availableHeight * 0.15;
    final maxHeight = availableHeight * 0.5;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio = _aspectRatio ?? (4 / 3);
        final height = (width / ratio).clamp(minHeight, maxHeight);
        return SizedBox(
          width: width,
          height: height,
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.cover,
            placeholder: (_, __) => _placeholder(),
            errorWidget: (_, __, ___) => _placeholder(),
          ),
        );
      },
    );
  }

  Widget _placeholder() =>
      Container(color: AppColors.nightBlue, alignment: Alignment.center);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the intrinsic ratio once via a side listener (like posts).
    final provider = CachedNetworkImageProvider(widget.url);
    final stream = provider.resolve(ImageConfiguration.empty);
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool sync) {
      final img = info.image;
      final r = img.width > 0 && img.height > 0
          ? (img.width / img.height).clamp(0.5, 3.0).toDouble()
          : null;
      info.dispose();
      if (r != null && mounted && _aspectRatio != r) {
        setState(() => _aspectRatio = r);
      }
      stream.removeListener(listener!);
    }, onError: (Object _, StackTrace? __) {
      stream.removeListener(listener!);
    });
    stream.addListener(listener);
  }
}

/// A sticker message — rendered DIRECTLY as the image, no text bubble.
///
/// Deliberately COMPACT (WhatsApp-like): bounded to a fraction of the chat
/// width and of the available height, always with `BoxFit.contain` so the
/// aspect ratio is preserved (no crop, no distortion, transparency and APNG
/// animation untouched). The image and its placeholders share one explicit
/// box, so there is no layout jump when the bytes arrive.
class _StickerBubble extends StatelessWidget {
  const _StickerBubble({required this.url});

  final String url;

  /// Hard ceiling for a sticker in the chat (also caps very wide screens).
  /// Kept deliberately SMALL so a sticker never dominates the conversation.
  static const double _maxSide = 118;

  @override
  Widget build(BuildContext context) {
    // Available height (minus chrome) keeps a tall sticker from dominating;
    // the width fraction + the hard ceiling make it compact on every device.
    final media = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = media.height - viewInsets;
    final size = (media.width * 0.27).clamp(
      84.0,
      _maxSide,
    );
    final heightBudget = (availableHeight * 0.22).clamp(84.0, _maxSide);
    final side = size < heightBudget ? size : heightBudget;

    return SizedBox(
      width: side,
      height: side,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => _placeholder(side),
        errorWidget: (_, __, ___) => _error(side),
      ),
    );
  }

  Widget _placeholder(double side) => SizedBox(
        width: side,
        height: side,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF008CFF),
            ),
          ),
        ),
      );

  Widget _error(double side) => SizedBox(
        width: side,
        height: side,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF008CFF),
            size: 26,
          ),
        ),
      );
}

/// Enlarged image viewer (tap media → full image with zoom via InteractiveViewer).
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF008CFF)),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A VIEW-ONCE media that is still sealed: a card that says "abrir" without
/// revealing anything (there is no thumbnail — the whole point is that the
/// media is only seen once, on open).
class _SealedViewOnce extends StatelessWidget {
  const _SealedViewOnce({
    required this.width,
    required this.kind,
    required this.onTap,
  });

  final double width;
  final String kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: width * 0.62,
        decoration: BoxDecoration(
          color: AppColors.bluishBlack,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.deepBlue),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ViewOnceIcon(color: AppColors.accentInk, size: 34, on: true),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              kind == 'video' ? 'Vídeo de 1 visualização' : 'Foto de 1 visualização',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 2),
            Text('Toque para abrir', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

/// A VIEW-ONCE the viewer already opened. The server no longer serves the
/// media, so the bubble says so plainly instead of showing a broken tile.
class _ConsumedViewOnce extends StatelessWidget {
  const _ConsumedViewOnce({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.bluishBlack,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.deepBlue),
      ),
      child: Row(
        children: [
          ViewOnceIcon(color: AppColors.holographicBlue, size: 20, on: false),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text('Visualização única já aberta',
                style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }
}

/// The caption under a media message. Tapping opens it in full (a caption can
/// be long, and the bubble must not grow to fit it).
class _Caption extends StatelessWidget {
  const _Caption({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: AppDimensions.spaceSm),
        child: Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
