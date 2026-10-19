import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Contrato de persistencia para perfiles de usuario.
abstract interface class ProfileService {
  /// Obtiene un perfil o null si todavía no existe.
  Future<UserProfile?> getProfile(String userId);

  /// Guarda un perfil con actualización parcial.
  Future<void> saveProfile(UserProfile profile);
}

/// Persistencia real de perfiles en Firestore.
class FirestoreProfileService implements ProfileService {
  /// Crea el servicio con una instancia opcional de Firestore.
  FirestoreProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final snapshot = await _users.doc(userId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return UserProfile.fromMap(snapshot.id, data);
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    return _users.doc(profile.id).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
  }
}

/// Persistencia en memoria para el modo demo.
class DemoProfileService implements ProfileService {
  /// Crea un repositorio de perfiles en memoria.
  DemoProfileService();

  final Map<String, UserProfile> _profiles = {};

  @override
  Future<UserProfile?> getProfile(String userId) async => _profiles[userId];

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profiles[profile.id] = profile;
  }
}
