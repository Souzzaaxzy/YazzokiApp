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
    this.actorNicknameColor,
    this.actorFrameId,
    this.actorFrameAsset,
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

  /// The ACTOR's own nickname color (hex), embedded by the server. Null →
  /// default color.
  final String? actorNicknameColor;

  /// The ACTOR's own equipped profile frame (assets key), embedded by the
  /// server. Null → default. Never the viewer's frame.
  final String? actorFrameId;
  final String? actorFrameAsset;

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
        actorNicknameColor: actorNicknameColor,
        actorFrameId: actorFrameId,
        actorFrameAsset: actorFrameAsset,
        postId: postId,
        commentId: commentId,
        storyId: storyId,
      );
}
