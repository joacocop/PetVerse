import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet.dart';

/// Contrato de persistencia y stream de mascotas.
abstract interface class PetService {
  /// Escucha la lista de mascotas de un usuario en tiempo real.
  Stream<List<Pet>> watchPets(String ownerId);

  /// Crea o actualiza una mascota.
  Future<void> savePet(Pet pet);

  /// Elimina una mascota.
  Future<void> deletePet(Pet pet);
}

/// Persistencia real de mascotas en subcolecciones de Firestore.
class FirestorePetService implements PetService {
  /// Crea el servicio con una instancia opcional de Firestore.
  FirestorePetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _pets(String ownerId) =>
      _firestore.collection('users').doc(ownerId).collection('pets');

  @override
  Stream<List<Pet>> watchPets(String ownerId) {
    return _pets(ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Pet.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> savePet(Pet pet) async {
    final collection = _pets(pet.ownerId);
    final reference = pet.id.isEmpty ? collection.doc() : collection.doc(pet.id);
    await reference.set(
      pet.copyWith(id: reference.id).toMap(),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deletePet(Pet pet) => _pets(pet.ownerId).doc(pet.id).delete();
}

/// Persistencia reactiva en memoria para el modo demo.
class DemoPetService implements PetService {
  /// Crea un repositorio de mascotas en memoria.
  DemoPetService();

  final Map<String, List<Pet>> _petsByOwner = {};
  final Map<String, StreamController<List<Pet>>> _controllers = {};

  @override
  Stream<List<Pet>> watchPets(String ownerId) {
    final controller = _controllers.putIfAbsent(
      ownerId,
      () => StreamController<List<Pet>>.broadcast(),
    );
    Future<void>.microtask(
      () => controller.add(List.unmodifiable(_petsByOwner[ownerId] ?? const [])),
    );
    return controller.stream;
  }

  @override
  Future<void> savePet(Pet pet) async {
    final ownerPets = _petsByOwner.putIfAbsent(pet.ownerId, () => []);
    final petToSave = pet.id.isEmpty
        ? pet.copyWith(id: 'demo_pet_${DateTime.now().microsecondsSinceEpoch}')
        : pet;
    final index = ownerPets.indexWhere((item) => item.id == petToSave.id);
    if (index == -1) {
      ownerPets.add(petToSave);
    } else {
      ownerPets[index] = petToSave;
    }
    _controllers[pet.ownerId]?.add(List.unmodifiable(ownerPets));
  }

  @override
  Future<void> deletePet(Pet pet) async {
    _petsByOwner[pet.ownerId]?.removeWhere((item) => item.id == pet.id);
    _controllers[pet.ownerId]?.add(
      List.unmodifiable(_petsByOwner[pet.ownerId] ?? const []),
    );
  }
}
