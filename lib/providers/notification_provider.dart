import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Mensaje recibido en primer plano, también utilizable por la interfaz.
class PushNotice {
  const PushNotice(this.title, this.body);
  final String title;
  final String body;
}

/// Alta voluntaria de FCM y limpieza del token antes de cerrar sesión.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required this.firebaseReady});
  final bool firebaseReady;
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
  // El worker contiene exclusivamente configuración pública del proyecto.
  static const workerProject = 'petverse-29db2';
  String? _uid;
  String? _token;
  bool busy = false;
  bool enabled = false;
  String? status;
  bool _disposed = false;
  int _session = 0;
  Future<void> _revocation = Future.value();
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<String>? _refresh;
  final _notices = StreamController<PushNotice>.broadcast();
  Stream<PushNotice> get notices => _notices.stream;

  /// Evita mostrar avisos de otra cuenta después de un cambio de sesión.
  void bindUser(String? uid) {
    if (_uid == uid) return;
    _session++;
    _uid = uid;
    enabled = false;
    status = null;
    _foreground?.cancel();
    _refresh?.cancel();
    if (firebaseReady && _token != null) {
      // Si Auth cambia fuera del botón de salida, revoca igualmente FCM.
      // Ya no puede borrarse el documento privado anterior sin esa sesión;
      // el servidor eliminará ese token cuando FCM lo reporte inválido.
      _revocation = _revocation.then(
        (_) => FirebaseMessaging.instance.deleteToken(),
      );
      _revocation = _revocation.catchError((Object _) {
        status =
            'No se pudo revocar el registro anterior. Desactivá push antes de cambiar de cuenta.';
        _notify();
      });
      _token = null;
    }
    if (!firebaseReady || uid == null) return;
    _foreground = FirebaseMessaging.onMessage.listen((message) {
      if (_uid != uid || message.data['targetUid'] != uid) return;
      _notices.add(
        PushNotice(
          message.notification?.title ?? 'PetVerse',
          message.notification?.body ?? 'Tenés una nueva notificación.',
        ),
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _tokenRef(String uid, String token) =>
      FirebaseFirestore.instance
          .collection('users/$uid/devices')
          .doc(base64Url.encode(utf8.encode(token)).replaceAll('=', ''));
  Future<void> _save(String uid, String token) => _tokenRef(uid, token).set({
    'token': token,
    'updatedAt': FieldValue.serverTimestamp(),
    'platform': 'web',
  });

  /// Debe llamarse desde un botón: no solicita permisos al cargar la página.
  Future<void> enable() async {
    if (busy) return;
    final uid = _uid;
    final session = _session;
    if (uid == null) return;
    busy = true;
    status = null;
    _notify();
    try {
      await _revocation;
      if (!firebaseReady) {
        throw StateError('La demo no envía notificaciones push.');
      }
      if (vapidKey.isEmpty) {
        throw StateError(
          'Falta FIREBASE_VAPID_KEY en config/firebase.local.json.',
        );
      }
      if (Firebase.app().options.projectId != workerProject) {
        throw StateError(
          'Actualizá la configuración pública del service worker para este proyecto.',
        );
      }
      final messaging = FirebaseMessaging.instance;
      if (!await messaging.isSupported()) {
        throw StateError(
          'Este navegador no admite push. Usá HTTPS o localhost.',
        );
      }
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        throw StateError(
          'No se concedió permiso. Podés cambiarlo en la configuración del navegador.',
        );
      }
      final token = await messaging.getToken(vapidKey: vapidKey);
      if (token == null) throw StateError('Firebase no devolvió un token.');
      if (_session != session) {
        await messaging.deleteToken();
        return;
      }
      await _save(uid, token);
      if (_session != session) {
        await messaging.deleteToken();
        return;
      }
      _token = token;
      enabled = true;
      status =
          'Este navegador está registrado. El envío automático requiere desplegar Cloud Functions (Blaze).';
      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((newToken) async {
        if (_session != session) return;
        try {
          final old = _token;
          await _save(uid, newToken);
          _token = newToken;
          if (old != null && old != newToken) {
            await _tokenRef(uid, old).delete();
          }
        } on Object {
          status = 'No se pudo renovar el registro push. Volvé a activarlo.';
          _notify();
        }
      });
    } on Object catch (e) {
      status = e is StateError
          ? e.message.toString()
          : 'No se pudo activar push. Revisá VAPID, el worker y las reglas de Firestore.';
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Revoca la suscripción del navegador, incluso si el servidor no está disponible.
  Future<void> disable() async {
    if (busy) return;
    busy = true;
    _notify();
    await _refresh?.cancel();
    try {
      if (firebaseReady && await FirebaseMessaging.instance.isSupported()) {
        final messaging = FirebaseMessaging.instance;
        final permission = await messaging.getNotificationSettings();
        final token =
            _token ??
            (vapidKey.isNotEmpty &&
                    permission.authorizationStatus ==
                        AuthorizationStatus.authorized
                ? await messaging.getToken(vapidKey: vapidKey)
                : null);
        // Primero revoca FCM; un fallo de Firestore no deja un token activo.
        if (token != null) await messaging.deleteToken();
        if (_uid != null && token != null) {
          await _tokenRef(_uid!, token).delete();
        }
      }
      _token = null;
      enabled = false;
      status = 'Notificaciones desactivadas en este navegador.';
    } on Object {
      status =
          'No se pudo confirmar la baja. Reintentá antes de cambiar de cuenta.';
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    _foreground?.cancel();
    _refresh?.cancel();
    _notices.close();
    super.dispose();
  }
}
