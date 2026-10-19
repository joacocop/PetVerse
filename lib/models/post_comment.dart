import 'post.dart';

/// Comentario de una publicación, con autor y fecha inmutables.
class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String text;
  final DateTime createdAt;

  factory PostComment.fromMap(
    String id,
    String postId,
    Map<String, dynamic> map,
  ) =>
      PostComment(
        id: id,
        postId: postId,
        authorId: map['userId'] as String,
        authorName: map['userName'] as String,
        authorPhotoUrl: map['userPhotoUrl'] as String? ?? '',
        text: map['text'] as String,
        createdAt: documentDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': authorId,
        'userName': authorName,
        'userPhotoUrl': authorPhotoUrl,
        'text': text,
        'createdAt': createdAt,
      };

  PostComment withId(String id) => PostComment(
        id: id,
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        text: text,
        createdAt: createdAt,
      );
}
