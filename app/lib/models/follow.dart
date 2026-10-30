/// The viewer's relationship to another user's profile — the Instagram-style
/// follow model (no approval step, unlike the old friend requests).
enum FollowState {
  /// Neither follows the other.
  none,

  /// The viewer follows the profile owner.
  following,

  /// The profile owner follows the viewer (a "Seguir de volta" hint).
  followsYou,

  /// Both directions.
  mutual;

  static FollowState fromApi(String? value) {
    switch (value) {
      case 'FOLLOWING':
        return FollowState.following;
      case 'FOLLOWS_YOU':
        return FollowState.followsYou;
      case 'MUTUAL':
        return FollowState.mutual;
      default:
        return FollowState.none;
    }
  }

  /// True when the viewer already follows the profile owner.
  bool get isFollowing => this == following || this == mutual;
}
