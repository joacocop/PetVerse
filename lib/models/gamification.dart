import 'post.dart';

/// Acciones que conceden puntos; los importes no son editables en Firestore.
enum ActivityKind { post, like, comment }

/// Crédito permanente por una acción única y validada por las reglas.
class Activity {
  /// Crea un crédito asociado a una publicación y, si corresponde, comentario.
  const Activity({
    required this.id,
    required this.kind,
    required this.postId,
    required this.referenceId,
    required this.createdAt,
  });
  final String id;
  final ActivityKind kind;
  final String postId;
  final String referenceId;
  final DateTime createdAt;

  /// Importe fijo de la política de puntos.
  int get points => switch (kind) {
    ActivityKind.post => 10,
    ActivityKind.like => 2,
    ActivityKind.comment => 3,
  };

  /// Reconstruye un crédito de la colección privada de actividad.
  factory Activity.fromMap(String id, Map<String, dynamic> map) => Activity(
    id: id,
    kind: ActivityKind.values.byName(map['kind'] as String),
    postId: map['postId'] as String,
    referenceId: map['referenceId'] as String,
    createdAt: documentDate(map['createdAt']),
  );
}

/// Insignia derivada de hechos verificados, nunca de un campo editable del perfil.
class PetBadge {
  /// Crea una insignia y su condición de desbloqueo.
  const PetBadge(this.name, this.description, this.unlocked);
  final String name;
  final String description;
  final bool unlocked;
}

/// Resumen reproducible; no guarda un contador que el cliente pueda incrementar.
class Gamification {
  /// Calcula puntos, nivel e insignias a partir de créditos únicos.
  Gamification(Iterable<Activity> activities)
    : activities = List.unmodifiable(
        {for (final activity in activities) activity.id: activity}.values,
      );
  final List<Activity> activities;

  /// Suma de créditos únicos; no acepta un total externo editable.
  int get points =>
      activities.fold(0, (sum, activity) => sum + activity.points);

  /// Cuenta acciones de una clase para las condiciones de insignias.
  int count(ActivityKind kind) =>
      activities.where((a) => a.kind == kind).length;

  /// Nivel actual según los umbrales del producto.
  String get level => points >= 250
      ? 'Leyenda'
      : points >= 100
      ? 'Embajador'
      : points >= 25
      ? 'Amigo'
      : 'Explorador';

  /// Umbral del próximo nivel o null al alcanzar el máximo.
  int? get nextLevelAt => points < 25
      ? 25
      : points < 100
      ? 100
      : points < 250
      ? 250
      : null;

  /// Avance entre el nivel actual y el siguiente, de cero a uno.
  double get progress {
    final next = nextLevelAt;
    if (next == null) return 1;
    final previous = points >= 100
        ? 100
        : points >= 25
        ? 25
        : 0;
    return (points - previous) / (next - previous);
  }

  /// Catálogo estable con la condición de cada insignia evaluada.
  List<PetBadge> get badges => [
    PetBadge(
      'Primera huella',
      'Compartí tu primera publicación.',
      count(ActivityKind.post) >= 1,
    ),
    PetBadge(
      'Buen compañero',
      'Dale me gusta a 5 publicaciones ajenas distintas.',
      count(ActivityKind.like) >= 5,
    ),
    PetBadge(
      'Conversador',
      'Comentá 5 publicaciones ajenas distintas.',
      count(ActivityKind.comment) >= 5,
    ),
    PetBadge('Estrella PetVerse', 'Alcanzá 100 puntos.', points >= 100),
  ];
}
