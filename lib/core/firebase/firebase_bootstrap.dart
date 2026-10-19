import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Inicializa Firebase de forma segura para producción o modo demo.
abstract final class FirebaseBootstrap {
  static bool _isReady = false;

  /// Indica si Firebase se inicializó correctamente.
  static bool get isReady => _isReady;

  /// Intenta inicializar Firebase sin impedir el arranque del modo demo.
  static Future<bool> initialize() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) {
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _isReady = true;
    } on FirebaseException {
      _isReady = false;
    }
    return _isReady;
  }
}
