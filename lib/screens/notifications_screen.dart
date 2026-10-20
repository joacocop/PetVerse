import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../providers/notification_provider.dart';

/// Preferencias de este dispositivo e historial privado creado por el servidor.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.user, super.key});
  final AppUser user;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final _history = context.read<NotificationProvider>().firebaseReady
      ? FirebaseFirestore.instance
            .collection('users/${widget.user.id}/notifications')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
      : null;
  @override
  Widget build(BuildContext context) {
    final push = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Avisos de likes, comentarios y mensajes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Activá las notificaciones para este navegador. El permiso no activa el envío automático: '
                'también deben estar desplegadas las funciones del servidor. No habilitamos facturación desde la app.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: push.busy ? null : push.enable,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                  push.enabled
                      ? 'Actualizar registro push'
                      : 'Activar notificaciones',
                ),
              ),
              TextButton(
                onPressed: push.busy
                    ? null
                    : () async {
                        try {
                          await push.disable();
                        } on Object {
                          /* El estado contiene el error. */
                        }
                      },
                child: const Text('Desactivar en este navegador'),
              ),
              if (push.busy) const LinearProgressIndicator(),
              if (push.status != null) Text(push.status!),
              const Divider(height: 40),
              if (_history == null)
                const Text('La demo no genera ni recibe push reales.')
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _history,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'No se pudo cargar el historial. Revisá las reglas.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return const Text('Todavía no hay notificaciones.');
                    }
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data();
                        return ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: Text(data['title'] as String? ?? 'PetVerse'),
                          subtitle: Text(data['body'] as String? ?? ''),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
