import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community.dart';

/// Persistencia de adopciones, directorio público y chats privados.
abstract interface class CommunityService {
  Stream<List<Adoption>> adoptions();
  Future<void> publishAdoption(Adoption adoption);
  Future<void> closeAdoption(String id, String uid);
  Stream<List<CommunityUser>> users();
  Stream<List<Chat>> chats(String uid);
  Future<String> openChat(String uid, String peer);
  Stream<List<ChatMessage>> messages(String chatId, String uid);
  Future<void> send(String chatId, String uid, String text);
  void dispose();
}

/// Identificador estable, independiente del iniciador y sin colisiones por separador.
String privateChatId(String a, String b) {
  if (a.isEmpty || b.isEmpty || a == b) {
    throw ArgumentError('Selecciona otra persona.');
  }
  final ids = [a, b]..sort();
  return ids
      .map((id) => base64Url.encode(utf8.encode(id)).replaceAll('=', ''))
      .join('.');
}

/// Comprueba el texto antes de escribir tanto en demo como en producción.
String validMessage(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.length > 2000) {
    throw ArgumentError('El mensaje debe tener entre 1 y 2000 caracteres.');
  }
  return trimmed;
}

/// Implementación real; las reglas vuelven a comprobar cada autorización.
class FirestoreCommunityService implements CommunityService {
  FirestoreCommunityService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Stream<List<Adoption>> adoptions() => _db
      .collection('adoptions')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Adoption.fromMap(d.id, d.data())).toList());

  @override
  Future<void> publishAdoption(Adoption adoption) async {
    // Un documento por mascota: republicar actualiza, no duplica el aviso.
    final id = privateChatId(adoption.pet.ownerId, 'pet:${adoption.pet.id}');
    await _db.collection('adoptions').doc(id).set({
      ...adoption.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> closeAdoption(String id, String uid) =>
      _db.collection('adoptions').doc(id).update({'active': false});

  @override
  Stream<List<CommunityUser>> users() => _db
      .collection('publicProfiles')
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => CommunityUser(
                d.id,
                d.data()['name'] as String,
                d.data()['photoUrl'] as String,
              ),
            )
            .toList(),
      );

  @override
  Stream<List<Chat>> chats(String uid) => _db
      .collection('chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((s) {
        final result = s.docs.map((d) => Chat.fromMap(d.id, d.data())).toList();
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result;
      });

  @override
  Future<String> openChat(String uid, String peer) async {
    final id = privateChatId(uid, peer);
    final ref = _db.collection('chats').doc(id);
    await _db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return;
      tx.set(ref, {
        'participants': [uid, peer]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastText': '',
        'lastSenderId': '',
        'lastMessageId': '',
      });
    });
    return id;
  }

  @override
  Stream<List<ChatMessage>> messages(String chatId, String uid) => _db
      .collection('chats/$chatId/messages')
      .orderBy('timestamp')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList(),
      );

  @override
  Future<void> send(String chatId, String uid, String text) async {
    final clean = validMessage(text);
    final chat = _db.collection('chats').doc(chatId);
    final message = chat.collection('messages').doc();
    final batch = _db.batch();
    batch.set(message, {
      'senderId': uid,
      'text': clean,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(chat, {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastText': clean,
      'lastSenderId': uid,
      'lastMessageId': message.id,
    });
    await batch.commit();
  }

  @override
  void dispose() {}
}

/// Demo en memoria: no simula subidas a Storage ni notificaciones del navegador.
class DemoCommunityService implements CommunityService {
  final _adoptions = <String, Adoption>{};
  final _chats = <String, Chat>{};
  final _messages = <String, List<ChatMessage>>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  int _sequence = 0;
  final demoUsers = <CommunityUser>[
    const CommunityUser('demo_google_user', 'Usuario Google', ''),
    const CommunityUser('demo_refugio', 'Refugio demo', ''),
  ];

  Stream<T> _watch<T>(T Function() read) => Stream.multi((controller) {
    void emit() {
      try {
        controller.add(read());
      } on Object catch (error, stack) {
        controller.addError(error, stack);
      }
    }

    emit();
    final sub = _changes.stream.listen((_) => emit());
    controller.onCancel = sub.cancel;
  });

  @override
  Stream<List<Adoption>> adoptions() => _watch(
    () =>
        _adoptions.values.toList()
          ..sort((a, b) => b.pet.createdAt.compareTo(a.pet.createdAt)),
  );
  @override
  Future<void> publishAdoption(Adoption adoption) async {
    final id = privateChatId(adoption.pet.ownerId, 'pet:${adoption.pet.id}');
    _adoptions[id] = Adoption(
      id: id,
      pet: adoption.pet,
      ownerName: adoption.ownerName,
      location: adoption.location,
      requirements: adoption.requirements,
      active: true,
    );
    _changes.add(null);
  }

  @override
  Future<void> closeAdoption(String id, String uid) async {
    final old = _adoptions[id]!;
    if (old.pet.ownerId != uid) throw StateError('No autorizado.');
    _adoptions[id] = Adoption(
      id: id,
      pet: old.pet,
      ownerName: old.ownerName,
      location: old.location,
      requirements: old.requirements,
      active: false,
    );
    _changes.add(null);
  }

  @override
  Stream<List<CommunityUser>> users() => _watch(() => List.of(demoUsers));
  @override
  Stream<List<Chat>> chats(String uid) => _watch(
    () =>
        _chats.values.where((c) => c.participants.contains(uid)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  @override
  Future<String> openChat(String uid, String peer) async {
    final id = privateChatId(uid, peer);
    _chats.putIfAbsent(
      id,
      () => Chat(
        id: id,
        participants: [uid, peer]..sort(),
        updatedAt: DateTime.now(),
      ),
    );
    _changes.add(null);
    return id;
  }

  void _check(String id, String uid) {
    if (!(_chats[id]?.participants.contains(uid) ?? false)) {
      throw StateError('No perteneces a esta conversación.');
    }
  }

  @override
  Stream<List<ChatMessage>> messages(String chatId, String uid) => _watch(() {
    _check(chatId, uid);
    return List.of(_messages[chatId] ?? []);
  });
  @override
  Future<void> send(String chatId, String uid, String text) async {
    _check(chatId, uid);
    final clean = validMessage(text);
    final date = DateTime.now();
    (_messages[chatId] ??= []).add(
      ChatMessage('${++_sequence}', uid, clean, date),
    );
    _chats[chatId] = Chat(
      id: chatId,
      participants: _chats[chatId]!.participants,
      updatedAt: date,
      lastText: clean,
      lastSenderId: uid,
    );
    _changes.add(null);
  }

  @override
  void dispose() => _changes.close();
}
