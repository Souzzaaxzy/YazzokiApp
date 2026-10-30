import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/glow_container.dart';
import '../../data/api_config.dart';
import '../../models/follow.dart';

/// The follow button — the Instagram model, driven by the server state:
///
///   SEGUIR            → tap → follows instantly → SEGUINDO
///   SEGUINDO          → tap → unfollows instantly → SEGUIR
///   SEGUIR DE VOLTA   → they follow you, you don't → tap → MÚTUO (Seguindo)
///
/// There is no approval step: every transition is confirmed by the server
/// first, so closing/reopening the app or screen never desyncs the button.
/// The state comes from the loaded profile's `follow`, never a local flag.
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.userId,
    required this.nickname,
    required this.follow,
  });

  final String userId;
  final String nickname;
  final FollowState? follow;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _busy = false;

  FollowState get _state => widget.follow ?? FollowState.none;

  Future<void> _run(Future<void> Function(AppState state) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    try {
      await action(state);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de conexão.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleTap() {
    // Follow is instant and one-directional: the same tap follows when not
    // following and unfollows when already following.
    if (_state.isFollowing) {
      _run((s) => s.unfollowUser(widget.userId));
    } else {
      _run((s) => s.followUser(widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: _buildButton(keyName: _state.name),
    );
  }

  Widget _buildButton({required String keyName}) {
    final label = switch (_state) {
      FollowState.none => 'SEGUIR',
      FollowState.following => 'SEGUINDO',
      FollowState.mutual => 'SEGUINDO',
      FollowState.followsYou => 'SEGUIR DE VOLTA',
    };
    final icon = switch (_state) {
      FollowState.none => Icons.person_add_alt_1_rounded,
      FollowState.following => Icons.check_rounded,
      FollowState.mutual => Icons.check_rounded,
      FollowState.followsYou => Icons.person_add_alt_1_rounded,
    };
    final isFollowing = _state.isFollowing;

    return _StateButton(
      key: ValueKey(keyName),
      label: label,
      icon: icon,
      isLoading: _busy,
      onPressed: _busy ? null : _handleTap,
      variant:
          isFollowing ? _StateButtonVariant.outline : _StateButtonVariant.filled,
    );
  }
}

/// A self-contained neon button with press-scale and dark/light support.
/// Uses the same language as Yazzoki's [GlowContainer] + icon + label.
class _StateButton extends StatefulWidget {
  const _StateButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.variant,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _StateButtonVariant variant;
  final bool isLoading;

  @override
  State<_StateButton> createState() => _StateButtonState();
}

class _StateButtonState extends State<_StateButton> {
  bool _pressing = false;

  bool get _disabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isOutline = widget.variant == _StateButtonVariant.outline;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) => setState(() => _pressing = false),
      onTapCancel: () => setState(() => _pressing = false),
      onTap: _disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: GlowContainer(
          glow: _pressing ? Glow.medium : Glow.none,
          background: isOutline
              ? Colors.transparent
              : _disabled
                  ? AppColors.deepBlue.withValues(alpha: 0.5)
                  : AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: isOutline
              ? Border.all(
                  color: AppColors.techWhite.withValues(alpha: 0.4),
                  width: AppDimensions.borderWidthActive,
                )
              : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceXl,
            vertical: AppDimensions.spaceLg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 18, color: AppColors.techWhite),
                const SizedBox(width: AppDimensions.spaceSm),
                if (widget.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.techWhite),
                    ),
                  )
                else
                  Text(
                    widget.label,
                    style: AppTextStyles.button,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _StateButtonVariant { filled, outline }
