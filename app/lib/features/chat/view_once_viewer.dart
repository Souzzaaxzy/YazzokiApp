import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/secure_screen.dart';
import '../../core/widgets/view_once_icon.dart';
import '../../data/api_config.dart';
import '../../models/conversation.dart';
import '../post/video_player_screen.dart';

/// Full-screen viewer for a VIEW-ONCE media, with the protections on.
///
/// Three things are true while this screen is up, and all three are lifted
/// when it closes:
///  * `FLAG_SECURE` is raised, so the system refuses screenshots/recordings;
///  * the screen turns BLACK the moment the app stops being in the foreground
///    — the OS snapshot used by the app switcher would otherwise show the
///    media, which is exactly what "one view" is supposed to prevent;
///  * the view is declared to the server, which then WITHHOLDS the media.
///
/// The declaration happens when the media is actually shown, not when the
/// route opens, so a viewer who backs out immediately does not burn it.
class ViewOnceViewer extends StatefulWidget {
  const ViewOnceViewer({
    super.key,
    required this.message,
    required this.onViewed,
  });

  final ChatMessage message;

  /// Called ONCE, the first moment the media is really on screen. The chat
  /// screen uses it to declare the view to the server (which then withholds
  /// the media) — not when the route opens, so backing out immediately does
  /// not burn the single view.
  final VoidCallback onViewed;

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with WidgetsBindingObserver {
  /// True while the app is NOT in the foreground: the whole screen goes black
  /// so the OS snapshot cannot capture the media.
  bool _obscured = false;
  bool _declared = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Shield goes up BEFORE the first frame: there must be no moment where
    // the media is on screen without the flag.
    SecureScreen.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Always drop the shield, even if the user left via the system back.
    SecureScreen.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_obscured == !foreground) return;
    setState(() => _obscured = !foreground);
  }

  /// Declares the view once, the first time the media is really shown.
  void _declareViewed() {
    if (_declared) return;
    _declared = true;
    // The caller owns the AppState call; this screen only reports the moment.
    widget.onViewed();
  }

  @override
  Widget build(BuildContext context) {
    // While backgrounded, paint NOTHING but black: no media, no controls, no
    // thumbnail — the app-switcher snapshot gets a blank frame.
    if (_obscured) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    final message = widget.message;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _media(message)),
          // A permanent hint that the media is protected, so the viewer knows
          // the rule without being told.
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppDimensions.spaceMd,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMd,
                  vertical: AppDimensions.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ViewOnceIcon(
                        color: Colors.white70, size: 16, on: true),
                    const SizedBox(width: AppDimensions.spaceXs),
                    Text('Visualização única',
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            right: AppDimensions.spaceSm,
            child: IconButton(
              tooltip: 'Fechar',
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _media(ChatMessage message) {
    final imageUrl = message.imageUrl;
    final videoUrl = message.videoUrl;
    if (message.isVideo && videoUrl != null) {
      // The video player is a separate route; the shield stays up because
      // this screen is still mounted underneath it.
      return _StartVideo(
        onStart: () {
          _declareViewed();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VideoPlayerScreen(
                videoUrl: ApiConfig.resolveUrl(videoUrl),
              ),
            ),
          );
        },
      );
    }
    if (imageUrl != null) {
      return InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: ApiConfig.resolveUrl(imageUrl),
            fit: BoxFit.contain,
            imageBuilder: (context, provider) {
              // Declare as soon as the bytes are actually on screen.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _declareViewed();
              });
              return Image(image: provider, fit: BoxFit.contain);
            },
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) => Center(
              child: Text('Não foi possível abrir a mídia.',
                  style: AppTextStyles.caption),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text('Mídia indisponível.', style: AppTextStyles.caption),
    );
  }
}

/// A video view-once starts on an explicit tap (autoplaying would consume the
/// single view before the viewer is ready).
class _StartVideo extends StatelessWidget {
  const _StartVideo({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onStart,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill_rounded,
                size: 76, color: Colors.white70),
            const SizedBox(height: AppDimensions.spaceMd),
            Text('Toque para assistir', style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}
