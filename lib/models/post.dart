import 'package:cloud_firestore/cloud_firestore.dart';

/// Medio que se muestra en una publicación.
enum PostMediaType { image, video }

/// Publicación compartida con todos los usuarios autenticados.
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.petId,
    required this.petName,
    required this.caption,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    this.likedBy = const {},
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String petId;
  final String petName;
  final String caption;
  final String mediaUrl;
  final PostMediaType mediaType;
  final DateTime createdAt;
  final Set<String> likedBy;

  int get likeCount => likedBy.length;
  bool isLikedBy(String userId) => likedBy.contains(userId);

  factory Post.fromMap(String id, Map<String, dynamic> map) => Post(
        id: id,
        authorId: map['ownerId'] as String,
        authorName: map['authorName'] as String,
        authorPhotoUrl: map['authorPhotoUrl'] as String? ?? '',
        petId: map['petId'] as String,
        petName: map['petName'] as String,
        caption: map['caption'] as String? ?? '',
        mediaUrl: map['imageUrl'] as String,
        mediaType: PostMediaType.values.byName(map['mediaType'] as String),
        createdAt: documentDate(map['createdAt']),
        likedBy: Set.unmodifiable(
          (map['likes'] as List<dynamic>? ?? const []).cast<String>(),
        ),
      );

  Map<String, dynamic> toMap() => {
        'ownerId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'petId': petId,
        'petName': petName,
        'caption': caption,
        'imageUrl': mediaUrl,
        'mediaType': mediaType.name,
        'createdAt': createdAt,
        'likes': likedBy.toList(),
      };

  Post copyWith({String? id, Set<String>? likedBy}) => Post(
        id: id ?? this.id,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        petId: petId,
        petName: petName,
        caption: caption,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: createdAt,
        likedBy: likedBy == null ? this.likedBy : Set.unmodifiable(likedBy),
      );
}

/// Admite fechas locales y marcas de tiempo de Firestore, incluso pendientes.
DateTime documentDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
