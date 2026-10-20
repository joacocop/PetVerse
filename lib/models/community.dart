import 'pet.dart';
import 'post.dart';

/// Instantánea pública de una mascota ofrecida en adopción.
class Adoption {
  const Adoption({
    required this.id,
    required this.pet,
    required this.ownerName,
    required this.location,
    required this.requirements,
    required this.active,
  });
  final String id;
  final Pet pet;
  final String ownerName;
  final String location;
  final String requirements;
  final bool active;

  factory Adoption.fromMap(String id, Map<String, dynamic> data) => Adoption(
    id: id,
    pet: Pet.fromMap(data['petId'] as String, data),
    ownerName: data['ownerName'] as String,
    location: data['location'] as String,
    requirements: data['requirements'] as String,
    active: data['active'] as bool,
  );

  Map<String, dynamic> toMap() => {
    ...pet.toMap(),
    'petId': pet.id,
    'ownerName': ownerName,
    'location': location,
    'requirements': requirements,
    'active': active,
  };

  /// Los filtros combinan tipo, rango de edad y ubicación sin distinguir acentos.
  bool matches({PetType? type, String age = 'all', String location = ''}) =>
      active &&
      (type == null || pet.type == type) &&
      switch (age) {
        'young' => pet.age < 2,
        'adult' => pet.age >= 2 && pet.age < 8,
        'senior' => pet.age >= 8,
        _ => true,
      } &&
      normalized(this.location).contains(normalized(location.trim()));
}

/// Perfil público mínimo; nunca incluye email ni documentos privados.
class CommunityUser {
  const CommunityUser(this.id, this.name, this.photoUrl);
  final String id;
  final String name;
  final String photoUrl;
}

/// Conversación privada entre exactamente dos participantes inmutables.
class Chat {
  const Chat({
    required this.id,
    required this.participants,
    required this.updatedAt,
    this.lastText = '',
    this.lastSenderId = '',
  });
  final String id;
  final List<String> participants;
  final DateTime updatedAt;
  final String lastText;
  final String lastSenderId;
  String other(String uid) => participants.firstWhere((id) => id != uid);
  factory Chat.fromMap(String id, Map<String, dynamic> data) => Chat(
    id: id,
    participants: List<String>.from(data['participants'] as List),
    updatedAt: documentDate(data['updatedAt']),
    lastText: data['lastText'] as String? ?? '',
    lastSenderId: data['lastSenderId'] as String? ?? '',
  );
}

/// Mensaje persistido con fecha asignada por Firestore.
class ChatMessage {
  const ChatMessage(this.id, this.senderId, this.text, this.timestamp);
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) =>
      ChatMessage(
        id,
        data['senderId'] as String,
        data['text'] as String,
        documentDate(data['timestamp']),
      );
}

/// Normalización compartida por búsqueda y filtros.
String normalized(String value) {
  var result = value.toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  accents.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}
