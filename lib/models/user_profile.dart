/// Perfil editable almacenado en `users/{userId}`.
class UserProfile {
  /// Crea un perfil de usuario.
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.bio,
    required this.createdAt,
  });

  /// Identificador del documento de usuario.
  final String id;

  /// Nombre visible.
  final String name;

  /// Email de la cuenta.
  final String email;

  /// URL de la foto de perfil.
  final String photoUrl;

  /// Biografía del usuario.
  final String bio;

  /// Fecha de creación del perfil.
  final DateTime createdAt;

  /// Crea un perfil vacío para completar en el primer acceso.
  factory UserProfile.initial({
    required String id,
    required String email,
    String? name,
  }) {
    return UserProfile(
      id: id,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'Amante de mascotas',
      email: email,
      photoUrl: '',
      bio: '',
      createdAt: DateTime.now(),
    );
  }

  /// Convierte el perfil a un mapa compatible con Firestore.
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'bio': bio,
        'createdAt': createdAt,
      };

  /// Reconstruye un perfil a partir de un documento de Firestore.
  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      name: map['name'] as String? ?? 'Amante de mascotas',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      createdAt: _dateFromValue(map['createdAt']),
    );
  }

  /// Crea una copia modificando únicamente los valores indicados.
  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime _dateFromValue(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value != null) {
    try {
      final dynamic date = value.toDate();
      if (date is DateTime) {
        return date;
      }
    } on Object {
      // Se usa la fecha actual para datos antiguos o incompletos.
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return parsed;
    }
  }
  return DateTime.now();
}
