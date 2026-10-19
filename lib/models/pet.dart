/// Tipo de mascota admitido por el registro inicial.
enum PetType {
  /// Perro.
  dog,

  /// Gato.
  cat,

  /// Otro tipo de mascota.
  other,
}

/// Mascota asociada a un usuario.
class Pet {
  /// Crea una mascota.
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.breed,
    required this.age,
    required this.weight,
    required this.photos,
    required this.bio,
    required this.createdAt,
  });

  /// Identificador del documento de mascota.
  final String id;

  /// Usuario propietario.
  final String ownerId;

  /// Nombre de la mascota.
  final String name;

  /// Tipo de mascota.
  final PetType type;

  /// Raza o variedad.
  final String breed;

  /// Edad en años.
  final int age;

  /// Peso en kilogramos.
  final double weight;

  /// URLs de fotos de la mascota.
  final List<String> photos;

  /// Descripción de la mascota.
  final String bio;

  /// Fecha de alta.
  final DateTime createdAt;

  /// Etiqueta legible del tipo de mascota.
  String get typeLabel => switch (type) {
        PetType.dog => 'Perro',
        PetType.cat => 'Gato',
        PetType.other => 'Otro',
      };

  /// Convierte la mascota a un mapa compatible con Firestore.
  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'name': name,
        'type': type.name,
        'breed': breed,
        'age': age,
        'weight': weight,
        'photos': photos,
        'bio': bio,
        'createdAt': createdAt,
      };

  /// Reconstruye una mascota desde un documento de Firestore.
  factory Pet.fromMap(String id, Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? PetType.other.name;
    final type = PetType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => PetType.other,
    );
    final rawPhotos = map['photos'];
    return Pet(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: type,
      breed: map['breed'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      photos: rawPhotos is Iterable
          ? rawPhotos.whereType<String>().toList()
          : const <String>[],
      bio: map['bio'] as String? ?? '',
      createdAt: _petDateFromValue(map['createdAt']),
    );
  }

  /// Crea una copia modificando únicamente los valores indicados.
  Pet copyWith({
    String? id,
    String? ownerId,
    String? name,
    PetType? type,
    String? breed,
    int? age,
    double? weight,
    List<String>? photos,
    String? bio,
    DateTime? createdAt,
  }) {
    return Pet(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime _petDateFromValue(dynamic value) {
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
