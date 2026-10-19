import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/profile_provider.dart';

/// Toma el perfil editable del autor sin publicar su email en Firestore.
AppUser feedAuthor(BuildContext context, AppUser user) {
  final profile = context.read<ProfileProvider>().profile;
  final ownProfile = profile?.id == user.id ? profile : null;
  return AppUser(
    id: user.id,
    email: user.email,
    displayName: publicName(ownProfile?.name ?? user.displayName ?? 'Usuario'),
    photoUrl: ownProfile?.photoUrl ?? user.photoUrl ?? '',
  );
}

/// Limita las instantáneas públicas al tamaño admitido por las reglas.
String publicName(String name) {
  final value = name.trim().isEmpty ? 'Usuario' : name.trim();
  return value.length > 120 ? value.substring(0, 120) : value;
}

/// Fecha local legible, sin depender de la zona horaria del servidor.
String feedDate(DateTime value) {
  final date = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '· ${two(date.hour)}:${two(date.minute)}';
}

/// Avatar que conserva una alternativa visible si falla la imagen remota.
class FeedAvatar extends StatelessWidget {
  const FeedAvatar({required this.url, super.key});
  final String url;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: SizedBox.square(
          dimension: 40,
          child: url.isEmpty
              ? const ColoredBox(
                  color: Color(0xFFFFE5DA),
                  child: Icon(Icons.person_outline),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_outline),
                ),
        ),
      );
}
