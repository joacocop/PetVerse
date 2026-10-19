import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/post.dart';
import '../models/post_comment.dart';
import '../services/feed_service.dart';

/// Estado del feed y sus operaciones, asociado a la sesión autenticada.
class FeedProvider extends ChangeNotifier {
  FeedProvider({required this._service});

  final FeedService _service;
  StreamSubscription<List<Post>>? _subscription;
  List<Post> _posts = const [];
  String? _userId;
  int _session = 0;
  bool _disposed = false;
  bool _isLoading = false;
  bool _isPublishing = false;
  final Set<String> _pendingLikes = {};
  String? _feedError;
  String? _actionError;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isPublishing => _isPublishing;
  String? get feedError => _feedError;
  String? get actionError => _actionError;
  bool isLiking(String postId) => _pendingLikes.contains(postId);

  /// Lo llama el ProxyProvider durante la composición; los snapshots notifican
  /// asincrónicamente y nunca conservan datos de una sesión anterior.
  void bindUser(String? userId, {bool force = false}) {
    if (_userId == userId && !force) return;
    final session = ++_session;
    _subscription?.cancel();
    _subscription = null;
    _userId = userId;
    _posts = const [];
    _pendingLikes.clear();
    _feedError = null;
    _actionError = null;
    _isPublishing = false;
    _isLoading = userId != null;
    if (userId == null) return;
    _subscription = _service.watchPosts().listen((posts) {
      if (_disposed || session != _session) return;
      _posts = posts;
      _feedError = null;
      _isLoading = false;
      notifyListeners();
    }, onError: (Object error) {
      if (_disposed || session != _session) return;
      _feedError = _message(error);
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Restablece la suscripción luego de un error de lectura.
  void retry() {
    bindUser(_userId, force: true);
    notifyListeners();
  }

  /// Valida y publica el contenido del formulario.
  Future<bool> publish({
    required String petId,
    required String petName,
    required String authorName,
    required String authorPhotoUrl,
    required String caption,
    required String mediaUrl,
    required PostMediaType mediaType,
  }) async {
    final userId = _userId;
    if (userId == null || _isPublishing) return false;
    final session = _session;
    if (petId.isEmpty) {
      _actionError = 'Selecciona una de tus mascotas.';
      notifyListeners();
      return false;
    }
    final uri = Uri.tryParse(mediaUrl.trim());
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      _actionError = 'Ingresa una URL válida de imagen o video.';
      notifyListeners();
      return false;
    }
    if (caption.trim().length > 2200) {
      _actionError = 'El texto admite hasta 2200 caracteres.';
      notifyListeners();
      return false;
    }
    _isPublishing = true;
    final success = await _run(() => _service.createPost(Post(
          id: '',
          authorId: userId,
          authorName: authorName,
          authorPhotoUrl: authorPhotoUrl,
          petId: petId,
          petName: petName,
          caption: caption.trim(),
          mediaUrl: mediaUrl.trim(),
          mediaType: mediaType,
          createdAt: DateTime.now(),
        )));
    if (!_disposed && session == _session) {
      _isPublishing = false;
      notifyListeners();
    }
    return success;
  }

  /// Alterna el botón; un doble toque indica explícitamente liked: true.
  Future<bool> like(Post post, {bool? liked}) async {
    final userId = _userId;
    final session = _session;
    if (userId == null || isLiking(post.id)) return false;
    final shouldLike = liked ?? !post.isLikedBy(userId);
    if (post.isLikedBy(userId) == shouldLike) return true;
    _pendingLikes.add(post.id);
    final result = await _run(
      () => _service.setLiked(post.id, userId, shouldLike),
    );
    if (!_disposed && session == _session) {
      _pendingLikes.remove(post.id);
      notifyListeners();
    }
    return result;
  }

  /// Crea el stream que conserva cada sección de comentarios abierta.
  Stream<List<PostComment>> commentsFor(String postId) =>
      _service.watchComments(postId);

  /// Agrega texto no vacío usando la identidad de la sesión actual.
  Future<bool> comment({
    required String postId,
    required String authorName,
    required String authorPhotoUrl,
    required String text,
  }) {
    final userId = _userId;
    if (userId == null) return Future.value(false);
    if (text.trim().isEmpty || text.trim().length > 1000) {
      _actionError = 'El comentario debe tener entre 1 y 1000 caracteres.';
      notifyListeners();
      return Future.value(false);
    }
    return _run(() => _service.addComment(PostComment(
          id: '',
          postId: postId,
          authorId: userId,
          authorName: authorName,
          authorPhotoUrl: authorPhotoUrl,
          text: text.trim(),
          createdAt: DateTime.now(),
        )));
  }

  /// Solicita eliminar un comentario y conserva cualquier error en pantalla.
  Future<bool> deleteComment(PostComment comment) {
    final userId = _userId;
    if (userId == null) return Future.value(false);
    return _run(() => _service.deleteComment(comment, userId));
  }

  Future<bool> _run(Future<void> Function() action) async {
    final session = _session;
    _actionError = null;
    notifyListeners();
    try {
      await action();
      return !_disposed && session == _session;
    } on Object catch (error) {
      if (!_disposed && session == _session) {
        _actionError = _message(error);
        notifyListeners();
      }
      return false;
    }
  }

  String _message(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'No tienes permiso para realizar esta acción con tu sesión actual.';
    }
    return 'No se pudo completar la operación. Intenta nuevamente.';
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
