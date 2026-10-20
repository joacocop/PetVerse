import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/install_provider.dart';

/// Botón visible también sin sesión, con ayuda específica por navegador.
class InstallButton extends StatelessWidget {
  /// Crea el botón de instalación de la PWA.
  const InstallButton({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<InstallProvider>();
    return IconButton(
      tooltip: state.state == 'installed'
          ? 'PetVerse instalada'
          : 'Instalar PetVerse',
      icon: Icon(
        state.state == 'installed'
            ? Icons.check_circle_outline
            : Icons.install_desktop_outlined,
      ),
      onPressed: state.busy
          ? null
          : () async {
              final result = await state.install();
              if (!context.mounted ||
                  result == 'accepted' ||
                  result == 'dismissed') {
                return;
              }
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    state.state == 'installed'
                        ? 'PetVerse ya está instalada'
                        : 'Instalar PetVerse',
                  ),
                  content: Text(
                    result == 'error'
                        ? 'No se pudo abrir el instalador. ${state.instructions}'
                        : state.instructions,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              );
            },
    );
  }
}
