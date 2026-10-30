import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/app_state.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/hud_label.dart';
import '../../core/widgets/repost_icon.dart';
import '../../core/widgets/theme_watcher.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/api_config.dart';
import '../../models/post.dart';

/// Bottom sheet listing EVERY user who reposted a post.
///
/// The post card's badge only embeds the 3 newest reposters; tapping the
/// badge opens THIS sheet, which pages through the full list from the server
/// (`GET /posts/:id/reposters`). Tapping a row opens that user's profile.
class RepostersSheet extends StatefulWidget {
  const RepostersSheet({super.key, required this.postId});

  final String postId;

  /// Opens the sheet with the platform bottom-sheet animation.
  static Future<void> open(BuildContext context, String postId) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ThemeWatcher(
        builder: (_) => RepostersSheet(postId: postId),
      ),
    );
  }

  @override
  State<RepostersSheet> createState() => _RepostersSheetState();
}

class _RepostersSheetState extends State<RepostersSheet> {
  static const _pageSize = 20;

  final List<ReposterUser> _users = [];
  final ScrollController _scroll = ScrollController();
  late AppState _state;
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  Object? _error;

  bool get _hasMore => _users.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope lookup registers a dependency, so it must not run in
    // initState — didChangeDependencies is the earliest safe point.
    _state = AppStateScope.of(context);
    if (_page == 0 && !_loading) _loadNext();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 48) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading) return;
    if (_page > 0 && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _state.loadReposters(
        widget.postId,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = result.page;
        _total = result.total;
        _users.addAll(result.users);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openUser(ReposterUser user) {
    // Close the sheet first, then open that user's profile.
    Navigator.of(context).pop();
    openProfileById(context, id: user.id, nickname: user.nickname);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppColors.bluishBlack,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLg),
          ),
          border: Border(
            top: BorderSide(color: AppColors.deepBlue, width: 1.5),
          ),
        ),
        // Material keeps ListTile ink splashes legal over the decoration.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppDimensions.spaceSm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceLg,
                  ),
                  child: Row(
                    children: [
                      const RepostIcon(
                        color: AppColors.electricBlue,
                        size: 18,
                        strokeWidth: 1.7,
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      const Expanded(
                        child: HudLabel(text: 'Quem repostou'),
                      ),
                      Text(
                        '$_total',
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 18,
                          color: AppColors.electricBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Divider(color: AppColors.deepBlue, height: 1),
                Flexible(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_users.isEmpty) {
      if (_loading) {
        return const Padding(
          padding: EdgeInsets.all(AppDimensions.spaceXxl),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.electricBlue),
          ),
        );
      }
      if (_error != null) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXxl),
          child: Center(
            child: Text(
              'Não foi possível carregar a lista.',
              style: AppTextStyles.bodyMuted,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXxl),
        child: Center(
          child: Text(
            'Ninguém repostou ainda.',
            style: AppTextStyles.bodyMuted,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      shrinkWrap: true,
      itemCount: _users.length + (_hasMore || _loading ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(color: AppColors.deepBlue, height: 1, indent: 72),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          return const Padding(
            padding: EdgeInsets.all(AppDimensions.spaceMd),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.electricBlue,
                ),
              ),
            ),
          );
        }
        final user = _users[index];
        return ListTile(
          onTap: () => _openUser(user),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLg,
            vertical: 2,
          ),
          leading: UserAvatar(
            name: user.nickname,
            seed: user.nickname,
            imageUrl: user.avatarUrl == null
                ? null
                : ApiConfig.resolveUrl(user.avatarUrl!),
            size: 37,
          ),
          title: Text(user.nickname, style: AppTextStyles.body),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.holographicBlue,
          ),
        );
      },
    );
  }
}
