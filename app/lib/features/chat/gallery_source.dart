import 'package:photo_manager/photo_manager.dart';

/// The device gallery, behind a seam.
///
/// The picker needs three things from the platform: the permission state, the
/// list of albums, and a page of assets. Going straight to the static
/// `PhotoManager` would make the picker impossible to test (and impossible to
/// drive from a fake in a widget test), so those three calls live here.
abstract class GallerySource {
  /// Asks for (or reads) the photo/video permission.
  Future<PermissionState> requestPermission();

  /// The "all media" list, newest first.
  Future<List<AssetEntity>> recent({required int page, int size = 80});

  /// Whether the "all media" list has more pages after [page].
  Future<bool> hasMore({required int page, int size = 80});
}

/// The real implementation, backed by `photo_manager`.
class PhotoManagerGallerySource implements GallerySource {
  const PhotoManagerGallerySource();

  Future<AssetPathEntity?> _all() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // photos + videos, one list
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    return albums.isEmpty ? null : albums.first;
  }

  @override
  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  @override
  Future<List<AssetEntity>> recent({required int page, int size = 80}) async {
    final all = await _all();
    if (all == null) return const [];
    return all.getAssetListPaged(page: page, size: size);
  }

  @override
  Future<bool> hasMore({required int page, int size = 80}) async {
    final all = await _all();
    if (all == null) return false;
    final total = await all.assetCountAsync;
    return (page + 1) * size < total;
  }
}
