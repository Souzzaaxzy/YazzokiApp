import 'comment.dart';

/// A post in the Yazzoki feed.
class Post {
  Post({
    required this.id,
    required this.authorNickname,
    required this.text,
    required this.createdAt,
    this.authorId,
    this.avatarSeed,
    this.authorAvatarUrl,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.likes = 0,
    this.liked = false,
    this.commentCount = 0,
    this.comments = const [],
    this.repostCount = 0,
    this.reposted = false,
    this.reposters = const [],
    this.repostedBy,
  });

  /// Unique server-side id. ALL operations (like, comment, detail, delete)
  /// key off this — never off the position in a list.
  final String id;

  /// The author's nickname — the single visual identity, rendered as plain
  /// text (never '@').
  final String authorNickname;

  /// Server-side id of the author (stable; nickname is mutable).
  final String? authorId;
  final String text;
  final DateTime createdAt;
  final String? avatarSeed;

  /// Remote URL of the author's profile photo (null → initials fallback).
  final String? authorAvatarUrl;

  /// The AUTHOR's own nickname color (hex), embedded by the server. Null →
  /// default color. Never the viewer's color.

  /// The AUTHOR's own equipped profile frame (assets key, e.g.
  /// `frames/coroa`), embedded by the server with the post. Null → default.
  /// Never the viewer's frame.
  final String? imageUrl;

  /// Remote URL of the post's VIDEO (video posts). Mutually exclusive with
  /// [imageUrl] server-side.
  final String? videoUrl;

  /// Remote URL of the video's cover/thumbnail (video posts). Persisted
  /// server-side; old videos may have null → the UI falls back to a badge.
  final String? thumbnailUrl;

  /// Whether this post's media is a video.
  bool get isVideo => videoUrl != null && videoUrl!.isNotEmpty;

  int likes;
  bool liked;

  /// Server-reported comment count (the full comment list is loaded on
  /// demand by the comments sheet).
  int commentCount;
  List<Comment> comments;

  /// How many users reposted this post (share to profile).
  int repostCount;

  /// Whether the SESSION user reposted this post (drives the active button).
  bool reposted;

  /// WHO reposted this post (newest first, capped by the server). Powers the
  /// "X repostou" badge above the actions.
  List<ReposterUser> reposters;

  /// Set ONLY on the profile "Reposts" tab: who reposted it, for the
  /// clickable "Repostado de @x" line.
  ReposterUser? repostedBy;

  Post copyWith({
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
    int? likes,
    bool? liked,
    int? commentCount,
    List<Comment>? comments,
    int? repostCount,
    bool? reposted,
    List<ReposterUser>? reposters,
    ReposterUser? Function()? repostedBy,
  }) =>
      Post(
        id: id,
        authorNickname: authorNickname,
        authorId: authorId,
        text: text ?? this.text,
        createdAt: createdAt,
        avatarSeed: avatarSeed,
        authorAvatarUrl: authorAvatarUrl,
        imageUrl: imageUrl ?? this.imageUrl,
        videoUrl: videoUrl ?? this.videoUrl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        likes: likes ?? this.likes,
        liked: liked ?? this.liked,
        commentCount: commentCount ?? this.commentCount,
        comments: comments ?? this.comments,
        repostCount: repostCount ?? this.repostCount,
        reposted: reposted ?? this.reposted,
        reposters: reposters ?? this.reposters,
        repostedBy: repostedBy != null ? repostedBy() : this.repostedBy,
      );
}

/// A user who reposted a post (badge + "Repostado de" attribution).
class ReposterUser {
  const ReposterUser({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;

  static ReposterUser? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'] as String?;
    final nickname = json['nickname'] as String?;
    if (id == null || nickname == null) return null;
    return ReposterUser(
      id: id,
      nickname: nickname,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
