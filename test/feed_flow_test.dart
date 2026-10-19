import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:petverse/main.dart';
import 'package:petverse/models/pet.dart';
import 'package:petverse/models/post.dart';
import 'package:petverse/providers/feed_provider.dart';
import 'package:petverse/providers/pet_provider.dart';

Future<BuildContext> enterFeed(WidgetTester tester) async {
  await tester.pumpWidget(const PetVerseApp(firebaseReady: false));
  await tester.pumpAndSettle();
  expect(find.textContaining('Apple'), findsNothing);
  final login = find.text('Probar demo con Google');
  await tester.ensureVisible(login);
  await tester.tap(login);
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(NavigationBar));
  await context.read<PetProvider>().savePet(Pet(
        id: '',
        ownerId: 'demo_google_user',
        name: 'Luna',
        type: PetType.dog,
        breed: 'Mestiza',
        age: 3,
        weight: 12,
        photos: const [],
        bio: '',
        createdAt: DateTime.now(),
      ));
  await tester.tap(find.text('Feed'));
  await tester.pumpAndSettle();
  return context;
}

void main() {
  testWidgets('Publicar, botón/doble toque y agregar/eliminar comentario',
      (tester) async {
    final context = await enterFeed(tester);
    await tester.tap(find.text('Nueva publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luna').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Luna de paseo');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'https://example.com/luna.jpg');
    final publish = find.widgetWithText(FilledButton, 'Publicar');
    await tester.ensureVisible(publish);
    await tester.pumpAndSettle();
    await tester.tap(publish);
    await tester.pumpAndSettle();
    final feed = context.read<FeedProvider>();
    expect(feed.posts.single.caption, 'Luna de paseo');
    final post = feed.posts.single;
    final likeButton = find.byKey(ValueKey('like-${post.id}'));
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    await tester.tap(likeButton);
    await tester.pumpAndSettle();
    expect(feed.posts.single.likeCount, 1);
    await tester.tap(likeButton);
    await tester.pumpAndSettle();
    expect(feed.posts.single.likeCount, 0);
    final media = find.byKey(ValueKey('post-media-${post.id}'));
    await tester.ensureVisible(media);
    await tester.pumpAndSettle();
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(media);
    await tester.pumpAndSettle();
    expect(feed.posts.single.likeCount, 1);
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(media);
    await tester.pumpAndSettle();
    expect(feed.posts.single.likeCount, 1);
    final comments = find.byKey(ValueKey('comments-${post.id}'));
    await tester.ensureVisible(comments);
    await tester.pumpAndSettle();
    await tester.tap(comments);
    await tester.pumpAndSettle();
    final input = find.widgetWithText(TextFormField, 'Escribe un comentario');
    await tester.ensureVisible(input);
    await tester.pumpAndSettle();
    await tester.enterText(input, '¡Hola Luna!');
    final send = find.widgetWithText(FilledButton, 'Comentar');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('¡Hola Luna!'), findsOneWidget);
    final delete = find.byTooltip('Eliminar comentario');
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola Luna!'), findsNothing);
    expect(find.text('Comentarios (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Video conserva su tipo y ofrece reproducción', (tester) async {
    final context = await enterFeed(tester);
    final feed = context.read<FeedProvider>();
    await feed.publish(
        petId: context.read<PetProvider>().pets.single.id,
        petName: 'Luna',
        authorName: 'Usuario Google',
        authorPhotoUrl: '',
        caption: 'Luna en video',
        mediaUrl: 'https://example.com/luna.mp4',
        mediaType: PostMediaType.video);
    await tester.pumpAndSettle();
    expect(find.text('Reproducir video'), findsOneWidget);
    expect(feed.posts.single.mediaType, PostMediaType.video);
    expect(tester.takeException(), isNull);
  });
}
