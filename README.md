# PetVerse

Red social para mascotas construida con Flutter Web, Firebase y Provider.

## Funcionalidades implementadas

- PV1: autenticación con email, Google y recuperación de contraseña.
- PV2: perfil editable con nombre, foto, bio y lista de mascotas implementado.
- PV3: registro y edición de mascotas con nombre, tipo, raza, edad, peso, fotos
  y bio implementado.
- PV4: feed compartido de imágenes/videos con mascota, autor, caption, fecha,
  likes y sección de comentarios. Las publicaciones más recientes aparecen primero.
- PV5: likes por botón o doble toque sobre el contenido, animación y contador
  sincronizado en tiempo real. El doble toque siempre da like; el botón permite quitarlo.
- PV6: agregar, ver y eliminar comentarios propios en tiempo real, con confirmación
  antes de borrar. Los comentarios de otras personas no se pueden eliminar.
- PV7: grilla de adopciones, filtros combinados por tipo/edad/ubicación, detalle,
  publicación/cierre de avisos propios y formulario de contacto por chat privado.
- PV8: selector de imágenes/videos del dispositivo, validación, progreso y cancelación
  de subida a Storage. **Implementado, pero desactivado en producción mientras
  se mantenga el proyecto sin facturación**, por decisión del usuario.
- PV9: directorio público mínimo, chat 1 a 1 e historial privado en Firestore.
- PV10: registro FCM voluntario, token por dispositivo, worker web, avisos en primer
  plano e historial; backend de likes/comentarios/mensajes preparado en `functions/`.
  **No hay envío automático real hasta desplegar las funciones (requiere Blaze).**
- Sin configuración de Firebase, los PV funcionan en modo demo con datos
  temporales en memoria, excepto subidas y push, que no se simulan como reales.

Las fotos de PV3 y los medios de PV4 se ingresan como URLs directas. Los videos
usan el reproductor de Flutter, con reproducción/pausa, sonido y barra de progreso.
La selección y subida de archivos está implementada en PV8, y se conserva la
opción de URLs para trabajar sin Storage. Los enlaces
deben ser accesibles por el navegador y permitir su carga desde la app; un enlace
a una página de YouTube, por ejemplo, no es un archivo de video directo.

## Requisitos

- Flutter 3.44 o superior, Dart 3.12 o superior y soporte Web.
- Un proyecto Firebase con Authentication y Firestore habilitados.

## Ejecutar en modo demo

```bash
flutter pub get
flutter run -d chrome
```

En modo demo se puede registrar una cuenta o usar cualquier email válido con una
contraseña de seis o más caracteres. Los datos se mantienen en memoria durante
la ejecución y se pierden al recargar o cerrar la aplicación.

El botón **Probar demo con Google** abre una sesión ficticia local sin verificar
una cuenta real. La recuperación de contraseña también es simulada y no envía
correos. Se pueden crear mascotas y publicaciones, dar likes y comentar en memoria.

## Configurar Firebase Web

La aplicación lee las opciones al compilar. Para usar el proyecto Firebase real,
guardá su configuración web en `config/firebase.local.json` y ejecutá:

```powershell
flutter run -d chrome --dart-define-from-file=config/firebase.local.json
```

El archivo local está excluido de Git. En otra computadora, copiá
`config/firebase.example.json` como `config/firebase.local.json` y completá los
valores de la aplicación web registrados en Firebase. El adaptador de opciones
ya utiliza esos valores, por lo que no hace falta pegar código JavaScript en
Flutter ni instalar el SDK de npm. También admite `--dart-define` individuales.

Detené la ejecución anterior con `Ctrl+C` antes de arrancar con esta configuración:
los cambios de configuración necesitan reiniciar la app, no solo recargarla.
Con Firebase inicializado, el aviso de modo demo desaparece y el botón pasa
a decir **Continuar con Google**. Esto confirma el
cambio de servicios, pero todavía hay que probar un acceso real y comprobar
que los datos se guarden y se recuperen desde Firestore.

También se puede ejecutar `flutterfire configure` y reemplazar el adaptador de
opciones por el archivo generado por FlutterFire.

Para utilizar cuentas reales hay que configurar además, en el proyecto Firebase:

1. Habilitar Email/Password y Google en Authentication > Sign-in method.
2. Incluir el dominio usado para ejecutar la app (por ejemplo, `localhost`)
   entre los dominios autorizados de Authentication y proporcionar
   `FIREBASE_AUTH_DOMAIN` al ejecutar.
3. Habilitar Firestore y aplicar las reglas de `firestore.rules`.

### Actualizar las reglas para PV4–PV6

Las reglas locales ahora incluyen `posts` y sus comentarios. Copiá el contenido
completo de `firestore.rules` en **Firestore > Reglas > Publicar** antes de probar
el feed real. Guardar o commitear el archivo no actualiza las reglas del servidor.
Con las reglas antiguas solo estarán habilitados el perfil y las mascotas.

Cada cuenta puede publicar usando una mascota propia, modificar únicamente su
reacción y borrar únicamente sus comentarios. Los perfiles y mascotas siguen
siendo privados; nombre, foto pública y nombre de mascota se guardan como
instantáneas en cada publicación, evitando hacer públicos los documentos de usuario.

Referencia oficial: [acceso social con Flutter y Firebase](https://firebase.google.com/docs/auth/flutter/federated-auth).

## Modelo de datos del feed

- `posts/{postId}`: `petId`, `petName`, `ownerId`, `authorName`, `authorPhotoUrl`,
  `imageUrl`, `mediaType` (`image` o `video`), `caption`, `likes[]`, `createdAt`.
- `posts/{postId}/comments/{commentId}`: `userId`, `userName`, `userPhotoUrl`,
  `text`, `createdAt`.

Se conservan los nombres del esquema de la consigna. `imageUrl` también guarda
el enlace cuando `mediaType` es `video`. Firestore asigna las fechas del servidor;
el contador de likes deriva de los UID únicos de `likes`, actualizados con
`arrayUnion`/`arrayRemove` para evitar duplicados y escrituras que pierdan likes ajenos.
Las suscripciones se cancelan al cerrar o cambiar de sesión.

## Comprobar PV4–PV6

1. Ingresá y registrá al menos una mascota en **Mi perfil**.
2. Entrá en **Feed > Nueva publicación**, seleccioná tu mascota e ingresá un
   caption y una URL de imagen o video; publicá.
3. Abrí otra sesión con otra cuenta: la publicación debe aparecer sin recargar.
4. Probá el botón de like y el doble toque: el contador debe cambiar en ambas
   sesiones, sin duplicar el like de una misma cuenta.
5. Abrí **Comentarios**, agregá uno y verificá su aparición en ambas sesiones.
   Solo el autor verá el botón para eliminarlo.

Pruebas de Flutter (incluyen recorrido de UI, orden cronológico, idempotencia de
likes, aislamiento de sesión y comentarios entre dos lectores):

```powershell
flutter test
flutter analyze
```

Pruebas de reglas contra Firestore Emulator (requieren Node.js 24.12+ y Java 21+):

La misma terminal debe mostrar esas versiones al ejecutar `node --version` y
`java -version`, aunque haya otras versiones instaladas en Windows.

```powershell
cd test/firestore
npm install
npm test
```

El emulador usa `demo-petverse-tests`, puerto local 8085 y datos descartables;
no escribe en el proyecto real. Las pruebas comprueban lectura autenticada,
mascotas propias, likes concurrentes, protección de campos, eliminación de
comentarios exclusivamente por su autor y snapshots en vivo entre dos clientes.

## Arquitectura

La aplicación separa modelos, servicios, providers y pantallas. Los servicios
de Firebase tienen implementaciones equivalentes en memoria para el modo demo,
lo que permite validar la navegación y la UI sin inventar credenciales.
