import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// Estado global del perfil editable.
class ProfileProvider extends ChangeNotifier {
  /// Crea el provider con un repositorio de perfiles.
  ProfileProvider({required ProfileService service}) : _service = service;

  final ProfileService _service;
  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  /// Perfil cargado actualmente.
  UserProfile? get profile => _profile;

  /// Indica si se está cargando el perfil.
  bool get isLoading => _isLoading;

  /// Indica si se está guardando el perfil.
  bool get isSaving => _isSaving;

  /// Último error de perfil.
  String? get errorMessage => _errorMessage;

  /// Carga o crea en memoria un perfil inicial para el usuario.
  Future<void> loadProfile({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final existing = await _service.getProfile(userId);
      if (existing != null) {
        _profile = existing;
      } else {
        final initial = UserProfile.initial(
          id: userId,
          email: email,
          name: displayName,
        );
        await _service.saveProfile(initial);
        _profile = initial;
      }
    } on Object catch (error) {
      _errorMessage = 'No se pudo cargar el perfil: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda los campos editables del perfil.
  Future<bool> saveProfile({
    required String name,
    required String photoUrl,
    required String bio,
  }) async {
    final current = _profile;
    if (current == null) {
      return false;
    }
    if (name.trim().length < 2) {
      _errorMessage = 'El nombre debe tener al menos 2 caracteres.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = current.copyWith(
        name: name.trim(),
        photoUrl: photoUrl.trim(),
        bio: bio.trim(),
      );
      await _service.saveProfile(updated);
      _profile = updated;
      return true;
    } on Object catch (error) {
      _errorMessage = 'No se pudo guardar el perfil: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
