/// Usuario autenticado dentro de PetVerse.
class AppUser {
  /// Crea una representación mínima de un usuario autenticado.
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Identificador único del usuario.
  final String id;

  /// Email asociado a la cuenta.
  final String email;

  /// Nombre público, si está disponible.
  final String? displayName;

  /// Foto pública del usuario, si está disponible.
  final String? photoUrl;
}
