import 'yazzoki_user.dart';

/// One profile visitor: WHO came and WHEN (the last time they did).
///
/// The list is only ever served to the PROFILE OWNER — the server rejects any
/// other reader, so a user can never learn who visited someone else's profile.
class ProfileView {
  const ProfileView({
    required this.user,
    required this.viewedAt,
    this.views = 1,
  });

  final YazzokiUser user;

  /// How many times this user opened the profile.
  final int views;

  /// Last time this user opened the profile (server timestamp).
  final DateTime viewedAt;
}
