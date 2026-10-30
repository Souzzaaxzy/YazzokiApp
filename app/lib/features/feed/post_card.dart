import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/profile_navigation.dart';
import '../../data/api_config.dart';
import '../../models/post.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/yazzoki_card.dart';
import '../../core/widgets/repost_icon.dart';
import '../../core/widgets/user_avatar.dart';
import 'post_video_preview.dart';
import 'reposters_sheet.dart';
import 'responsive_post_image.dart';
import '../post/video_player_screen.dart';

/// Reusable post card for the feed.
///
/// Likes are toggled remotely via AppState (optimistic update with
/// server confirmation and rollback on failure). Tapping the card opens
/// the post detail screen using the post's real server id.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onComment,
    this.videoActive = false,
    this.videoKey,
  });

  final Post post;
  final VoidCallback onComment;

  /// Whether this post's video preview should autoplay (single-active: the
  /// feed keeps exactly one active video at a time).
  final bool videoActive;

  /// GlobalKey the feed attaches to the video frame for visibility tracking.
  final GlobalKey? videoKey;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _likeController;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.35,
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    _likeController.forward(from: 1.0).then((_) => _likeController.reverse());
    final ok = await AppStateScope.of(context).toggleLike(widget.post.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível atualizar a curtida. Tente novamente.'),
        ),
      );
    }
  }

  /// Toggles the repost ("share to profile"). The server throttles rapid
  /// RE-reposts; a 429 surfaces as a discreet message, the local state is
  /// rolled back by AppState.
  Future<void> _toggleRepost() async {
    final ok = await AppStateScope.of(context).toggleRepost(widget.post.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível repostar agora. Aguarde um instante e tente de novo.',
          ),
        ),
      );
    }
  }

  /// Opens the fullscreen video player for this post's video.
  void _openVideo() {
    if (!widget.post.isVideo) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          videoUrl: ApiConfig.resolveUrl(widget.post.videoUrl!),
        ),
      ),
    );
  }

  void _openDetail() {
    Navigator.of(context)
        .pushNamed(AppRoutes.postDetail, arguments: widget.post.id);
  }


  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return YazzokiCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceLg,
        vertical: AppDimensions.spaceSm,
      ),
      child: InkWell(
        onTap: _openDetail,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tapping the author's photo OR nickname opens THAT user's
            // profile (by real id), never the session user's. The GestureDetector
            // wins this region's taps over the card's own open-detail InkWell.
            GestureDetector(
              onTap: () => openProfileById(
                context,
                id: post.authorId ?? '',
                nickname: post.authorNickname,
              ),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  UserAvatar(
                      name: post.authorNickname,
                      seed: post.avatarSeed,
                      imageUrl: post.authorAvatarUrl,
                    ),
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorNickname, style: AppTextStyles.h3),
                        Text(
                          '${post.authorNickname} • ${relativeTime(post.createdAt)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (post.text.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceLg),
              Text(post.text, style: AppTextStyles.body),
            ],
            if (post.isVideo) ...[
              const SizedBox(height: AppDimensions.spaceMd),
              KeyedSubtree(
                key: widget.videoKey,
                child: PostVideoPreview(
                  videoUrl: ApiConfig.resolveUrl(post.videoUrl!),
                  thumbnailUrl: post.thumbnailUrl != null
                      ? ApiConfig.resolveUrl(post.thumbnailUrl!)
                      : null,
                  active: widget.videoActive,
                  onTap: _openVideo,
                ),
              ),
            ] else if (post.imageUrl != null) ...[
              const SizedBox(height: AppDimensions.spaceMd),
              ResponsivePostImage(
                  imageUrl: ApiConfig.resolveUrl(post.imageUrl!)),
            ],
            const SizedBox(height: AppDimensions.spaceLg),
            // Repost badge (TikTok-style): a small chip on the LEFT with the
            // repost mark + "usuario repostou" (or "+N usuarios repostaram").
            // Sits ABOVE the action buttons.
            if (post.repostCount > 0) ...[
              _RepostBadge(post: post),
              const SizedBox(height: AppDimensions.spaceMd),
            ],
            Row(
              children: [
                ScaleTransition(
                  scale: _likeController,
                  child: _ActionButton(
                    icon: post.liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: post.likes.toString(),
                    color: post.liked
                        ? AppColors.error
                        : AppColors.holographicBlue,
                    onTap: _toggleLike,
                    semanticLabel: post.liked
                        ? 'Descurtir publicação'
                        : 'Curtir publicação',
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceXl),
                // Repost sits BETWEEN the like and the comment, with the
                // DRAWN mark (never a Material glyph).
                _ActionButton(
                  label: post.repostCount.toString(),
                  color: post.reposted
                      ? AppColors.success
                      : AppColors.holographicBlue,
                  onTap: _toggleRepost,
                  semanticLabel: post.reposted
                      ? 'Remover repost'
                      : 'Repostar publicação',
                  child: RepostIcon(
                    color: post.reposted
                        ? AppColors.success
                        : AppColors.holographicBlue,
                    active: post.reposted,
                    size: 19,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceXl),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: post.commentCount.toString(),
                  color: AppColors.holographicBlue,
                  onTap: widget.onComment,
                  semanticLabel: 'Abrir comentários',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.icon,
    this.child,
    required this.label,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
  }) : assert(icon != null || child != null,
            'Informe um icon ou um child desenhado.');

  /// A Material icon; ignored when [child] is provided.
  final IconData? icon;

  /// A custom DRAWN mark (e.g. [RepostIcon]) rendered instead of an icon.
  final Widget? child;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceSm,
            vertical: AppDimensions.spaceXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              child ?? Icon(icon, size: 18, color: color),
              const SizedBox(width: AppDimensions.spaceSm),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The TikTok-style repost chip shown ABOVE the post's action buttons: the
/// DRAWN repost mark + who reposted ("joao repostou" or "+3 usuarios
/// repostaram"). Tapping it opens the FULL list of reposters (each row leads
/// to that user's profile).
class _RepostBadge extends StatelessWidget {
  const _RepostBadge({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final first = post.reposters.isNotEmpty ? post.reposters.first : null;
    final others = post.repostCount - 1;
    final label = others > 0
        ? (first != null
            ? '${first.nickname} e +$others repostaram'
            : '+$others repostaram')
        : (first != null ? '${first.nickname} repostou' : 'Repostado');

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        // Abre a lista COMPLETA de quem repostou (o cartão só mostra os 3
        // mais recentes). Cada linha da lista leva ao perfil do usuário.
        onTap: () => RepostersSheet.open(context, post.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceSm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.bluishBlack,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: AppColors.deepBlue.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepostIcon(color: AppColors.holographicBlue, size: 13, strokeWidth: 1.5),
              const SizedBox(width: AppDimensions.spaceXs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.holographicBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
