import 'dart:async';
import 'dart:js_interop';
import 'install_service.dart';

@JS('petversePwaState')
external JSString _state();
@JS('petversePwaInstructions')
external JSString _instructions();
@JS('petversePwaInstall')
external JSPromise<JSString> _install();
@JS('petversePwaSubscribe')
external void _subscribe(JSFunction callback);
@JS('petversePwaUnsubscribe')
external void _unsubscribe(JSFunction callback);

/// Crea el puente cargado por pwa.js antes de Flutter.
InstallService createService() => _WebInstallService();

class _WebInstallService implements InstallService {
  _WebInstallService() {
    _callback = ((JSString state) => _changes.add(state.toDart)).toJS;
    _subscribe(_callback);
  }
  final _changes = StreamController<String>.broadcast();
  late final JSFunction _callback;
  @override
  String get state => _state().toDart;
  @override
  String get instructions => _instructions().toDart;
  @override
  Stream<String> get changes => _changes.stream;
  @override
  Future<String> request() async => (await _install().toDart).toDart;
  @override
  void dispose() {
    _unsubscribe(_callback);
    _changes.close();
  }
}
