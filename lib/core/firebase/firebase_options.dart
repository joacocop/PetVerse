import 'package:firebase_core/firebase_core.dart';

/// Opciones de Firebase leídas desde variables de compilación.
abstract final class DefaultFirebaseOptions {
  /// Devuelve las opciones web si están completas; de lo contrario, null.
  static FirebaseOptions? get currentPlatform {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId =
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
