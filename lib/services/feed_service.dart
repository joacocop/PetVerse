import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/gamification.dart';
import 'activity_service.dart';

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
      .map(
        (snapshot) => List.unmodifiable(
          snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())),
        ),
      );

  @override
  Future<void> createPost(Post post) async {
    final ref = _posts.doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      ...post.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'likes': <String>[],
    });
    batch.set(
      _credit(post.authorId, ActivityKind.post, ref.id),
      _creditData(ActivityKind.post, ref.id),
    );
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _credit(
    String uid,
    ActivityKind kind,
    String postId,
  ) => _firestore.doc('users/$uid/activity/${kind.name}_$postId');
  Map<String, dynamic> _creditData(
    ActivityKind kind,
    String postId, {
    String referenceId = '',
  }) => {
    'kind': kind.name,
    'postId': postId,
    'referenceId': referenceId,
    'createdAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> setLiked(String postId, String userId, bool liked) async {
    final ref = _posts.doc(postId);
    if (!liked) {
      await ref.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
      return;
    }
    // La transacción serializa acciones concurrentes y evita acreditar otra
    // vez después de quitar/reponer la reacción, incluso desde otra pestaña.
    await _firestore.runTransaction((tx) async {
      final post = await tx.get(ref);
      final credit = _credit(userId, ActivityKind.like, postId);
      final earned = await tx.get(credit);
      tx.update(ref, {
        'likes': FieldValue.arrayUnion([userId]),
      });
      if (!earned.exists && post.data()?['ownerId'] != userId) {
        tx.set(credit, _creditData(ActivityKind.like, postId));
      }
    });
  }

  @override
  Stream<List<PostComment>> watchComments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) => List.unmodifiable(
          snapshot.docs.map(
            (doc) => PostComment.fromMap(doc.id, postId, doc.data()),
          ),
        ),
      );

  @override
  Future<void> addComment(PostComment comment) async {
    final postRef = _posts.doc(comment.postId);
    final ref = postRef.collection('comments').doc();
    final credit = _credit(
      comment.authorId,
      ActivityKind.comment,
      comment.postId,
    );
    await _firestore.runTransaction((tx) async {
      final post = await tx.get(postRef);
      final earned = await tx.get(credit);
      tx.set(ref, {
        ...comment.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!earned.exists && post.data()?['ownerId'] != comment.authorId) {
        tx.set(
          credit,
          _creditData(
            ActivityKind.comment,
            comment.postId,
            referenceId: ref.id,
          ),
        );
      }
    });
  }

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
  /// Comparte el historial de logros con el provider demo de la aplicación.
  DemoFeedService({DemoActivityService? activityService})
    : _activity = activityService ?? DemoActivityService(),
      _ownsActivity = activityService == null;
  final DemoActivityService _activity;
  final bool _ownsActivity;
  final Map<String, Post> _posts = {};
  final Map<String, List<PostComment>> _comments = {};
  final _postChanges = StreamController<void>.broadcast();
  final _commentChanges = StreamController<String>.broadcast();
  int _nextId = 0;

  List<Post> get _sortedPosts => List.unmodifiable(
    _posts.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

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
    _activity.award(post.authorId, ActivityKind.post, id);
    _postChanges.add(null);
  }

  @override
  Future<void> setLiked(String postId, String userId, bool liked) async {
    final post = _posts[postId];
    if (post == null) throw StateError('La publicación ya no existe.');
    final users = {...post.likedBy};
    if (liked) {
      users.add(userId);
      if (post.authorId != userId) {
        _activity.award(userId, ActivityKind.like, postId);
      }
    } else {
      users.remove(userId);
    }
    _posts[postId] = post.copyWith(likedBy: users);
    _postChanges.add(null);
  }

  @override
  Stream<List<PostComment>> watchComments(String postId) =>
      Stream<List<PostComment>>.multi((listener) {
        List<PostComment> current() => List.unmodifiable(
          (_comments[postId] ?? []).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
        final subscription = _commentChanges.stream.listen((changedId) {
          if (changedId == postId) listener.add(current());
        }, onDone: listener.close);
        listener.add(current());
        listener.onCancel = subscription.cancel;
      });

  @override
  Future<void> addComment(PostComment comment) async {
    if (!_posts.containsKey(comment.postId)) {
      throw StateError('La publicación ya no existe.');
    }
    final saved = comment.withId('demo_comment_${++_nextId}');
    _comments.putIfAbsent(comment.postId, () => []).add(saved);
    if (_posts[comment.postId]!.authorId != comment.authorId) {
      _activity.award(
        comment.authorId,
        ActivityKind.comment,
        comment.postId,
        referenceId: saved.id,
      );
    }
    _commentChanges.add(comment.postId);
  }

  @override
  Future<void> deleteComment(PostComment comment, String userId) async {
    final existing = (_comments[comment.postId] ?? []).where(
      (item) => item.id == comment.id,
    );
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
    if (_ownsActivity) _activity.dispose();
  }
}
