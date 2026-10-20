import 'install_stub.dart'
    if (dart.library.js_interop) 'install_web.dart'
    as platform;

/// Contrato portable del puente de instalación del navegador.
abstract interface class InstallService {
  /// Estado actual: available, installed o manual.
  String get state;

  /// Instrucciones cuando el navegador no ofrece un diálogo programático.
  String get instructions;

  /// Cambios de disponibilidad e instalación.
  Stream<String> get changes;

  /// Solicita el diálogo desde el gesto del usuario; no simula su aceptación.
  Future<String> request();

  /// Libera eventos y callbacks.
  void dispose();
}

/// Selecciona el puente web o una implementación sin navegador para tests.
InstallService createInstallService() => platform.createService();
