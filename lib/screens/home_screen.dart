import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';
import 'adoptions_screen.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';

/// Contenedor principal después de autenticarse.
class HomeScreen extends StatefulWidget {
  /// Crea la pantalla principal.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<PushNotice>? _notices;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notices ??= context.read<NotificationProvider>().notices.listen((notice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${notice.title}: ${notice.body}')),
      );
    });
  }

  Future<void> _logout() async {
    try {
      await context.read<NotificationProvider>().disable();
      if (mounted) await context.read<AuthProvider>().signOut();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cerrar la sesión de forma segura. Reintentá la baja de notificaciones.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(user: user),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: context.watch<NotificationProvider>().busy
                ? null
                : _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ProfileScreen(user: user),
          FeedScreen(user: user),
          AdoptionsScreen(key: ValueKey('adoptions-${user.id}'), user: user),
          ChatsScreen(key: ValueKey('chats-${user.id}'), user: user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Adopciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Mensajes',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notices?.cancel();
    super.dispose();
  }
}
