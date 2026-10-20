import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gamification.dart';
import '../services/activity_service.dart';

/// Estado de gamificación aislado por sesión, con cancelación de suscripciones.
class GamificationProvider extends ChangeNotifier {
  /// Recibe el repositorio real o demo.
  GamificationProvider({required this._service});
  final ActivityService _service;
  StreamSubscription<List<Activity>>? _subscription;
  String? _uid;
  int _session = 0;
  bool _disposed = false;
  Gamification summary = Gamification([]);
  bool loading = false;
  String? error;

  /// Cambia de cuenta sin mostrar puntos ni insignias de la sesión anterior.
  void bindUser(String? uid, {bool force = false}) {
    if (_uid == uid && !force) return;
    _uid = uid;
    final session = ++_session;
    _subscription?.cancel();
    summary = Gamification([]);
    error = null;
    loading = uid != null;
    if (uid == null) return;
    _subscription = _service
        .watch(uid)
        .listen(
          (activities) {
            if (_disposed || session != _session) return;
            summary = Gamification(activities);
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object _) {
            if (_disposed || session != _session) return;
            loading = false;
            error =
                'No se pudieron cargar tus logros. Revisá la conexión y las reglas.';
            notifyListeners();
          },
        );
  }

  /// Reintenta una lectura fallida.
  void retry() {
    bindUser(_uid, force: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
