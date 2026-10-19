# PetVerse

Red social para mascotas construida con Flutter Web, Firebase y Provider.

## Estado inicial

- PV1: código de autenticación con email, Google, Apple y recuperación de
  contraseña implementado. La autenticación real requiere configurar Firebase
  y habilitar los proveedores; su validación sigue pendiente.
- PV2: perfil editable con nombre, foto, bio y lista de mascotas implementado.
- PV3: registro y edición de mascotas con nombre, tipo, raza, edad, peso, fotos
  y bio implementado.
- Sin configuración de Firebase, los tres PV funcionan en modo demo con datos
  temporales en memoria. La persistencia real de PV2 y PV3 requiere Firestore.

Las fotos de PV3 se modelan como URLs; la selección de archivos y la subida a
Firebase Storage quedan reservadas para PV8, tal como separa la consigna.

## Requisitos

- Flutter con soporte Web.
- Un proyecto Firebase con Authentication y Firestore habilitados.

## Ejecutar en modo demo

```bash
flutter pub get
flutter run -d chrome
```

En modo demo se puede registrar una cuenta o usar cualquier email válido con una
contraseña de seis o más caracteres. Los datos se mantienen en memoria durante
la ejecución y se pierden al recargar o cerrar la aplicación.

Los botones **Probar demo con Google** y **Probar demo con Apple** abren una
sesión ficticia local: no abren el selector de cuentas ni verifican identidades
reales. La recuperación de contraseña también es simulada y no envía correos.

## Configurar Firebase Web

La aplicación lee las opciones mediante `--dart-define`, evitando guardar claves
en el repositorio:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

También se puede ejecutar `flutterfire configure` y reemplazar el adaptador de
opciones por el archivo generado por FlutterFire.

Para utilizar cuentas reales hay que configurar además, en el proyecto Firebase:

1. Habilitar Email/Password y Google en Authentication > Sign-in method.
2. Habilitar Apple y completar su configuración con una cuenta de Apple
   Developer, incluyendo el Service ID y la configuración OAuth correspondiente.
3. Incluir el dominio usado para ejecutar la app (por ejemplo, `localhost`)
   entre los dominios autorizados de Authentication y proporcionar
   `FIREBASE_AUTH_DOMAIN` al ejecutar.
4. Habilitar Firestore y aplicar las reglas de `firestore.rules` para los
   perfiles y las mascotas.

La configuración de los proveedores y las pruebas con cuentas reales son
necesarias para dar PV1 por validado por completo. El código de PV1–PV3 se puede
versionar como avance en modo demo sin presentar esas integraciones como probadas.

Referencias oficiales: [acceso social con Flutter y Firebase](https://firebase.google.com/docs/auth/flutter/federated-auth)
y [configuración de Apple para Web](https://firebase.google.com/docs/auth/web/apple).

## Arquitectura

La aplicación separa modelos, servicios, providers y pantallas. Los servicios
de Firebase tienen implementaciones equivalentes en memoria para el modo demo,
lo que permite validar la navegación y la UI sin inventar credenciales.
