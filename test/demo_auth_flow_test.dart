import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petverse/core/constants/app_constants.dart';
import 'package:petverse/main.dart';

void main() {
  for (final (provider, email) in [
    ('Google', 'google@demo.petverse'),
    ('Apple', 'apple@demo.petverse'),
  ]) {
    testWidgets('La demo de $provider permite entrar y cerrar sesión',
        (tester) async {
      await tester.pumpWidget(const PetVerseApp(firebaseReady: false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppConstants.demoModeMessage), findsOneWidget);
      final button = find.widgetWithText(
        OutlinedButton,
        'Probar demo con $provider',
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(email), findsOneWidget);
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Mis mascotas'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text(email), findsNothing);
    });
  }

  testWidgets('La recuperación demo informa que no envía correos',
      (tester) async {
    await tester.pumpWidget(const PetVerseApp(firebaseReady: false));
    await tester.pumpAndSettle();

    final forgotPassword = find.text('¿Olvidaste tu contraseña?');
    await tester.ensureVisible(forgotPassword);
    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(
      find.text('Modo demo: este formulario es una simulación. '
          'No se enviará ningún correo.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'persona@example.com');
    final submit = find.widgetWithText(FilledButton, 'Probar recuperación');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Simulación completada. No se envió ningún correo.'),
      findsOneWidget,
    );
    expect(find.text('Revisa tu bandeja de entrada.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
