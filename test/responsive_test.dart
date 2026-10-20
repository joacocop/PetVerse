import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:petverse/main.dart';
import 'package:petverse/models/pet.dart';
import 'package:petverse/models/community.dart';
import 'package:petverse/models/post.dart';
import 'package:petverse/providers/pet_provider.dart';
import 'package:petverse/providers/feed_provider.dart';
import 'package:petverse/services/community_service.dart';
import 'package:petverse/screens/profile_screen.dart';
import 'package:petverse/screens/pet_form_screen.dart';
import 'package:petverse/screens/create_post_screen.dart';
import 'package:petverse/screens/adoptions_screen.dart';
import 'package:petverse/screens/chat_screen.dart';

Future<void> changeSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 740),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Perfil, feed, formularios, adopciones y chat en ${size.width.toInt()} px',
      (tester) async {
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          original?.call(details);
        };
        addTearDown(() => FlutterError.onError = original);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await changeSize(tester, size);
        await tester.pumpWidget(const PetVerseApp(firebaseReady: false));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Probar demo con Google'));
        expect(
          size.width >= 900
              ? find.byType(NavigationRail)
              : find.byType(NavigationBar),
          findsOneWidget,
        );
        final context = tester.element(find.byType(ProfileScreen));
        final pet = Pet(
          id: '',
          ownerId: 'demo_google_user',
          name: 'Luna de nombre muy largo',
          type: PetType.dog,
          breed: 'Mestiza de pelo largo',
          age: 3,
          weight: 12,
          photos: [],
          bio: 'Compañera',
          createdAt: DateTime.now(),
        );
        await context.read<PetProvider>().savePet(pet);
        await tester.pumpAndSettle();
        final saved = context.read<PetProvider>().pets.single;
        await context.read<FeedProvider>().publish(
          petId: saved.id,
          petName: saved.name,
          authorName: 'Usuario Google',
          authorPhotoUrl: '',
          caption: 'Paseando',
          mediaUrl: 'https://example.com/luna.jpg',
          mediaType: PostMediaType.image,
        );
        await context.read<CommunityService>().publishAdoption(
          Adoption(
            id: '',
            pet: pet.copyWith(id: 'luna', ownerId: 'demo_refugio'),
            ownerName: 'Refugio demo',
            location: 'Córdoba',
            requirements: 'Hogar responsable',
            active: true,
          ),
        );
        await tester.pumpAndSettle();
        for (final page in <Widget>[
          PetFormScreen(pet: saved),
          CreatePostScreen(
            user: tester.widget<ProfileScreen>(find.byType(ProfileScreen)).user,
          ),
          PublishAdoptionScreen(
            user: tester.widget<ProfileScreen>(find.byType(ProfileScreen)).user,
          ),
        ]) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => page));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        final navigation = size.width >= 900
            ? find.byType(NavigationRail)
            : find.byType(NavigationBar);
        await tester.tap(
          find.descendant(
            of: navigation,
            matching: find.byIcon(Icons.dynamic_feed_outlined),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Paseando'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: navigation,
            matching: find.byIcon(Icons.pets_outlined),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Conocer y contactar →'));
        expect(find.text('Quiero adoptar'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: navigation,
            matching: find.byIcon(Icons.chat_bubble_outline),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Nuevo chat'));
        await tester.tap(find.text('Refugio demo'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatScreen), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Mensaje'),
          '¡Hola!',
        );
        await tester.tap(find.byTooltip('Enviar mensaje'));
        await tester.pumpAndSettle();
        expect(find.text('¡Hola!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
