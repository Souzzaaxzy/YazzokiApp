import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/gallery_picker.dart';
import '../../data/api_config.dart';
import '../../data/services.dart';
import '../../models/conversation.dart';
import 'media_picker_sheet.dart';

/// 📎 attach button inside the chat composer (private + group).
///
/// Opens Yazzoki's OWN media picker ([MediaPickerSheet]) — an in-app gallery
/// grid, not the OS picker, so the selection UI wears the app's identity. The
/// sheet also carries the caption field and the VIEW-ONCE switch.
///
/// The picked files are uploaded (image → /api/uploads, video →
/// /api/uploads/video) and sent as a MEDIA (or ALBUM) message through
/// [onSendMedia], preserving the active reply reference the composer already
/// holds. The upload/send runs inside this widget (with error feedback) so the
/// chat composer never breaks.
class ChatAttachButton extends StatelessWidget {
  const ChatAttachButton({
    super.key,
    required this.iconColor,
    required this.onSendMedia,
  });

  final Color iconColor;

  /// Called after upload with the real media URL; [kind] is 'image'|'video'.
  /// The composer supplies the current replyToMessageId, plus the caption /
  /// view-once / album the user chose in the picker.
  final Future<void> Function(
    String kind,
    String url, {
    String? caption,
    bool viewOnce,
    List<AlbumItem>? album,
  }) onSendMedia;

  Future<void> _openMenu(BuildContext context) async {
    final action = await showModalBottomSheet<_AttachAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const _AttachPopup(),
    );
    if (action == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (action == _AttachAction.camera) {
      // The camera still uses the OS capture (there is no in-app camera), and
      // it stays a SINGLE file — the sheet's caption/view-once do not apply.
      final result = await _captureCameraMedia(context);
      if (!context.mounted) return;
      if (!result.isSuccess || result.file == null) return;
      await _uploadAndSend(
        messenger,
        files: [File(result.file!.path)],
      );
      return;
    }

    // Gallery: Yazzoki's own picker (grid + caption + view-once + album).
    final selection = await showModalBottomSheet<MediaSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const MediaPickerSheet(),
    );
    if (selection == null || selection.assets.isEmpty) return;
    if (!context.mounted) return;

    // Materialise the picked assets into files (the picker works with
    // AssetEntity; the uploader wants bytes on disk).
    final files = <File>[];
    for (final asset in selection.assets) {
      final f = await asset.file;
      if (f != null) files.add(f);
    }
    if (files.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível ler as mídias.')),
      );
      return;
    }
    await _uploadAndSend(
      messenger,
      files: files,
      caption: selection.caption,
      viewOnce: selection.viewOnce,
    );
  }

  /// Uploads every file and sends ONE message: a single media, or an ALBUM
  /// when more than one was picked. The first file becomes the message's
  /// primary media; the whole set travels as `album`.
  Future<void> _uploadAndSend(
    ScaffoldMessengerState messenger, {
    required List<File> files,
    String? caption,
    bool viewOnce = false,
  }) async {
    try {
      final items = <AlbumItem>[];
      for (final file in files) {
        final kind = _isVideoPath(file.path) ? 'video' : 'image';
        if (kind == 'video' && file.lengthSync() > 100 * 1024 * 1024) {
          messenger.showSnackBar(
            const SnackBar(content: Text('O vídeo excede o limite de 100 MB.')),
          );
          return;
        }
        final url = kind == 'video'
            ? await Services.instance.uploads.uploadVideo(file)
            : await Services.instance.uploads.upload(file);
        items.add(AlbumItem(kind: kind, url: url));
      }
      final first = items.first;
      await onSendMedia(
        first.kind,
        first.url,
        caption: caption,
        viewOnce: viewOnce,
        album: items.length > 1 ? items : null,
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Erro ao enviar a mídia.')));
    }
  }

  /// Camera capture: opens the native camera and lets the user switch
  /// between taking a PHOTO or recording a VIDEO (image_picker has no
  /// single "camera media" entry, so the camera action offers Foto/Vídeo —
  /// the gallery action stays unified).
  Future<GalleryPickResult> _captureCameraMedia(BuildContext context) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _CameraKindPopup(),
    );
    if (kind == null) return const GalleryPickResult.cancelled();
    return kind == 'video' ? pickCameraVideo() : pickCameraImage();
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: IconButton(
        icon: Icon(Icons.attach_file_rounded, color: iconColor, size: 26),
        onPressed: () => _openMenu(context),
        tooltip: 'Anexar mídia',
      ),
    );
  }
}

enum _AttachAction { gallery, camera }

/// Compact bottom pop-up listing the attach actions (Galeria / Câmera).
class _AttachPopup extends StatelessWidget {
  const _AttachPopup();

  @override
  Widget build(BuildContext context) {
    return _menuShell(
      context,
      icon1: Icons.photo_library_rounded,
      label1: 'Galeria',
      on1: () => Navigator.of(context).pop(_AttachAction.gallery),
      icon2: Icons.videocam_rounded,
      label2: 'Câmera',
      on2: () => Navigator.of(context).pop(_AttachAction.camera),
    );
  }
}

/// Camera sub-menu: Foto ou Vídeo (only for the camera — image_picker's
/// native camera has separate photo/video intents).
class _CameraKindPopup extends StatelessWidget {
  const _CameraKindPopup();

  @override
  Widget build(BuildContext context) {
    return _menuShell(
      context,
      icon1: Icons.photo_camera_outlined,
      label1: 'Foto',
      on1: () => Navigator.of(context).pop('image'),
      icon2: Icons.video_camera_back_outlined,
      label2: 'Vídeo',
      on2: () => Navigator.of(context).pop('video'),
    );
  }
}

Widget _menuShell(
  BuildContext context, {
  required IconData icon1,
  required String label1,
  required VoidCallback on1,
  required IconData icon2,
  required String label2,
  required VoidCallback on2,
}) {
  return SafeArea(
    top: false,
    child: Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bluishBlack,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.deepBlue),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuTile(context, icon1, label1, on1),
            _menuTile(context, icon2, label2, on2),
            const SizedBox(height: AppDimensions.spaceXs),
          ],
        ),
      ),
    ),
  );
}

Widget _menuTile(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onTap,
) {
  return ListTile(
    leading: Icon(icon, color: AppColors.holographicBlue, size: 24),
    title: Text(label,
        style: AppTextStyles.body.copyWith(color: AppColors.techWhite)),
    trailing: Icon(Icons.chevron_right_rounded,
        color: AppColors.holographicBlue, size: 20),
    onTap: onTap,
  );
}
