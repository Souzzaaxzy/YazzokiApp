import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Result of an attempted gallery pick. Success carries the picked file
/// (already resized/compressed by [ImagePicker]); failure carries a
/// user-facing message so callers never hang or crash on a denial.

class GalleryPickResult {
  const GalleryPickResult._({this.file, this.error, this.cancelled = false});

  const GalleryPickResult.success(XFile file) : this._(file: file);
  const GalleryPickResult.cancelled() : this._(cancelled: true);
  const GalleryPickResult.failure(String error) : this._(error: error);

  /// The picked image (non-null only on success).
  final XFile? file;

  /// A ready-to-show error message (non-null only on failure).
  final String? error;

  /// True when the user simply cancelled the picker (no message needed).
  final bool cancelled;

  bool get isSuccess => file != null;
}

/// Unified device-gallery image picker.

/// Handles the runtime permission for the device photo library (Android 13+
/// uses the granular `READ_MEDIA_IMAGES`;older versions fall back to the
/// legacy READ_EXTERNAL_STORAGE via permission_handler)and then picks a
/// single image with mild compression so MEMORY stays bounded. Denials
/// return a typed [GalleryPickResult.failure] — the caller reacts without
/// blocking the screen.
///
/// The returned [XFile] is already scaled down (max 1600px) and JPEG
/// compressed (quality ~85) by image_picker, which avoids shipping giant
/// original photos around the app.
Future<GalleryPickResult> pickGalleryImage({
  int imageQuality = 85,
  double maxWidth = 1600,
  double maxHeight = 1600,
}) async {
  if (kIsWeb) {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
      );
      return file == null
          ? const GalleryPickResult.cancelled()
          : GalleryPickResult.success(file);
    } catch (_) {
      return const GalleryPickResult.failure(
          'Não foi possível abrir a galeria.');
    }
  }

  if (!kIsWeb && !Platform.isIOS) {
    // permission_handler maps the right OS permission: it requests
    // READ_MEDIA_IMAGES (Android 13+ an no-op on 12-) ORthe
    // legacy READ_EXTERNAL_STORAGE (<=12) automatically. On a
    // denial we still check the other media permission before giving up —
    // on some OEM builds one of them is granted while the other reports
    // denied.
    final photos = await Permission.photos.request();
    final storage = await Permission.storage.request();
    final photosOk = photos.isGranted || photos.isLimited;
    final storageOk = storage.isGranted || storage.isLimited;
    if (!photosOk && !storageOk) {
      return GalleryPickResult.failure(
        'Permissão para acessar a galeria negada. '
        'Conceda acesso nas configurações para escolher imagens.',
      );
    }
  }

  try {
    // Primeiro escolhe SEM reencode: assim um GIF chega intacto. O
    // image_picker RECODIFICA quando pedimos qualidade/dimensão, e
    // recodificar um GIF animado o transforma num quadro estático.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: null,
      maxWidth: null,
      maxHeight: null,
    );
    if (file == null) {
      return const GalleryPickResult.cancelled();
    }
    if (isGifPath(file.path)) {
      // GIF: mantém os BYTES originais (animação preservada).
      return GalleryPickResult.success(file);
    }
    // Não-GIF: recomprime normalmente para não subir uma foto gigante.
    final optimized = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return GalleryPickResult.success(optimized ?? file);
  } catch (_) {
    return const GalleryPickResult.failure('Não foi possível abrir a galeria.');
  }
}

/// Extensões de imagem aceitas no avatar/banner. GIF entra aqui: é uma
/// IMAGEM ANIMADA — vídeo (.mp4 e afins) continua fora.
const Set<String> supportedImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
};

/// True when [path] points at an accepted image type (GIF included).
bool isSupportedImagePath(String path) {
  final lower = path.toLowerCase();
  return supportedImageExtensions.any(lower.endsWith);
}

/// True when [path] is a GIF (the one type we must NOT re-encode).
bool isGifPath(String path) => path.toLowerCase().endsWith('.gif');

/// Opens the device gallery and lets the user pick EITHER a photo or a
/// video in a single step (image_picker's `pickMedia`). The caller detects
/// the type from the returned file (extension/MIME). Returns the [XFile].
Future<GalleryPickResult> pickGalleryMedia() async {
  try {
    // image_picker's `pickMedia` opens the gallery photo/video picker in one
    // step (photo OR video — the user chooses directly there).
    final file = await ImagePicker().pickMedia();
    if (file == null) {
      return const GalleryPickResult.cancelled();
    }
    return GalleryPickResult.success(file);
  } catch (_) {
    return const GalleryPickResult.failure('Não foi possível abrir a galeria.');
  }
}

/// Picks a VIDEO from the device gallery (image_picker's pickVideo). No
/// permission prompts beyond what Android's photo picker requires; returns
/// the [XFile] as-is (videos are not re-encoded).
Future<GalleryPickResult> pickGalleryVideo() async {
  try {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return const GalleryPickResult.cancelled();
    }
    return GalleryPickResult.success(file);
  } catch (_) {
    return const GalleryPickResult.failure('Não foi possível abrir a galeria.');
  }
}

/// Captures a PHOTO with the device camera (image_picker).
Future<GalleryPickResult> pickCameraImage() async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) {
      return const GalleryPickResult.cancelled();
    }
    return GalleryPickResult.success(file);
  } catch (_) {
    return const GalleryPickResult.failure('Não foi possível abrir a câmera.');
  }
}

/// Records a VIDEO with the device camera (image_picker, preserves quality).
Future<GalleryPickResult> pickCameraVideo() async {
  try {
    final file = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (file == null) {
      return const GalleryPickResult.cancelled();
    }
    return GalleryPickResult.success(file);
  } catch (_) {
    return const GalleryPickResult.failure('Não foi possível abrir a câmera.');
  }
}

/// Turns a gallery [AssetEntity] (chosen in the app's own grid) into a file the
/// uploader can send.
///
/// Two rules, and both matter:
///  * a GIF (or a VIDEO) is passed through UNTOUCHED — re-encoding an animated
///    GIF flattens it to a single frame, and a video must stay a video;
///  * anything else is re-encoded DOWN to [maxSide] and JPEG-compressed, so a
///    modern phone photo never ships at full resolution (memory + upload).
///
/// Returns null when the asset cannot be read (the caller surfaces a message).
Future<File?> assetToUploadFile(
  AssetEntity asset, {
  int maxSide = 1600,
  int quality = 85,
}) async {
  try {
    // Video, or an animated GIF: keep the original bytes.
    final name = (asset.title ?? '').toLowerCase();
    if (asset.type == AssetType.video || name.endsWith('.gif')) {
      return asset.file;
    }
    // Everything else: a bounded, compressed JPEG.
    final bytes = await asset.thumbnailDataWithSize(
      ThumbnailSize.square(maxSide),
      quality: quality,
    );
    if (bytes == null) return asset.file;
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/yazzoki_${asset.id}_$maxSide.jpg',
    );
    await out.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    return out;
  } catch (_) {
    return null;
  }
}
