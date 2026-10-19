import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/pet_service.dart';
import 'services/profile_service.dart';

/// Punto de entrada de PetVerse.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseBootstrap.initialize();
  runApp(PetVerseApp(firebaseReady: firebaseReady));
}

/// Aplicación raíz y composición de dependencias.
class PetVerseApp extends StatelessWidget {
  /// Crea la aplicación.
  const PetVerseApp({required this.firebaseReady, super.key});

  /// Indica si se utilizarán repositorios reales de Firebase.
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            service: firebaseReady ? FirebaseAuthService() : DemoAuthService(),
          ),
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
      ],
      child: MaterialApp(
        title: 'PetVerse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _AppGate(),
      ),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.user == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}
