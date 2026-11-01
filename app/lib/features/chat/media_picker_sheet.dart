import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/view_once_icon.dart';

/// The most media one send may carry (an album). Enforced here AND on the
/// server — the client cap is for the UI, the server's is the real rule.
const int kMaxAlbumItems = 10;

/// What the user chose in [MediaPickerSheet].
class MediaSelection {
  const MediaSelection({
    required this.assets,
    this.caption,
    this.viewOnce = false,
  });

  final List<AssetEntity> assets;
  final String? caption;
  final bool viewOnce;

  bool get isAlbum => assets.length > 1;
}

/// Yazzoki's own media picker.
///
/// A grid of the device gallery built in the app (not the OS picker) so the
/// selection UI can wear the app's identity: ink surfaces, ice-blue accents,
/// the Zen Mincho display face and the hand-drawn [ViewOnceIcon]. It is used
/// for private chat, groups and stories.
///
/// The sheet is deliberately a single screen: the grid, a caption field and
/// the VIEW-ONCE switch for the CHAT case. Stories pass [forStory] to hide the
/// chat-only affordances (caption / view-once) — a story is just media.
class MediaPickerSheet extends StatefulWidget {
  const MediaPickerSheet({
    super.key,
    this.forStory = false,
    this.initialCount = 0,
  });

  /// Stories: media only (no caption, no view-once, single file).
  final bool forStory;

  /// How many items the caller already holds (0 for a fresh open).
  final int initialCount;

  @override
  State<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<MediaPickerSheet> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _caption = TextEditingController();

  List<AssetEntity> _assets = const [];
  final List<AssetEntity> _selected = [];

  PermissionState? _permission;
  bool _loading = true;
  String? _error;
  bool _viewOnce = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    try {
      if (!more) {
        final permission = await PhotoManager.requestPermissionExtend();
        if (!mounted) return;
        setState(() => _permission = permission);
        if (!permission.isAuth && !permission.hasAccess) {
          setState(() => _loading = false);
          return;
        }
      }
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, // photos + videos, one list
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );
      if (albums.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _assets = const [];
        });
        return;
      }
      final all = albums.first;
      final page = await all.getAssetListPaged(
        page: more ? (_assets.length ~/ 80) : 0,
        size: 80,
      );
      if (!mounted) return;
      setState(() {
        _assets = more ? [..._assets, ...page] : page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível abrir a galeria.';
      });
    }
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 400) {
      _load(more: true);
    }
  }

  void _toggle(AssetEntity asset) {
    final idx = _selected.indexWhere((a) => a.id == asset.id);
    if (idx >= 0) {
      setState(() => _selected.removeAt(idx));
      return;
    }
    final cap = widget.forStory ? 1 : kMaxAlbumItems;
    if (_selected.length >= cap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cap == 1
              ? 'O story aceita uma mídia.'
              : 'No máximo $kMaxAlbumItems mídias por envio.'),
        ),
      );
      return;
    }
    setState(() {
      _selected.add(asset);
      // A view-once is a single media by definition; picking a second file
      // turns the send into an album, so the switch must not stay armed.
      if (_selected.length > 1) _viewOnce = false;
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(
      MediaSelection(
        assets: List.of(_selected),
        caption: widget.forStory ? null : _caption.text.trim(),
        viewOnce: widget.forStory ? false : _viewOnce,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.absoluteBlack,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
        border: Border.all(color: AppColors.deepBlue),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(),
            _Header(
              count: _selected.length,
              forStory: widget.forStory,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            const Divider(height: 1),
            SizedBox(height: 320, child: _buildGrid()),
            if (!widget.forStory) _buildComposerBar(),
            _ConfirmBar(
              count: _selected.length,
              forStory: widget.forStory,
              onConfirm: _selected.isEmpty ? null : _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Text(_error!,
              style: AppTextStyles.caption, textAlign: TextAlign.center),
        ),
      );
    }
    final permission = _permission;
    if (permission != null && !permission.isAuth && !permission.hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Text(
            'Para escolher mídias, permita o acesso à galeria nas '
            'configurações do aparelho.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Text('Nenhuma mídia encontrada.', style: AppTextStyles.caption),
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(AppDimensions.spaceXs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, i) {
        final asset = _assets[i];
        final order = _selected.indexWhere((a) => a.id == asset.id);
        return _MediaTile(
          asset: asset,
          order: order >= 0 ? order + 1 : null,
          onTap: () => _toggle(asset),
        );
      },
    );
  }

  Widget _buildComposerBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceMd,
        AppDimensions.spaceSm,
        AppDimensions.spaceSm,
        AppDimensions.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _caption,
              minLines: 1,
              maxLines: 3,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Escreva uma legenda...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.holographicBlue,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMd,
                  vertical: AppDimensions.spaceSm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide(color: AppColors.deepBlue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide(color: AppColors.deepBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          _ViewOnceToggle(
            armed: _viewOnce,
            // An album cannot be view-once: the two rules contradict each
            // other, and the server rejects the combination.
            enabled: _selected.length <= 1,
            onChanged: (v) => setState(() => _viewOnce = v),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spaceSm),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.holographicBlue.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.forStory,
    required this.onClose,
  });

  final int count;
  final bool forStory;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceLg,
        AppDimensions.spaceSm,
        AppDimensions.spaceSm,
        AppDimensions.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forStory ? 'Novo story' : 'Enviar mídia',
                  style: AppTextStyles.title.copyWith(fontSize: 17),
                ),
                Text(
                  forStory
                      ? 'Escolha uma foto ou vídeo'
                      : (count == 0
                          ? 'Escolha até $kMaxAlbumItems'
                          : '$count selecionada${count > 1 ? 's' : ''}'),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            icon: Icon(Icons.close_rounded, color: AppColors.techWhite),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// One gallery cell: the thumbnail, the selection order badge, and a small
/// video mark. The selected state is the theme accent, so the grid wears the
/// active theme like the rest of the app.
class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.asset,
    required this.order,
    required this.onTap,
  });

  final AssetEntity asset;
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order != null;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AssetThumb(asset: asset),
          if (asset.type == AssetType.video)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(Icons.play_circle_fill_rounded,
                  size: 16, color: Colors.white),
            ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryBlue, width: 3),
              ),
            ),
          Positioned(
            right: 4,
            top: 4,
            child: _OrderBadge(order: order),
          ),
        ],
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});

  final int? order;

  @override
  Widget build(BuildContext context) {
    final selected = order != null;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primaryBlue : Colors.black38,
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: selected
          ? Text(
              '$order',
              style: AppTextStyles.label.copyWith(fontSize: 10),
            )
          : null,
    );
  }
}

/// Thumbnail for one gallery asset. Loads the bytes through photo_manager and
/// decodes them; the tile keeps its box while loading, so the grid never
/// reflows.
class _AssetThumb extends StatefulWidget {
  const _AssetThumb({required this.asset});

  final AssetEntity asset;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // A small square thumbnail: the grid never needs the full-resolution file
    // (that would blow up memory on a long scroll).
    final bytes = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(240),
      quality: 80,
    );
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return Container(color: AppColors.bluishBlack);
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
    );
  }
}

/// The VIEW-ONCE switch: the hand-drawn mark plus a label, in a pill that
/// fills with the accent when armed.
class _ViewOnceToggle extends StatelessWidget {
  const _ViewOnceToggle({
    required this.armed,
    required this.enabled,
    required this.onChanged,
  });

  final bool armed;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? AppColors.holographicBlue.withValues(alpha: 0.4)
        : (armed ? AppColors.techWhite : AppColors.accentInk);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Tooltip(
        message: enabled
            ? 'Visualização única'
            : 'Álbum não pode ser de visualização única',
        child: InkWell(
          onTap: enabled ? () => onChanged(!armed) : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMd,
              vertical: AppDimensions.spaceSm,
            ),
            decoration: BoxDecoration(
              color: armed ? AppColors.primaryBlue : AppColors.bluishBlack,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: armed ? AppColors.primaryBlue : AppColors.deepBlue,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ViewOnceIcon(color: fg, size: 18, on: armed),
                const SizedBox(width: AppDimensions.spaceXs),
                Text(
                  '1x',
                  style: AppTextStyles.label.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.count,
    required this.forStory,
    required this.onConfirm,
  });

  final int count;
  final bool forStory;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final label = forStory
        ? 'PUBLICAR NO STORY'
        : (count > 1 ? 'ENVIAR $count MÍDIAS' : 'ENVIAR');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceLg,
        AppDimensions.spaceSm,
        AppDimensions.spaceLg,
        AppDimensions.spaceMd,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor:
                onConfirm == null ? AppColors.deepBlue : AppColors.primaryBlue,
            foregroundColor: AppColors.techWhite,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceLg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          child: Text(label, style: AppTextStyles.label),
        ),
      ),
    );
  }
}
