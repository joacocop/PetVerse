# PV7 a PV10: uso, pruebas y configuración pendiente

## Estado del proyecto sin facturación

Por decisión del usuario se mantiene Spark, sin activar Blaze ni desplegar
servicios de pago. PV7 y PV9 usan Firestore. PV8 está implementado con Storage,
pero la selección/subida permanece desactivada en la configuración local para
evitar intentos contra un servicio no habilitado. Se pueden seguir usando URLs.
PV10 tiene cliente y servidor implementados, pero no envía avisos automáticos
reales hasta desplegar Cloud Functions. No se sustituyeron por falsas notificaciones.

La clave pública VAPID proporcionada quedó en `config/firebase.local.json`,
que está ignorado por Git. No es una clave privada. El worker incluye solo la
configuración pública del proyecto `petverse-29db2`; si se cambia de proyecto,
hay que actualizar `web/firebase-messaging-sw.js` y la comprobación del cliente.

Referencias oficiales:
[Storage requiere Blaze](https://firebase.google.com/docs/storage/flutter/start),
[Functions: preparación y despliegue](https://firebase.google.com/docs/functions/get-started),
[FCM web y VAPID](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## Lo necesario ahora: reglas y reinicio

1. Firebase > Firestore > Reglas: reemplazar por el contenido completo de
   `firestore.rules` y pulsar Publicar. No hace falta crear las colecciones a mano.
   Esto es necesario también para guardar perfiles: ahora se escribe un directorio
   público mínimo junto con el perfil privado.
2. Detener la app y ejecutar:

```powershell
flutter pub get
flutter run -d chrome --web-port 5000 --dart-define-from-file=config/firebase.local.json
```

El puerto estable evita cambiar de origen y de permiso push en cada ejecución.
Si el puerto 5000 está ocupado, elegir otro puerto libre y conservarlo.

## PV7: adopciones

- Registrar una mascota propia en Mi perfil, con sus fotos y bio.
- Adopciones > Publicar adopción: elegir la mascota, indicar ciudad/provincia y
  condiciones. Se publica una instantánea de sus datos, sin el email del dueño.
- Se combinan tipo, edades (<2, 2-7, 8+) y ubicación; la búsqueda no distingue
  mayúsculas ni acentos. Mis avisos limita la grilla a los propios.
- Repetir el aviso de una misma mascota actualiza su publicación, no la duplica.
- Otra cuenta puede abrir el detalle y enviar nombre y consulta mediante el
  formulario. Se entrega como mensaje privado; no se envía un email externo.
- Solo el responsable puede cerrar su aviso, con confirmación. Puede republicarlo.

## PV8: archivos (preparado, desactivado)

En publicaciones se admiten JPG/JPEG/PNG/WebP/GIF (hasta 10 MB) y MP4/WebM/MOV
(hasta 50 MB). El navegador debe soportar el códec del video para reproducirlo;
no se transcodifica. Perfil y mascotas solo admiten imágenes. Se suben bytes
con `putData`, con progreso de `snapshotEvents` y cancelación. La URL devuelta
se incorpora al formulario; hay que guardar/publicar para asociarla al documento.

Solo si el usuario decide activar facturación más adelante:

1. Habilitar Blaze y crear el bucket de Storage, verificando nombre y región.
2. Publicar `storage.rules` en Storage > Reglas.
3. Cambiar `FIREBASE_STORAGE_ENABLED` a `"true"` en la configuración local y
   reiniciar la app. El valor predeterminado es `false`.
4. Probar una imagen, un video, cancelación, error y persistencia al recargar.

Los archivos usan `users/{uid}/media/{archivo}`. Solo su propietario crea/borra;
no se permite sobrescribir. Los enlaces de descarga son enlaces compartibles:
no usar este contenedor para documentos sensibles. Un archivo subido y luego
abandonado sin guardar puede quedar huérfano; eliminarlo desde Storage si no se usa.

## PV9: mensajería

- Mensajes > Nuevo chat permite buscar miembros por nombre. Los usuarios antiguos
  aparecen cuando vuelven a iniciar la app, que sincroniza su perfil público mínimo.
- También se abre desde el icono de chat de una publicación ajena o desde adopciones.
- El mismo par de usuarios abre siempre el mismo chat, independientemente del iniciador.
- El historial tiene fechas del servidor y se actualiza por suscripción. Mensajes
  vacíos o mayores de 2000 caracteres se rechazan; un fallo conserva el borrador.
- Solo los dos participantes pueden consultar el chat; no se pueden sustituir
  participantes ni editar/borrar mensajes ya enviados. El resumen y el mensaje
  se escriben juntos de forma atómica.
- El directorio `publicProfiles` expone únicamente nombre/foto. `users`, tokens,
  mascotas privadas y chats no se vuelven públicos. Un cambio de sesión descarta
  las pantallas privadas abiertas.

## PV10: push (registro preparado; envío automático pendiente)

La campana > Activar notificaciones solicita permiso expresamente. Requiere
localhost o HTTPS, un navegador compatible y la clave pública VAPID del mismo
proyecto. No es necesario agregar scripts Firebase a `index.html`: FlutterFire
carga el SDK, y FCM registra `firebase-messaging-sw.js` al obtener el token.

El token se guarda en `users/{uid}/devices/{id}`. El botón de salida revoca el token
antes de cerrar sesión. Los avisos en primer plano aparecen dentro de la app;
en segundo plano los muestra FCM usando el worker. No se agrega otro manejador
que duplique los avisos del navegador. El historial es privado y solo lo escribe
el servidor. Los push de mensajes no incluyen el contenido del chat en la pantalla bloqueada.

El backend contiene tres disparadores y una bandeja de salida durable:

- `onNewLike`: solo nuevos UID, excluyendo el like del propio autor.
- `onNewComment`: avisa al dueño de la publicación, salvo comentario propio.
- `onNewMessage`: avisa al otro participante.
- `deliverNotification`: envía a los dispositivos registrados y elimina tokens
  permanentemente inválidos. IDs estables evitan duplicar el historial cuando
  Firestore reentrega eventos. Un fallo entre FCM y el registro de entrega puede
  repetir un envío; la etiqueta estable reduce duplicados visibles.

No se desplegó nada. Si más adelante se autoriza Blaze, usar Node 22, instalar
las dependencias y desplegar únicamente funciones y reglas; no desplegar hosting
ni Vercel como parte de estos PV:

```powershell
cd functions
npm ci
npm test
cd ..
firebase deploy --project petverse-29db2 --only firestore:rules,storage,functions
```

El parámetro opcional `APP_URL` se configura con una URL HTTPS real si se desea
que el clic abra la app publicada. No se inventó una URL desplegada. No subir
cuentas de servicio ni claves privadas al cliente o al repositorio.

## Verificación reproducible sin facturación

```powershell
flutter analyze
flutter test
cd test/firestore
npm ci
npm test
cd ../../functions
npm ci
npm test
```

Las pruebas de reglas requieren Node 24.12+ y Java 21+; el servidor desplegado
usa Node 22. Los emuladores prueban Firestore y Storage en el proyecto ficticio
`demo-petverse-tests`, nunca en el Firebase real. Incluyen snapshots, privacidad,
remitentes falsos, reglas de archivos y progreso de una subida local. Los tests
de servidor cubren cálculo de destinatarios/IDs, tipos de avisos y tokens inválidos.
No equivalen a verificar entrega push real de extremo a extremo.

Si OneDrive vuelve a bloquear `build` durante los tests, ejecutar una copia del
proyecto fuera de OneDrive, excluyendo `.git`, `.dart_tool`, `build` y
`node_modules`. La carpeta original sigue siendo la fuente de trabajo.
