/// A Yazzoki notification (like, comment, follow, repost, story repost).
///
/// The server owns notification creation; the APK only renders them. Every
/// notification embeds the acting user (actor) so no second lookup is
/// needed, and may reference a post / comment / story.
class YazzokiNotification {
  const YazzokiNotification({
    required this.id,
    required this.type,
    required this.read,
    required this.createdAt,
    required this.actorId,
    required this.actorNickname,
    this.actorAvatarUrl,
    this.postId,
    this.commentId,
    this.storyId,
  });

  final String id;

  /// LIKE | COMMENT | FOLLOW | REPOST | STORY_REPOST — extensible on the
  /// server, so we keep it as a plain string.
  final String type;
  final bool read;
  final DateTime createdAt;

  final String actorId;

  /// The acting user's nickname — rendered as plain text (never '@').
  final String actorNickname;
  final String? actorAvatarUrl;

  final String? postId;
  final String? commentId;

  /// Set for STORY_REPOST: the story the notification refers to.
  final String? storyId;

  YazzokiNotification copyWith({bool? read}) => YazzokiNotification(
        id: id,
        type: type,
        read: read ?? this.read,
        createdAt: createdAt,
        actorId: actorId,
        actorNickname: actorNickname,
        actorAvatarUrl: actorAvatarUrl,
        postId: postId,
        commentId: commentId,
        storyId: storyId,
      );
}
