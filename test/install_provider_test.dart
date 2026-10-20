import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:petverse/core/pwa/install_service.dart';
import 'package:petverse/providers/install_provider.dart';

class FakeInstallService implements InstallService {
  final controller = StreamController<String>.broadcast();
  @override
  String state = 'available';
  @override
  String get instructions => 'Menú del navegador';
  @override
  Stream<String> get changes => controller.stream;
  @override
  Future<String> request() async {
    state = 'manual';
    return 'accepted';
  }

  @override
  void dispose() {
    controller.close();
  }
}

void main() {
  test('Aceptar el prompt no inventa que la instalación terminó', () async {
    final browser = FakeInstallService();
    final provider = InstallProvider(service: browser);
    addTearDown(provider.dispose);
    expect(await provider.install(), 'accepted');
    expect(provider.state, 'manual');
    browser.state = 'installed';
    browser.controller.add('installed');
    await Future<void>.delayed(Duration.zero);
    expect(provider.state, 'installed');
    expect(provider.busy, isFalse);
  });
}
