import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Estado global de autenticación y sesión.
class AuthProvider extends ChangeNotifier {
  /// Crea el provider y comienza a escuchar la sesión.
  AuthProvider({required this._service}) {
    _subscription = _service.authStateChanges.listen((user) {
      _user = user;
      _isInitializing = false;
      notifyListeners();
    });
    Future<void>.microtask(() {
      if (_isInitializing) {
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  final AuthService _service;
  StreamSubscription<AppUser?>? _subscription;
  AppUser? _user;
  bool _isInitializing = true;
  bool _isBusy = false;
  String? _errorMessage;

  /// Usuario autenticado actual.
  AppUser? get user => _user;

  /// Indica si todavía se está recuperando la sesión.
  bool get isInitializing => _isInitializing;

  /// Indica si hay una operación de autenticación en curso.
  bool get isBusy => _isBusy;

  /// Último error legible para la interfaz.
  String? get errorMessage => _errorMessage;

  /// Inicia sesión con email y contraseña.
  Future<bool> signInWithEmail(String email, String password) async =>
      _run(() => _service.signInWithEmail(email, password));

  /// Registra una cuenta nueva.
  Future<bool> register(String name, String email, String password) async =>
      _run(() => _service.registerWithEmail(name, email, password));

  /// Solicita un email de recuperación de contraseña.
  Future<bool> sendPasswordResetEmail(String email) async {
    _setBusy(true);
    try {
      await _service.sendPasswordResetEmail(email);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'No se pudo enviar el email.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Inicia sesión con Google.
  Future<bool> signInWithGoogle() async => _run(_service.signInWithGoogle);

  /// Cierra la sesión.
  Future<void> signOut() => _service.signOut();

  Future<bool> _run(Future<AppUser?> Function() operation) async {
    _setBusy(true);
    try {
      final user = await operation();
      _user = user ?? _user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _friendlyAuthError(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'El email o la contraseña no son correctos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese email.';
      case 'weak-password':
        return error.message ?? 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return error.message ?? 'Ingresa un email válido.';
      default:
        return error.message ?? 'No se pudo completar la operación.';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
