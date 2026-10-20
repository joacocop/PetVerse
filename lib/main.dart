import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/notification_provider.dart';
import 'services/community_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/feed_service.dart';
import 'services/pet_service.dart';
import 'services/profile_service.dart';

/// Punto de entrada de PetVerse.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseBootstrap.initialize();
  runApp(PetVerseApp(firebaseReady: firebaseReady));
}

/// Aplicación raíz y composición de dependencias.
class PetVerseApp extends StatefulWidget {
  /// Crea la aplicación.
  const PetVerseApp({required this.firebaseReady, super.key});

  /// Indica si se utilizarán repositorios reales de Firebase.
  final bool firebaseReady;

  @override
  State<PetVerseApp> createState() => _PetVerseAppState();
}

class _PetVerseAppState extends State<PetVerseApp> {
  final _navigator = GlobalKey<NavigatorState>();
  bool get firebaseReady => widget.firebaseReady;
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CommunityService>(
          create: (_) => firebaseReady
              ? FirestoreCommunityService()
              : DemoCommunityService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            service: firebaseReady ? FirebaseAuthService() : DemoAuthService(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(firebaseReady: firebaseReady),
          update: (_, auth, push) => push!..bindUser(auth.user?.id),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            service: firebaseReady
                ? FirestoreProfileService()
                : DemoProfileService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PetProvider(
            service: firebaseReady ? FirestorePetService() : DemoPetService(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FeedProvider>(
          create: (_) => FeedProvider(
            service: firebaseReady ? FirestoreFeedService() : DemoFeedService(),
          ),
          update: (_, auth, feed) => feed!..bindUser(auth.user?.id),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigator,
        title: 'PetVerse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _AppGate(navigator: _navigator),
      ),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate({required this.navigator});
  final GlobalKey<NavigatorState> navigator;
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  String? _previousUid;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final uid = auth.user?.id;
        if (_previousUid != null && _previousUid != uid) {
          // También descarta pantallas privadas abiertas si la sesión vence
          // desde otra pestaña o cambia fuera del botón Cerrar sesión.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.navigator.currentState?.popUntil((route) => route.isFirst);
          });
        }
        _previousUid = uid;
        return uid == null
            ? const LoginScreen()
            : HomeScreen(key: ValueKey(uid));
      },
    );
  }
}
