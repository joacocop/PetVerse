import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:petverse/main.dart';
import 'package:petverse/models/community.dart';
import 'package:petverse/models/pet.dart';
import 'package:petverse/services/community_service.dart';
import 'package:petverse/providers/pet_provider.dart';
import 'package:petverse/providers/auth_provider.dart';

Future<BuildContext> enter(WidgetTester tester) async {
  await tester.pumpWidget(const PetVerseApp(firebaseReady: false));
  await tester.pumpAndSettle();
  final google = find.text('Probar demo con Google');
  await tester.ensureVisible(google);
  await tester.pumpAndSettle();
  await tester.tap(google);
  await tester.pumpAndSettle();
  return tester.element(find.byType(NavigationBar));
}

Pet pet(String owner) => Pet(
  id: 'luna',
  ownerId: owner,
  name: 'Luna',
  type: PetType.dog,
  breed: 'Mestiza',
  age: 3,
  weight: 12,
  photos: [],
  bio: 'Muy compañera',
  createdAt: DateTime.now(),
);
Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Un cierre externo de sesión descarta el chat abierto', (
    tester,
  ) async {
    final context = await enter(tester);
    final auth = context.read<AuthProvider>();
    await tester.tap(find.text('Mensajes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refugio demo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Mensaje'),
      'Texto privado',
    );
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('Texto privado'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Texto privado'), findsNothing);
    expect(find.text('Probar demo con Google'), findsOneWidget);
  });
  testWidgets(
    'Publicar adopción, filtrar por ubicación y cerrar aviso propio',
    (tester) async {
      final context = await enter(tester);
      await context.read<PetProvider>().savePet(
        pet('demo_google_user').copyWith(id: ''),
      );
      await tester.tap(find.text('Adopciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar adopción'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luna').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Córdoba');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Hogar responsable',
      );
      await tapVisible(tester, find.text('Publicar aviso'));
      expect(find.text('Conocer y contactar →'), findsOneWidget);
      final location = find.widgetWithText(TextField, 'Ubicación');
      await tester.enterText(location, 'Buenos Aires');
      await tester.pumpAndSettle();
      expect(find.text('Conocer y contactar →'), findsNothing);
      await tester.enterText(location, 'cordoba');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Conocer y contactar →'));
      expect(find.text('Hogar responsable'), findsOneWidget);
      await tapVisible(tester, find.text('Cerrar aviso de adopción'));
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Conocer y contactar →'), findsNothing);
    },
  );
  testWidgets('Contacto de adopción llega al chat y conserva el historial', (
    tester,
  ) async {
    final context = await enter(tester);
    final service = context.read<CommunityService>();
    await service.publishAdoption(
      Adoption(
        id: '',
        pet: pet('demo_refugio'),
        ownerName: 'Refugio demo',
        location: 'Rosario',
        requirements: 'Cuidado responsable',
        active: true,
      ),
    );
    await tester.tap(find.text('Adopciones'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Conocer y contactar →'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Joaquín');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Quisiera conocer a Luna',
    );
    await tapVisible(tester, find.text('Enviar consulta'));
    expect(find.textContaining('Quisiera conocer a Luna'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mensaje'),
      '¿Cuándo podemos visitarla?',
    );
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuándo podemos visitarla?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensajes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refugio demo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuándo podemos visitarla?'), findsOneWidget);
  });
  testWidgets(
    'Nuevo chat desde directorio y push demo explicado sin simular envío',
    (tester) async {
      await enter(tester);
      await tester.tap(find.text('Mensajes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refugio demo'));
      await tester.pumpAndSettle();
      expect(find.text('Escribí el primer mensaje.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Activar notificaciones'));
      expect(
        find.text('La demo no envía notificaciones push.'),
        findsOneWidget,
      );
    },
  );
}
