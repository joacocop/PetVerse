import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:petverse/models/community.dart';
import 'package:petverse/models/pet.dart';
import 'package:petverse/services/community_service.dart';
import 'package:petverse/services/media_service.dart';

Pet pet({String owner = 'alice', int age = 2}) => Pet(
  id: 'luna',
  ownerId: owner,
  name: 'Luna',
  type: PetType.dog,
  breed: '',
  age: age,
  weight: 8,
  photos: [],
  bio: '',
  createdAt: DateTime(2026),
);
Adoption adoption({int age = 2}) => Adoption(
  id: '',
  pet: pet(age: age),
  ownerName: 'Alice',
  location: 'Córdoba, Argentina',
  requirements: '',
  active: true,
);

void main() {
  test('Filtros combinados con acentos y límites de edad', () {
    expect(
      adoption().matches(type: PetType.dog, age: 'adult', location: 'cordoba'),
      isTrue,
    );
    expect(adoption().matches(type: PetType.cat), isFalse);
    expect(adoption(age: 1).matches(age: 'young'), isTrue);
    expect(adoption(age: 2).matches(age: 'young'), isFalse);
    expect(adoption(age: 7).matches(age: 'adult'), isTrue);
    expect(adoption(age: 8).matches(age: 'senior'), isTrue);
  });
  test('Avisos en vivo, sin duplicar y cierre solo por propietario', () async {
    final service = DemoCommunityService();
    addTearDown(service.dispose);
    await service.publishAdoption(adoption());
    await service.publishAdoption(adoption());
    final listings = await service.adoptions().first;
    expect(listings, hasLength(1));
    await expectLater(
      service.closeAdoption(listings.single.id, 'bob'),
      throwsStateError,
    );
    await service.closeAdoption(listings.single.id, 'alice');
    expect((await service.adoptions().first).single.active, isFalse);
  });
  test('Chat estable sin colisiones y validación de participantes', () {
    expect(privateChatId('alice', 'bob'), privateChatId('bob', 'alice'));
    expect(privateChatId('a_b', 'c'), isNot(privateChatId('a', 'b_c')));
    expect(() => privateChatId('alice', 'alice'), throwsArgumentError);
  });
  test(
    'Historial entre dos lectores, sin acceso de terceros ni mensajes vacíos',
    () async {
      final service = DemoCommunityService();
      addTearDown(service.dispose);
      final id = await service.openChat('alice', 'bob');
      expect(await service.openChat('bob', 'alice'), id);
      final received = service
          .messages(id, 'bob')
          .firstWhere((list) => list.length == 2);
      await service.send(id, 'alice', ' Hola ');
      await service.send(id, 'bob', 'Respuesta');
      expect((await received).map((m) => m.text), ['Hola', 'Respuesta']);
      expect((await service.chats('alice').first).single.lastText, 'Respuesta');
      expect(await service.chats('mallory').first, isEmpty);
      await expectLater(
        service.send(id, 'mallory', 'Espiar'),
        throwsStateError,
      );
      await expectLater(
        service.messages(id, 'mallory').first,
        throwsStateError,
      );
      await expectLater(service.send(id, 'alice', '  '), throwsArgumentError);
      await expectLater(
        service.send(id, 'alice', 'x' * 2001),
        throwsArgumentError,
      );
    },
  );
  test(
    'Archivos: MIME, tipo y límites; la demo no inventa URLs de Storage',
    () async {
      final image = MediaFile('FOTO.JPG', Uint8List.fromList([1, 2, 3]));
      expect(image.contentType, 'image/jpeg');
      expect(image.isVideo, isFalse);
      image.validate();
      expect(MediaFile('video.mp4', Uint8List(1)).isVideo, isTrue);
      expect(
        () => MediaFile('script.svg', Uint8List(1)).validate(),
        throwsArgumentError,
      );
      expect(
        () => MediaFile('foto.jpg', Uint8List(10 * 1024 * 1024 + 1)).validate(),
        throwsArgumentError,
      );
      expect(
        () =>
            MediaFile('video.mp4', Uint8List(50 * 1024 * 1024 + 1)).validate(),
        throwsArgumentError,
      );
      await expectLater(
        UnavailableMediaService().upload('alice', image, (_) {}),
        throwsStateError,
      );
    },
  );
}
