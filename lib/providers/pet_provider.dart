import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pet.dart';
import '../services/pet_service.dart';

/// Estado global de la lista de mascotas del usuario.
class PetProvider extends ChangeNotifier {
  /// Crea el provider con un repositorio de mascotas.
  PetProvider({required this._service});

  final PetService _service;
  StreamSubscription<List<Pet>>? _subscription;
  List<Pet> _pets = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _ownerId;

  /// Mascotas ordenadas por fecha de creación.
  List<Pet> get pets => _pets;

  /// Indica si se está cargando la lista.
  bool get isLoading => _isLoading;

  /// Indica si se está guardando o eliminando una mascota.
  bool get isSaving => _isSaving;

  /// Último error de mascotas.
  String? get errorMessage => _errorMessage;

  /// Comienza a escuchar la subcolección de mascotas de un usuario.
  Future<void> loadPets(String ownerId) async {
    if (_ownerId == ownerId && _subscription != null) {
      return;
    }
    await _subscription?.cancel();
    _ownerId = ownerId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _subscription = _service.watchPets(ownerId).listen(
      (pets) {
        _pets = pets;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = 'No se pudieron cargar las mascotas: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Crea o actualiza una mascota.
  Future<bool> savePet(Pet pet) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.savePet(pet);
      return true;
    } on Object catch (error) {
      _errorMessage = 'No se pudo guardar la mascota: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Elimina una mascota.
  Future<bool> deletePet(Pet pet) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.deletePet(pet);
      return true;
    } on Object catch (error) {
      _errorMessage = 'No se pudo eliminar la mascota: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
