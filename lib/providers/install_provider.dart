import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/pwa/install_service.dart';

/// Mantiene el prompt pendiente; una aceptación no se confunde con instalación real.
class InstallProvider extends ChangeNotifier {
  /// Permite inyectar un navegador falso para probar el flujo.
  InstallProvider({InstallService? service})
    : _service = service ?? createInstallService() {
    state = _service.state;
    _subscription = _service.changes.listen((value) {
      state = value;
      if (!_disposed) notifyListeners();
    });
  }
  final InstallService _service;
  late final StreamSubscription<String> _subscription;
  late String state;
  bool busy = false;
  bool _disposed = false;
  String get instructions => _service.instructions;

  /// Invoca inmediatamente el prompt para conservar el gesto del usuario.
  Future<String> install() async {
    if (busy) return 'busy';
    busy = true;
    notifyListeners();
    try {
      return await _service.request();
    } on Object {
      return 'error';
    } finally {
      busy = false;
      state = _service.state;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _service.dispose();
    super.dispose();
  }
}
