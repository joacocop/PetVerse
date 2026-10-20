import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gamification_provider.dart';

/// Puntos, progreso de nivel y catálogo de insignias desbloqueables.
class GamificationCard extends StatelessWidget {
  /// Crea la tarjeta del perfil.
  const GamificationCard({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<GamificationProvider>();
    final summary = state.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mis logros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (state.loading)
              const LinearProgressIndicator()
            else if (state.error != null) ...[
              Text(state.error!),
              TextButton(
                onPressed: state.retry,
                child: const Text('Reintentar logros'),
              ),
            ] else ...[
              Text(
                '${summary.points} puntos · ${summary.level}',
                key: const ValueKey('gamification-points'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: summary.progress),
              const SizedBox(height: 6),
              Text(
                summary.nextLevelAt == null
                    ? '¡Alcanzaste el nivel máximo!'
                    : 'Te faltan ${summary.nextLevelAt! - summary.points} puntos para el próximo nivel.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.badges
                    .map(
                      (badge) => Tooltip(
                        message: badge.description,
                        child: Chip(
                          avatar: Icon(
                            badge.unlocked
                                ? Icons.workspace_premium
                                : Icons.lock_outline,
                            size: 20,
                            color: badge.unlocked
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          label: Text(badge.name),
                          backgroundColor: badge.unlocked
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Publicar: +10 · Me gusta: +2 · Comentar: +3.\n'
              'Likes y comentarios: una vez por publicación ajena. Quitar o borrar no vuelve a sumar.',
            ),
          ],
        ),
      ),
    );
  }
}
