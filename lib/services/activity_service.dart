import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamification.dart';

/// Lectura de créditos privados; el feed los escribe junto con cada acción.
abstract interface class ActivityService {
  /// Escucha únicamente el historial del usuario autenticado.
  Stream<List<Activity>> watch(String uid);

  /// Libera los recursos locales.
  void dispose();
}

/// Las reglas verifican las fuentes y bloquean créditos duplicados o falsificados.
class FirestoreActivityService implements ActivityService {
  /// Permite inyectar una conexión para pruebas.
  FirestoreActivityService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  @override
  Stream<List<Activity>> watch(String uid) => _db
      .collection('users/$uid/activity')
      .snapshots()
      .map((s) => s.docs.map((d) => Activity.fromMap(d.id, d.data())).toList());
  @override
  void dispose() {}
}

/// Equivalente en memoria: conserva créditos al quitar un like o borrar un comentario.
class DemoActivityService implements ActivityService {
  final _credits = <String, Map<String, Activity>>{};
  final _changes = StreamController<String>.broadcast();

  /// Acredita una única vez una clase de acción por publicación.
  void award(
    String uid,
    ActivityKind kind,
    String postId, {
    String referenceId = '',
  }) {
    final id = '${kind.name}_$postId';
    final credits = _credits.putIfAbsent(uid, () => {});
    if (credits.containsKey(id)) return;
    credits[id] = Activity(
      id: id,
      kind: kind,
      postId: postId,
      referenceId: referenceId,
      createdAt: DateTime.now(),
    );
    _changes.add(uid);
  }

  @override
  Stream<List<Activity>> watch(String uid) => Stream.multi((controller) {
    List<Activity> read() =>
        List.unmodifiable(_credits[uid]?.values ?? const <Activity>[]);
    final sub = _changes.stream.listen((changed) {
      if (changed == uid) controller.add(read());
    }, onDone: controller.close);
    controller.add(read());
    controller.onCancel = sub.cancel;
  });
  @override
  void dispose() {
    _changes.close();
  }
}
