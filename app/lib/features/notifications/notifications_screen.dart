import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart' as yazzoki;
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/hud_label.dart';
import '../../core/widgets/yazzoki_button.dart';
import '../../core/widgets/yazzoki_card.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/api_config.dart';
import '../../models/yazzoki_notification.dart';

/// Notifications tab — persistent server-side notifications.
///
/// LIKE / COMMENT rows navigate to the post; a FOLLOW
/// renders the actionable Aceitar / Recusar card inside the same list.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _requested = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await AppStateScope.of(context).loadNotifications();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Sem conexão com o Yazzoki.');
    }
  }

  void _open(YazzokiNotification notification) {
    AppStateScope.of(context).markNotificationRead(notification.id);
    if (notification.postId != null) {
      Navigator.of(context)
          .pushNamed(AppRoutes.postDetail, arguments: notification.postId);
    } else {
      openProfileById(
        context,
        id: notification.actorId,
        nickname: notification.actorNickname,
      );
    }
  }

  /// Tapping the ACTOR's photo or nickname on a notification opens THEIR
  /// profile (by real id) — the same no-op guard if already open.
  void _openActor(YazzokiNotification notification) {
    AppStateScope.of(context).markNotificationRead(notification.id);
    openProfileById(
      context,
      id: notification.actorId,
      nickname: notification.actorNickname,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final notifications = state.notifications;
    final loading = state.isLoadingNotifications && notifications.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.absoluteBlack,
      body: RefreshIndicator(
        color: AppColors.electricBlue,
        backgroundColor: AppColors.nightBlue,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.absoluteBlack,
              surfaceTintColor: Colors.transparent,
              title: Text('ATIVIDADES',
                  style: AppTextStyles.title.copyWith(fontSize: 18)),
              actions: [
                if (state.unreadNotifications > 0)
                  IconButton(
                    tooltip: 'Marcar todas como lidas',
                    icon: Icon(Icons.checklist_rounded,
                        color: AppColors.holographicBlue),
                    onPressed: state.markAllNotificationsRead,
                  ),
              ],
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: HudLabel(text: 'LOADING...', dot: true)),
              )
            else if (_error != null && notifications.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'CONNECTION ERROR',
                  hud: 'OFFLINE',
                  subtitle: _error!,
                  action: YazzokiButton(
                    label: 'Tentar novamente',
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                  ),
                ),
              )
            else if (notifications.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'ALL CLEAR',
                  hud: 'NO SIGNAL',
                  subtitle: 'Nenhuma notificação por aqui.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceLg,
                ),
                sliver: SliverList.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    return _NotificationTile(
                      notification: n,
                      onTap: () => _open(n),
                      onActorTap: () => _openActor(n),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spaceXxl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Regular notification row: avatar, actor, description, relative time and
/// an unread glow dot.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onActorTap,
  });

  final YazzokiNotification notification;
  final VoidCallback onTap;
  final VoidCallback onActorTap;

  static String description(YazzokiNotification n) {
    switch (n.type) {
      case 'LIKE':
        return 'curtiu sua publicação.';
      case 'COMMENT':
        return 'comentou na sua publicação.';
      case 'FOLLOW':
        return 'começou a seguir você.';
      case 'REPOST':
        return 'repostou o seu post.';
      case 'STORY_REPOST':
        return 'repostou o seu stories.';
      default:
        return 'interagiu com você.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return YazzokiCard(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm),
      onTap: onTap,
      border: Border.all(
        color: n.read
            ? AppColors.deepBlue.withValues(alpha: 0.5)
            : AppColors.primaryBlue,
        width: n.read
            ? AppDimensions.borderWidthThin
            : AppDimensions.borderWidthActive,
      ),
      child: Row(
        children: [
          if (!n.read)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.electricBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.glowSmall, blurRadius: 8),
                ],
              ),
            ),
          if (!n.read) const SizedBox(width: AppDimensions.spaceSm),
          // The ACTOR's photo opens THEIR profile (by real id).
          GestureDetector(
            onTap: onActorTap,
            behavior: HitTestBehavior.opaque,
            child: UserAvatar(
  name: n.actorNickname,
  seed: n.actorNickname,
  imageUrl: n.actorAvatarUrl,
  size: 36,
),
          ),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The actor's nickname keeps its OWN cosmetics (color +
                // via the shared NicknameRenderer — never the
                // viewer's configuration.
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMuted,
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        // The actor's nickname opens THEIR profile.
                        child: GestureDetector(
                          onTap: onActorTap,
                          behavior: HitTestBehavior.opaque,
                          child: Text(n.actorNickname, style: AppTextStyles.h3.copyWith(fontSize: 14)),
                        ),
                      ),
                      TextSpan(text: ' ${description(n)}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXs),
                Text(
                  yazzoki.relativeTime(n.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
