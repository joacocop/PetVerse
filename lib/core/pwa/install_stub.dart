import 'install_service.dart';

/// Crea la alternativa para plataformas sin beforeinstallprompt.
InstallService createService() => _StubInstallService();

class _StubInstallService implements InstallService {
  @override
  String get state => 'manual';
  @override
  String get instructions =>
      'Abrí PetVerse desde un navegador compatible y usá su menú Instalar aplicación o Agregar a inicio.';
  @override
  Stream<String> get changes => const Stream.empty();
  @override
  Future<String> request() async => 'manual';
  @override
  void dispose() {}
}
