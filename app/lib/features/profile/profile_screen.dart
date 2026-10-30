import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/app_state.dart';
import '../../core/services/video_cover_service.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glow_container.dart';
import '../../core/widgets/grid_icon.dart';
import '../../core/widgets/hud_label.dart';
import '../../core/widgets/repost_icon.dart';
import '../../core/widgets/yazzoki_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/api_config.dart';
import '../../models/follow.dart';
import '../../models/yazzoki_user.dart';
import '../../models/post.dart';
import '../chat/chat_navigation.dart';
import '../feed/story_viewer.dart';
import 'follow_button.dart';
import 'follow_list_sheet.dart';
import 'profile_music_bar.dart';
import 'settings_sheet.dart';

/// Profile screen — the server is the single source of truth.
///
/// [nickname] null (or equal to the session user's) means "own profile":
/// renders the Edit button and the floating "+" create-post button, and
/// NEVER the follow button. Another user's profile shows the big
/// Seguir / Seguindo / Seguir de volta button (server-managed state).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.nickname, this.active = true});

  final String? nickname;

  /// A aba de perfil está VISÍVEL? O app usa `IndexedStack`, que mantém as
  /// abas vivas (`Visibility.maintain` → `maintainAnimation: true`), então a
  /// música continuaria tocando ao trocar de aba. O `HomeScreen` informa a
  /// visibilidade e a tela PARA a música quando ela sai de vista — que é o
  /// pedido: "a música só fica na aba de perfil; se sair, ela para e reseta".
  ///
  /// Uma tela EMPURRADA (nickname != null) não passa por isso: ela vive numa
  /// rota própria e o dispose já cuida do áudio.
  final bool active;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _requested = false;
  String? _error;

  /// Posts | Reposts. The TabBarView gives the horizontal SWIPE between the
  /// two tabs for free; the header/stats stay above, shared by both.
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// Acesso ao player da música do perfil para pará-lo quando a aba sai de
  /// vista (o `IndexedStack` mantém a tela viva, então o dispose NÃO roda).
  final GlobalKey<ProfileMusicBarState> _musicKey =
      GlobalKey<ProfileMusicBarState>();

  @override
  void didUpdateWidget(covariant ProfileScreen old) {
    super.didUpdateWidget(old);
    // A aba deixou de estar visível → para a música e volta ao início.
    if (old.active && !widget.active) {
      _musicKey.currentState?.stopAndReset();
    }
  }

  /// The real user id this screen is presenting (once loaded). Used to
  /// register/un-register the profile in the navigation stack and to guard
  /// the photo long-press "view only on another user's profile".
  String? _shownUserId;

  /// The own-profile tab (nickname == null) lives inside a persistent
  /// IndexedStack tab — it must stay registered as open and never un-register
  /// on dispose. A pushed ProfileScreen (nickname != null) pops and un-registers.
  bool get _isTab => widget.nickname == null;

  bool get _isOwn {
    final state = AppStateScope.of(context);
    return widget.nickname == null ||
        widget.nickname!.toLowerCase() ==
            (state.currentUser?.nickname.toLowerCase() ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      // Defer: loadProfile notifies listeners, which is not allowed
      // synchronously during the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    // A pushed profile route pops and must release its slot so the same
    // profile can be opened again later. The persistent own-profile tab
    // stays registered for the app lifetime.
    if (!_isTab) {
      final id = _shownUserId;
      if (id != null) closeProfile(id);
    }
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final nickname = widget.nickname ?? state.currentUser?.nickname;
    if (nickname == null) return;
    setState(() => _error = null);
    try {
      await state.loadProfile(nickname);
      if (!mounted) return;
      // The Reposts tab data (own or another user's) loads alongside the
      // profile so switching tabs never shows a blank frame.
      final uid = state.profileFor(widget.nickname)?.user.id;
      if (uid != null) {
        unawaited(state.loadReposts(uid));
      }
      // Register the profile by its REAL id once it resolves. Called both on
      // the first load and on refresh — re-adding the same id is a no-op.
      final loaded = state.profileFor(widget.nickname)?.user;
      if (loaded != null) {
        _shownUserId = loaded.id;
        markProfileOpen(loaded.id);
        // The user effectively VISITED this profile → remember it in the
        // "Pesquisas recentes" history (never the session user's own).
        if (!_isOwn) {
          state.recordProfileVisit(loaded);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Não foi possível conectar ao Yazzoki. '
            'Verifique sua conexão.',
      );
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).pushNamed(AppRoutes.editProfile);
    // Reload from the server after editing so the profile always reflects
    // what was actually persisted.
    await _load();
  }

  void _openPost(Post post) {
    Navigator.of(context).pushNamed(AppRoutes.postDetail, arguments: post.id);
  }

  /// Clique na foto de perfil: abre o Story ATIVO dessa pessoa (mesmo já
  /// visto). Se ela não tiver Story ativo, NÃO abre um visualizador vazio —
  /// garante os Stories carregados antes de decidir.
  Future<void> _openUserStory(AppState state, YazzokiUser user) async {
    if (!state.isStoryCatalogLoaded) {
      await state.loadStories();
      if (!mounted) return;
    }
    final index = state.storyGroupIndexFor(user.id);
    if (index < 0) return; // sem Story ativo → nada acontece
    await StoryViewer.open(context, state, startGroup: index);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isOwn = _isOwn;
    final sessionUser = state.currentUser;

    if (sessionUser == null) {
      return Scaffold(
        backgroundColor: AppColors.absoluteBlack,
        body: Center(child: HudLabel(text: 'NOT AUTHENTICATED', dot: true)),
      );
    }

    // The viewed profile is read from ITS OWN keyed slot — never from a
    // shared variable. Visiting B and coming back shows A immediately,
    // because A's slot was never overwritten by B.
    final profile = state.profileFor(widget.nickname);
    final user = profile?.user ?? (isOwn ? sessionUser : null);
    final posts = profile?.posts ?? const <Post>[];
    final follow = profile?.follow;
    final loading = state.isLoadingProfile && profile == null;

    return Scaffold(
      backgroundColor: AppColors.absoluteBlack,
      floatingActionButton: isOwn ? const CreatePostFab() : null,
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
              // The ☰ settings menu exists ONLY on the own profile — on
              // another user's profile there is no logout/delete entry.
              leading: isOwn
                  ? IconButton(
                      tooltip: 'Configurações',
                      icon: Icon(Icons.menu_rounded,
                          color: AppColors.holographicBlue),
                      onPressed: () => SettingsSheet.open(context),
                    )
                  : null,
              title: Text('PERFIL',
                  style: AppTextStyles.title.copyWith(fontSize: 18)),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: HudLabel(text: 'LOADING PROFILE...', dot: true),
                ),
              )
            else if (_error != null && profile == null)
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
            else if (user != null) ...[
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  user: user,
                  isOwn: isOwn,
                  follow: follow,
                  hasUnseenStory: state.hasUnseenStory(user.id),
                  onOpenStory: () => _openUserStory(state, user),
                  onEdit: _openEditProfile,
                  onFollowersTap: () => FollowListSheet.open(
                      context, user, FollowListKind.followers),
                  onFollowingTap: () => FollowListSheet.open(
                      context, user, FollowListKind.following),
                  onMessage: () => openChatWithUser(context, user),
                  musicKey: _musicKey,
                ),
              ),
              SliverToBoxAdapter(
                child: Divider(color: AppColors.deepBlue, height: 1),
              ),
              // Two equal halves (2/4 and 3/4 of the width): Posts | Reposts.
              // Swiping horizontally moves between them.
              SliverToBoxAdapter(
                child: _ProfileTabs(
                  controller: _tabs,
                  postsCount: posts.length,
                  repostsCount: state.repostsFor(user.id).length,
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _ProfileGrid(
                      posts: posts,
                      emptyTitle: 'NO POSTS YET',
                      emptySubtitle: isOwn
                          ? 'Você ainda não publicou nada.'
                          : 'Este usuário ainda não publicou nada.',
                      onOpen: _openPost,
                    ),
                    _ProfileGrid(
                      posts: state.repostsFor(user.id),
                      emptyTitle: 'NO REPOSTS YET',
                      emptySubtitle: isOwn
                          ? 'Você ainda não repostou nada.'
                          : 'Este usuário ainda não repostou nada.',
                      onOpen: _openPost,
                    ),
                  ],
                ),
              ),
            ],
            // Room for the floating "+" so it never covers the last tile.
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spaceHuge * 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar da foto de perfil com o estado de STORY como moldura:
///   * [unseen] = true  → borda BRANCA (Story ativo não visto);
///   * [unseen] = false → SEM borda (Story visto ou inexistente).
///
/// Reusa o MESMO sistema visual de Stories do feed (borda branca =
/// não visto); a moldura antiga foi removida via `UserAvatar(ring: false)`.
class _StoryRingAvatar extends StatelessWidget {
  const _StoryRingAvatar({required this.unseen, required this.child});

  final bool unseen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(unseen ? 4 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Borda branca só quando há Story não visto; caso contrário,
        // transparente (sem borda) — a transição é suave.
        border: Border.all(
          color: unseen ? Colors.white : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: unseen
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: AppDimensions.glowSmallBlur,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Profile header — banner on top, avatar overlapping its lower edge.
///
/// Layout (top → bottom):
///   • wide BANNER (cover) — the user's own image, or a default gradient;
///   • the round avatar straddling the banner's bottom edge, pushed to the
///     LEFT: its upper half sits over the banner, the lower half below it;
///   • the nickname to the RIGHT of the avatar (aligned with its lower half);
///   • the bio under the nickname;
///   • the real counters (Seguidores / Seguindo / Curtidas / Posts);
///   • then the edit CTA (own profile) or the follow button.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.isOwn,
    required this.follow,
    required this.onEdit,
    required this.onFollowersTap,
    required this.onFollowingTap,
    required this.onMessage,
    required this.hasUnseenStory,
    required this.onOpenStory,
    this.musicKey,
  });

  /// Key do player da música, para a TELA conseguir pará-lo quando a aba sai
  /// de vista (o IndexedStack mantém a tela viva, então o dispose não roda).
  final GlobalKey<ProfileMusicBarState>? musicKey;

  final YazzokiUser user;
  final bool isOwn;
  final FollowState? follow;
  final VoidCallback onEdit;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final VoidCallback onMessage;

  /// True when this user has an ACTIVE story the visitor has not seen yet —
  /// draws the white ring around the photo (same viewed/unviewed system as
  /// the feed strip; persisted server-side).
  final bool hasUnseenStory;

  /// Simple TAP on the photo opens this user's Story. A no-op when they have
  /// no active story (never opens an empty viewer).
  final VoidCallback onOpenStory;

  /// Banner height (157px). The avatar box is 108px, so half of it (54)
  /// hangs below the banner — enough for the nickname to sit beside the
  /// avatar's lower half without colliding with the banner itself.
  static const double _bannerHeight = 157;

  /// Outer box of the avatar (the FramedAvatar frame is drawn inside it).
  /// The photo itself is [_avatarSize].
  static const double _avatarBox = 108;

  /// Extra height the strip needs when the small `#id` line is rendered
  /// under the nickname (it must not be clipped by the Stack).
  static const double _publicIdExtra = 16;
  static const double _avatarSize = 96;

  @override
  Widget build(BuildContext context) {
    // The photo is rendered BARE: no glow/halo container and no decorative
    // ring for everyone — only the STORY state draws a border.
    final avatar = _StoryRingAvatar(
      unseen: hasUnseenStory,
      child: UserAvatar(
        name: user.nickname,
        seed: user.avatarSeed ?? user.nickname,
        imageUrl: user.avatarUrl,
        // The avatar's own decorative ring is DISABLED here: the photo
        // border now communicates the STORY state (white = unseen, none =
        // seen/no story) instead of a fixed accent ring.
        size: _avatarSize,
        ring: false,
      ),
    );

    // Gesto duplo na foto (outro usuário):
    //   * CLIQUE  → abre o Story ativo (se houver);
    //   * PRESSÃO (long press) → amplia a foto de perfil.
    // O GestureDetector diferencia os dois: um long press cancela o tap
    // (nunca dispara as duas ações).
    final tappableAvatar = GestureDetector(
      onTap: isOwn ? null : onOpenStory,
      onLongPress: isOwn
          ? null
          : () => _showProfilePhotoZoom(
                context,
                user: user,
                enabled: true,
              ),
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner + avatar + nickname in ONE Stack.
        //
        // The Stack must CONTAIN every child: a child rendered outside its
        // parent's bounds is not hit-testable, so a photo hanging past the
        // bottom would stop responding to tap/long-press. Its height is
        // therefore banner + the avatar's lower half.
        //
        // The nickname is positioned INSIDE this Stack (not in a following
        // row) so it sits beside the photo's lower half — in the strip that
        // the avatar straddles — instead of being pushed below the photo.
        SizedBox(
          // The strip below the banner must fit the avatar's lower half AND
          // the nickname + the small `#id` that sit beside it — hence the
          // extra room when the id is present.
          height: _bannerHeight +
              _avatarBox / 2 +
              (user.publicIdText != null ? _publicIdExtra : 0),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _bannerHeight,
                child: _ProfileBanner(user: user, height: _bannerHeight),
              ),
              // Straddles the banner's lower edge: half above, half below.
              Positioned(
                left: AppDimensions.spaceXl,
                top: _bannerHeight - (_avatarBox / 2),
                child: tappableAvatar,
              ),
              // Right of the photo, vertically aligned with its lower half:
              // the nickname, with the small public `#id` right below it.
              Positioned(
                left: AppDimensions.spaceXl + _avatarBox + AppDimensions.spaceLg,
                right: AppDimensions.spaceXl,
                top: _bannerHeight + AppDimensions.spaceSm,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nickname, style: AppTextStyles.h2.copyWith(fontSize: 22)),
                    // The public `#id`, deliberately much smaller than the
                    // nickname — an identifier, not a second title.
                    if (user.publicIdText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user.publicIdText!,
                          style: AppTextStyles.hud.copyWith(
                            fontSize: 11,
                            color: AppColors.holographicBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Below the photo/#id: the pinned song (⏯️ button + song name).
        if (user.music != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spaceXl,
              AppDimensions.spaceMd,
              AppDimensions.spaceXl,
              0,
            ),
            child: ProfileMusicBar(key: musicKey, music: user.music!),
          ),
        // Below the photo AND the nickname: the bio.
        if (user.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spaceXl,
              AppDimensions.spaceSm,
              AppDimensions.spaceXl,
              0,
            ),
            child: Text(
              user.bio,
              textAlign: TextAlign.start,
              style: AppTextStyles.bodyMuted,
            ),
          ),
        // Then the real counters (server): followers/following open sheets.
        const SizedBox(height: AppDimensions.spaceXl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileStats(
                user: user,
                onFollowersTap: onFollowersTap,
                onFollowingTap: onFollowingTap,
              ),
              const SizedBox(height: AppDimensions.spaceXl),
              if (isOwn)
                YazzokiButton(
                  label: 'Editar perfil',
                  icon: Icons.edit_rounded,
                  variant: YazzokiButtonVariant.outline,
                  expanded: true,
                  onPressed: onEdit,
                )
              else if (follow?.isFollowing == true)
                // Following → two equal buttons side by side: Seguindo
                // (tap = unfollow) + Mensagem.
                Row(
                  children: [
                    Expanded(
                      child: FollowButton(
                        userId: user.id,
                        nickname: user.nickname,
                        follow: follow,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: YazzokiButton(
                        label: 'Mensagem',
                        icon: Icons.chat_bubble_rounded,
                        onPressed: onMessage,
                      ),
                    ),
                  ],
                )
              else
                FollowButton(
                  userId: user.id,
                  nickname: user.nickname,
                  follow: follow,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The wide profile cover.
///
/// Renders the user's banner image when set; otherwise a deterministic
/// gradient derived from the nickname (same seed idea as the fallback
/// avatar), so every profile looks intentional even without a banner.
/// The image is clipped and always `BoxFit.cover` — never distorted.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.user, required this.height});

  final YazzokiUser user;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = user.bannerUrl;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: bannerUrl != null && bannerUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: ApiConfig.resolveUrl(bannerUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
              placeholder: (_, __) => _fallback(context),
              errorWidget: (_, __, ___) => _fallback(context),
            )
          : _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    // Deterministic hue per user so the default cover is stable across
    // rebuilds and unique-ish per profile.
    final seed = user.avatarSeed ?? user.nickname;
    final hue = (seed.codeUnits.fold<int>(0, (a, b) => a + b) * 7) % 360;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.28).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.12).toColor(),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Shows a large, centered, circular view of another user's profile photo
/// over the current interface. It is intentionally VIEW-ONLY: it never edits
/// the photo, never opens an image picker and never navigates. Tapping
/// OUTSIDE the circle closes it; tapping inside does nothing (avoids
/// accidental dismissal and conflicts with tap/long-press/navigation).
///
/// This is invoked ONLY from the profile screen's header when viewing
/// someone else's profile — it is not reachable from the feed, comments,
/// search, followers or any other surface.
void _showProfilePhotoZoom(
  BuildContext context, {
  required YazzokiUser user,
  required bool enabled,
}) {
  if (!enabled) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: true,
    builder: (dialogContext) {
      final screen = MediaQuery.sizeOf(dialogContext);
      final diameter = screen.shortestSide * 0.72;
      return GestureDetector(
        // Tapping the dark outside area closes it (the dialog barrier also
        // dismisses, but the explicit GestureDetector makes "tap outside the
        // circle" deterministic on every surface).
        onTap: () => Navigator.of(dialogContext).pop(),
        behavior: HitTestBehavior.opaque,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: GestureDetector(
              // Tapping INSIDE the photo does nothing — no accidental close.
              onTap: () {},
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      UserAvatar(
                        name: user.nickname,
                        seed: user.avatarSeed ?? user.nickname,
                        imageUrl: user.avatarUrl,
                        size: diameter,
                        ring: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Real counters row — Seguidores / Seguindo (tappable → follow-list sheets),
/// Curtidas and Posts. The numbers come from the server profile payload, so a
/// viewed profile always shows THAT user's counts, never the session user's.
class _ProfileStats extends StatelessWidget {
  const _ProfileStats({
    required this.user,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final YazzokiUser user;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    // Four counters must fit every phone width: each takes an equal share
    // (Expanded) so a long label/count shrinks instead of overflowing.
    return Row(
      children: [
        Expanded(
          child: _StatColumn(
            count: user.followersCount,
            label: 'Seguidores',
            onTap: onFollowersTap,
          ),
        ),
        Expanded(
          child: _StatColumn(
            count: user.followingCount,
            label: 'Seguindo',
            onTap: onFollowingTap,
          ),
        ),
        // Curtidas: total likes across all of the user's posts (read-only).
        Expanded(child: _StatColumn(count: user.likesCount, label: 'Curtidas')),
        Expanded(child: _StatColumn(count: user.postsCount, label: 'Posts')),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.count, required this.label, this.onTap});

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceMd,
          vertical: AppDimensions.spaceXs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              '$count',
              style: AppTextStyles.h3.copyWith(
                fontSize: 20,
                color: AppColors.electricBlue,
                shadows: const [
                  Shadow(color: AppColors.electricBlue, blurRadius: 12),
                ],
              ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: AppTextStyles.hud.copyWith(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating "+" button — only rendered on the own profile. Opens a
/// chooser for the TWO content types (Nova publicação / Novo Story) instead
/// of duplicating the button: the post flow itself is unchanged, and Story
/// reuses the same media picker/upload pipeline.
class CreatePostFab extends StatelessWidget {
  const CreatePostFab({super.key});

  Future<void> _openChooser(BuildContext context) async {
    final choice = await showModalBottomSheet<_CreateChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const _CreateChooserSheet(),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _CreateChoice.post:
        Navigator.of(context).pushNamed(AppRoutes.createPost);
      case _CreateChoice.story:
        Navigator.of(context).pushNamed(AppRoutes.createStory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlowContainer(
      glow: Glow.medium,
      color: AppColors.glowMedium,
      background: AppColors.primaryBlue,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => _openChooser(context),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spaceLg),
          child: Icon(Icons.add_rounded, size: 28, color: AppColors.techWhite),
        ),
      ),
    );
  }
}

/// Tipo de conteúdo escolhido no botão "+" do perfil.
enum _CreateChoice { post, story }

/// Sheet de escolha: Nova publicação ou Novo Story (pt-BR, ícones nativos).
class _CreateChooserSheet extends StatelessWidget {
  const _CreateChooserSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.spaceMd),
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceXs),
        decoration: BoxDecoration(
          color: AppColors.bluishBlack,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: AppColors.deepBlue),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChooserItem(
                icon: Icons.article_rounded,
                label: 'Nova publicação',
                onTap: () => Navigator.of(context).pop(_CreateChoice.post),
              ),
              _ChooserItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Novo Story',
                onTap: () => Navigator.of(context).pop(_CreateChoice.story),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChooserItem extends StatelessWidget {
  const _ChooserItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLg,
          vertical: AppDimensions.spaceMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.electricBlue, size: 20),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(color: AppColors.techWhite),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable grid tile for a profile post. Opens the post detail screen.
/// The two profile tabs — Posts (left half) and Reposts (right half), each
/// taking exactly 2/4 and 3/4 of the width as equal halves. The controller
/// comes from the screen so the TabBarView below stays in sync (swiping the
/// grid also moves the underline).
class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({
    required this.controller,
    required this.postsCount,
    required this.repostsCount,
  });

  final TabController controller;
  final int postsCount;
  final int repostsCount;

  @override
  Widget build(BuildContext context) {
    // Mais respiro: as abas ganham altura própria e ficam ABAIXO dos
    // contadores, sem disputar espaço com nada acima.
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spaceSm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.deepBlue, width: 1),
        ),
      ),
      child: TabBar(
        controller: controller,
        // Mais alto para os ícones maiores não ficarem apertados.
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: AppColors.electricBlue,
        indicatorWeight: 2,
        labelColor: AppColors.techWhite,
        unselectedLabelColor: AppColors.holographicBlue,
        labelStyle: AppTextStyles.hud.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTextStyles.hud.copyWith(fontSize: 12),
        // DRAWN marks (never an emoji/glyph): a grid for Posts and the
        // chasing arrows for Reposts. The count rides next to each mark.
        tabs: [
          _ProfileTab(
            icon: (c) => GridIcon(color: c, size: 23),
            count: postsCount,
            label: 'POSTS',
          ),
          _ProfileTab(
            icon: (c) => RepostIcon(color: c, size: 23, strokeWidth: 1.7),
            count: repostsCount,
            label: 'REPOSTS',
          ),
        ],
      ),
    );
  }
}

/// One profile tab: a DRAWN mark + the item count (and a discreet label for
/// accessibility). The mark takes the active/inactive colour from the TabBar.
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.icon,
    required this.count,
    required this.label,
  });

  final Widget Function(Color color) icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    // TabBarTheme resolves the active/inactive colour for us.
    final color = DefaultTextStyle.of(context).style.color ??
        AppColors.holographicBlue;
    return Semantics(
      label: label,
      // Altura mínima para os ícones maiores respirarem sem apertar.
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon(color),
            const SizedBox(height: AppDimensions.spaceXs),
            Text('$count', style: AppTextStyles.hud.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// The scrollable grid of ONE tab (posts or reposts). Kept as a separate
/// widget so the two tabs share the exact layout and empty state.
class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({
    required this.posts,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onOpen,
  });

  final List<Post> posts;
  final String emptyTitle;
  final String emptySubtitle;
  final void Function(Post) onOpen;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(top: AppDimensions.spaceHuge),
          child: EmptyState(
            icon: Icons.grid_view_rounded,
            title: emptyTitle,
            hud: 'SYSTEM WAITING...',
            subtitle: emptySubtitle,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceLg,
        vertical: AppDimensions.spaceMd,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimensions.spaceMd,
        crossAxisSpacing: AppDimensions.spaceMd,
        childAspectRatio: 0.9,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        return _ProfilePostTile(post: post, onTap: () => onOpen(post));
      },
    );
  }
}

class _ProfilePostTile extends StatelessWidget {
  const _ProfilePostTile({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bluishBlack,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (post.isVideo)
                _VideoThumb(post)
              else if (post.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: ApiConfig.resolveUrl(post.imageUrl!),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              else
                _placeholder(),
              // "Repostado de @x" — only on the Reposts tab (the server sets
              // repostedBy). The NAME is clickable and styled as a mention,
              // so it is obvious that tapping goes to the reposter's post.
              if (post.repostedBy != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceSm,
                      vertical: AppDimensions.spaceXs,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        RepostIcon(
                          color: AppColors.holographicBlue,
                          size: 12,
                          strokeWidth: 1.5,
                        ),
                        const SizedBox(width: AppDimensions.spaceXs),
                        Expanded(
                          child: GestureDetector(
                            // Wins the tap over the tile's open-detail InkWell.
                            onTap: () => openProfileById(
                              context,
                              id: post.repostedBy!.id,
                              nickname: post.repostedBy!.nickname,
                            ),
                            behavior: HitTestBehavior.opaque,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Repostado de ',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.holographicBlue,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '@${post.repostedBy!.nickname}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.electricBlue,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.electricBlue,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      // The heart reflects the REAL like state, the same
                      // everywhere (feed, detail, profile): filled when the
                      // authenticated user liked the post, empty otherwise —
                      // driven by post.liked, which the server computes from
                      // the AUTHENTICATED token user.
                      Icon(
                        post.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: post.liked
                            ? AppColors.error
                            : AppColors.holographicBlue,
                        size: 14,
                      ),
                      const SizedBox(width: AppDimensions.spaceXs),
                      Text('${post.likes}', style: AppTextStyles.caption),
                      const SizedBox(width: AppDimensions.spaceMd),
                      Icon(Icons.chat_bubble_outline_rounded,
                          color: AppColors.holographicBlue, size: 13),
                      const SizedBox(width: AppDimensions.spaceXs),
                      Text('${post.commentCount}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.nightBlue,
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      alignment: Alignment.center,
      child: Text(
        post.text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      ),
    );
  }
}

/// Square grid tile for VIDEO posts in the profile grid.
///
/// * With a persisted [Post.thumbnailUrl] → the server cover (crisp, no
///   empty space), same as the feed.
/// * Old videos without a cover → the [VideoCoverService] lazily builds one
///   from the same `video_thumbnail` pipeline the create-post flow uses
///   (once per URL, cached) while the tile shows a clear video placeholder.
/// * Always a play badge so the media reads as a video.
class _VideoThumb extends StatefulWidget {
  const _VideoThumb(this.post);

  final Post post;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  Uint8List? _lazyCover;
  String? _lazyVideoUrl;

  @override
  void initState() {
    super.initState();
    _maybeLoadLazyCover();
  }

  @override
  void didUpdateWidget(covariant _VideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.videoUrl != widget.post.videoUrl ||
        oldWidget.post.thumbnailUrl != widget.post.thumbnailUrl) {
      _lazyCover = null;
      _maybeLoadLazyCover();
    }
  }

  /// Only OLD videos (no persisted cover) get a lazily built cover — new
  /// videos use [Post.thumbnailUrl] directly and never hit this path.
  void _maybeLoadLazyCover() {
    final post = widget.post;
    final cover = post.thumbnailUrl;
    if (cover != null && cover.isNotEmpty) return;
    final video = post.videoUrl;
    if (video == null || video.isEmpty) return;
    final resolved = ApiConfig.resolveUrl(video);
    if (resolved == _lazyVideoUrl && _lazyCover != null) return;
    _lazyVideoUrl = resolved;
    VideoCoverService.instance.coverFor(resolved).then((bytes) {
      if (!mounted) return;
      setState(() => _lazyCover = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.post.thumbnailUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover != null && cover.isNotEmpty)
          CachedNetworkImage(
            imageUrl: ApiConfig.resolveUrl(cover),
            fit: BoxFit.cover,
            placeholder: (_, __) => _videoPlaceholder(),
            errorWidget: (_, __, ___) => _videoPlaceholder(),
          )
        else if (_lazyCover != null)
          // Lazily generated cover for old videos. Image.memory — the bytes
          // are already downloaded by the service; gapless so the tile never
          // flashes while they resolve.
          Image.memory(
            _lazyCover!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          )
        else
          _videoPlaceholder(),
        Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: AppColors.holographicBlue, size: 34),
        ),
      ],
    );
  }

  /// Clear video identification (works in both themes): an icon + label so a
  /// video without a cover never looks like an empty/black frame. Auto-adapts
  /// through AppColors' active palette.
  Widget _videoPlaceholder() {
    return Container(
      color: AppColors.nightBlue,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded,
              color: AppColors.holographicBlue, size: 26),
          const SizedBox(height: 6),
          Text('VÍDEO',
              style: AppTextStyles.hud
                  .copyWith(color: AppColors.holographicBlue)),
        ],
      ),
    );
  }
}
