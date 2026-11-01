import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/app_state.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/hud_label.dart';
import '../../core/widgets/profile_views_icon.dart';
import '../../core/widgets/theme_watcher.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/api_config.dart';
import '../../models/profile_view.dart';

/// "Quem viu seu perfil" — a bottom sheet listing everyone who opened the
/// OWNER's profile, with how long ago they came ("há N minutos/dias/…").
///
/// PRIVACY: the server only serves this list to the profile OWNER (403 for
/// anyone else), so the sheet is only ever opened from the own profile.
class ProfileViewsSheet extends StatefulWidget {
  const ProfileViewsSheet({super.key, required this.userId});

  final String userId;

  static Future<void> open(BuildContext context, String userId) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ThemeWatcher(
        builder: (_) => ProfileViewsSheet(userId: userId),
      ),
    );
  }

  @override
  State<ProfileViewsSheet> createState() => _ProfileViewsSheetState();
}

class _ProfileViewsSheetState extends State<ProfileViewsSheet> {
  late AppState _state;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppStateScope.of(context);
    if (!_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _state.loadProfileViews(widget.userId);
      });
    }
  }

  void _openUser(ProfileView view) {
    Navigator.of(context).pop();
    openProfileById(
      context,
      id: view.user.id,
      nickname: view.user.nickname,
    );
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
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: ListenableBuilder(
              listenable: _state,
              builder: (context, _) {
                final views = _state.profileViewsFor(widget.userId);
                final loading = _state.isLoadingProfileViews;
                return Column(
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
                          const ProfileViewsIcon(
                            color: AppColors.electricBlue,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimensions.spaceSm),
                          const Expanded(
                            child: HudLabel(text: 'Quem viu seu perfil'),
                          ),
                          Text(
                            '${views.length}',
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
                    Flexible(
                      child: _buildList(views, loading),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<ProfileView> views, bool loading) {
    if (views.isEmpty) {
      if (loading) {
        return const Padding(
          padding: EdgeInsets.all(AppDimensions.spaceXxl),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.electricBlue),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXxl),
        child: Center(
          child: Text(
            'Ninguém viu seu perfil ainda.',
            style: AppTextStyles.bodyMuted,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: views.length,
      separatorBuilder: (_, __) =>
          Divider(color: AppColors.deepBlue, height: 1, indent: 72),
      itemBuilder: (context, i) {
        final v = views[i];
        return ListTile(
          onTap: () => _openUser(v),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLg,
            vertical: 2,
          ),
          leading: UserAvatar(
            name: v.user.nickname,
            seed: v.user.nickname,
            imageUrl: v.user.avatarUrl == null
                ? null
                : ApiConfig.resolveUrl(v.user.avatarUrl!),
            size: 37,
          ),
          title: Text(v.user.nickname, style: AppTextStyles.body),
          subtitle: Text(
            viewedAgo(v.viewedAt),
            style: AppTextStyles.caption,
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.holographicBlue,
          ),
        );
      },
    );
  }
}

/// "A N minutos / A N horas / A N dias / A N semanas / A N meses / A N anos".
///
/// Pure function so the wording is unit-testable without a widget.
String viewedAgo(DateTime viewedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(viewedAt);
  if (diff.isNegative || diff.inSeconds < 60) return 'A poucos segundos';
  if (diff.inMinutes < 60) {
    final n = diff.inMinutes;
    return 'A $n ${n == 1 ? 'minuto' : 'minutos'}';
  }
  if (diff.inHours < 24) {
    final n = diff.inHours;
    return 'A $n ${n == 1 ? 'hora' : 'horas'}';
  }
  if (diff.inDays < 7) {
    final n = diff.inDays;
    return 'A $n ${n == 1 ? 'dia' : 'dias'}';
  }
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) {
    return 'A $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
  }
  final months = diff.inDays ~/ 30;
  if (months < 12) {
    return 'A $months ${months == 1 ? 'mês' : 'meses'}';
  }
  final years = diff.inDays ~/ 365;
  return 'A $years ${years == 1 ? 'ano' : 'anos'}';
}
