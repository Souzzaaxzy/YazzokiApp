import 'package:photo_manager/photo_manager.dart';
import 'package:yazzoki/features/chat/gallery_source.dart';

/// Uma galeria que só existe no teste: sem prompt de permissão, sem aparelho.
///
/// O seletor fala com a galeria por [GallerySource] justamente para isto — o
/// fluxo de escolher mídia pode ser exercitado de ponta a ponta num teste de
/// widget, sem depender do `photo_manager` (que é estático e só roda no
/// aparelho).
class FakeGallerySource implements GallerySource {
  FakeGallerySource({this.assets = const [], this.granted = true});

  List<AssetEntity> assets;
  bool granted;

  @override
  Future<PermissionState> requestPermission() async =>
      granted ? PermissionState.authorized : PermissionState.denied;

  @override
  Future<List<AssetEntity>> recent({required int page, int size = 80}) async {
    if (page == 0) return assets;
    final start = page * size;
    if (start >= assets.length) return const [];
    return assets.sublist(start);
  }

  @override
  Future<bool> hasMore({required int page, int size = 80}) async =>
      (page + 1) * size < assets.length;
}

/// Um asset de mentira. O `id` é o que o seletor usa para marcar seleção, e o
/// `title` decide o tratamento de GIF.
AssetEntity fakeAsset({
  required String id,
  String? title,
  AssetType type = AssetType.image,
}) {
  return AssetEntity(
    id: id,
    typeInt: type == AssetType.video ? 2 : 1,
    width: 100,
    height: 100,
    title: title,
  );
}
