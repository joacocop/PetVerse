import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import '../models/post_comment.dart';

/// Contrato compartido por el feed real y la demostración en memoria.
abstract interface class FeedService {
  /// Escucha las publicaciones, de la más reciente a la más antigua.
  Stream<List<Post>> watchPosts();
  /// Publica un momento de una mascota con autor y fecha.
  Future<void> createPost(Post post);
  /// Aplica una reacción idempotente sin sobrescribir las de otros usuarios.
  Future<void> setLiked(String postId, String userId, bool liked);
  /// Escucha los comentarios en orden de creación.
  Stream<List<PostComment>> watchComments(String postId);
  /// Agrega un comentario a una publicación existente.
  Future<void> addComment(PostComment comment);
  /// Elimina un comentario propio; el servidor vuelve a verificar su autor.
  Future<void> deleteComment(PostComment comment, String userId);
  /// Libera los canales locales al destruir el provider.
  void dispose();
}

/// Los snapshots difunden publicaciones, likes y comentarios entre clientes.
class FirestoreFeedService implements FeedService {
  FirestoreFeedService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  @override
  Stream<List<Post>> watchPosts() => _posts
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => List.unmodifiable(
            snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())),
          ));

  @override
  Future<void> createPost(Post post) => _posts.add({
        ...post.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': <String>[],
      });

  @override
  Future<void> setLiked(String postId, String userId, bool liked) =>
      _posts.doc(postId).update({
        // Transformaciones atómicas: un usuario no suma dos veces ni borra
        // los likes de otros clientes concurrentes.
        'likes': liked
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });

  @override
  Stream<List<PostComment>> watchComments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((snapshot) => List.unmodifiable(snapshot.docs.map(
            (doc) => PostComment.fromMap(doc.id, postId, doc.data()),
          )));

  @override
  Future<void> addComment(PostComment comment) =>
      _posts.doc(comment.postId).collection('comments').add({
        ...comment.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteComment(PostComment comment, String userId) {
    if (comment.authorId != userId) {
      throw StateError('Solo puedes eliminar tus propios comentarios.');
    }
    return _posts
        .doc(comment.postId)
        .collection('comments')
        .doc(comment.id)
        .delete();
  }

  @override
  void dispose() {}
}

/// Repositorio compartido en memoria para probar las mismas interacciones.
class DemoFeedService implements FeedService {
  final Map<String, Post> _posts = {};
  final Map<String, List<PostComment>> _comments = {};
  final _postChanges = StreamController<void>.broadcast();
  final _commentChanges = StreamController<String>.broadcast();
  int _nextId = 0;

  List<Post> get _sortedPosts => List.unmodifiable(_posts.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Stream<List<Post>> watchPosts() => Stream<List<Post>>.multi((listener) {
        // Suscribir antes de emitir el estado inicial evita perder cambios.
        final subscription = _postChanges.stream.listen(
          (_) => listener.add(_sortedPosts),
          onDone: listener.close,
        );
        listener.add(_sortedPosts);
        listener.onCancel = subscription.cancel;
      });

  @override
  Future<void> createPost(Post post) async {
    final id = 'demo_post_${++_nextId}';
    _posts[id] = post.copyWith(id: id, likedBy: {});
    _postChanges.add(null);
  }

  @override
  Future<void> setLiked(String postId, String userId, bool liked) async {
    final post = _posts[postId];
    if (post == null) throw StateError('La publicación ya no existe.');
    final users = {...post.likedBy};
    if (liked) {
      users.add(userId);
    } else {
      users.remove(userId);
    }
    _posts[postId] = post.copyWith(likedBy: users);
    _postChanges.add(null);
  }

  @override
  Stream<List<PostComment>> watchComments(String postId) =>
      Stream<List<PostComment>>.multi((listener) {
        List<PostComment> current() =>
            List.unmodifiable((_comments[postId] ?? []).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
        final subscription = _commentChanges.stream.listen(
          (changedId) {
            if (changedId == postId) listener.add(current());
          },
          onDone: listener.close,
        );
        listener.add(current());
        listener.onCancel = subscription.cancel;
      });

  @override
  Future<void> addComment(PostComment comment) async {
    if (!_posts.containsKey(comment.postId)) {
      throw StateError('La publicación ya no existe.');
    }
    _comments.putIfAbsent(comment.postId, () => []).add(
          comment.withId('demo_comment_${++_nextId}'),
        );
    _commentChanges.add(comment.postId);
  }

  @override
  Future<void> deleteComment(PostComment comment, String userId) async {
    final existing = (_comments[comment.postId] ?? [])
        .where((item) => item.id == comment.id);
    if (existing.isEmpty) return;
    if (existing.first.authorId != userId) {
      throw StateError('Solo puedes eliminar tus propios comentarios.');
    }
    _comments[comment.postId]!.removeWhere((item) => item.id == comment.id);
    _commentChanges.add(comment.postId);
  }

  @override
  void dispose() {
    _postChanges.close();
    _commentChanges.close();
  }
}
