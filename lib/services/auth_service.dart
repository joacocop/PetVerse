import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Contrato de autenticación usado por la aplicación y el modo demo.
abstract interface class AuthService {
  /// Cambios de sesión del usuario actual.
  Stream<AppUser?> get authStateChanges;

  /// Inicia sesión con email y contraseña.
  Future<AppUser?> signInWithEmail(String email, String password);

  /// Registra un usuario con email, contraseña y nombre.
  Future<AppUser?> registerWithEmail(
    String name,
    String email,
    String password,
  );

  /// Envía un email de recuperación de contraseña.
  Future<void> sendPasswordResetEmail(String email);

  /// Inicia sesión con Google.
  Future<AppUser?> signInWithGoogle();

  /// Inicia sesión con Apple.
  Future<AppUser?> signInWithApple();

  /// Cierra la sesión actual.
  Future<void> signOut();
}

/// Implementación real basada en Firebase Authentication.
class FirebaseAuthService implements AuthService {
  /// Crea el servicio usando la instancia inicializada de Firebase Auth.
  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AppUser? _toAppUser(User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(_toAppUser);

  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toAppUser(credential.user);
  }

  @override
  Future<AppUser?> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    return _toAppUser(credential.user);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    final credential = await _auth.signInWithPopup(GoogleAuthProvider());
    return _toAppUser(credential.user);
  }

  @override
  Future<AppUser?> signInWithApple() async {
    final credential = await _auth.signInWithPopup(OAuthProvider('apple.com'));
    return _toAppUser(credential.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Implementación local para recorrer la aplicación sin credenciales.
class DemoAuthService implements AuthService {
  /// Crea un servicio de autenticación en memoria.
  DemoAuthService() : _changes = StreamController<AppUser?>.broadcast();

  final StreamController<AppUser?> _changes;
  AppUser? _currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _changes.stream;

  @override
  Future<AppUser?> signInWithEmail(String email, String password) async {
    _validateCredentials(email, password);
    _currentUser = AppUser(
      id: _demoId(email),
      email: email.trim(),
      displayName: 'Amante de mascotas',
    );
    _changes.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<AppUser?> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    _validateCredentials(email, password);
    if (name.trim().length < 2) {
      throw FirebaseAuthException(
        code: 'invalid-display-name',
        message: 'Ingresa un nombre de al menos 2 caracteres.',
      );
    }
    _currentUser = AppUser(
      id: _demoId(email),
      email: email.trim(),
      displayName: name.trim(),
    );
    _changes.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!email.contains('@')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Ingresa un email válido.',
      );
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    _currentUser = const AppUser(
      id: 'demo_google_user',
      email: 'google@demo.petverse',
      displayName: 'Usuario Google',
    );
    _changes.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<AppUser?> signInWithApple() async {
    _currentUser = const AppUser(
      id: 'demo_apple_user',
      email: 'apple@demo.petverse',
      displayName: 'Usuario Apple',
    );
    _changes.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _changes.add(null);
  }

  String _demoId(String email) =>
      'demo_${email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  void _validateCredentials(String email, String password) {
    if (!email.contains('@')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Ingresa un email válido.',
      );
    }
    if (password.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'La contraseña debe tener al menos 6 caracteres.',
      );
    }
  }
}
