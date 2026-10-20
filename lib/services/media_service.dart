import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Archivo seleccionado y validado antes de cargarlo en memoria.
class MediaFile {
  const MediaFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  String get extension => name.split('.').last.toLowerCase();
  bool get isVideo => ['mp4', 'webm', 'mov'].contains(extension);
  String get contentType => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    _ => throw ArgumentError('Formato no admitido.'),
  };
  void validate() {
    contentType;
    final limit = isVideo ? 50 * 1024 * 1024 : 10 * 1024 * 1024;
    if (bytes.isEmpty || bytes.length > limit) {
      throw ArgumentError('Máximo: 10 MB por imagen y 50 MB por video.');
    }
  }
}

/// Upload web con Uint8List; la UI se suscribe al progreso real de Storage.
abstract interface class MediaService {
  bool get available;
  Future<String> upload(
    String uid,
    MediaFile file,
    void Function(double) progress,
  );
  Future<void> cancel();
}

/// Instancia por selector para no cancelar subidas de otra pantalla.
class FirebaseMediaService implements MediaService {
  UploadTask? _task;
  @override
  bool get available => true;
  @override
  Future<String> upload(
    String uid,
    MediaFile file,
    void Function(double) progress,
  ) async {
    file.validate();
    final ref = FirebaseStorage.instance.ref(
      'users/$uid/media/'
      '${DateTime.now().microsecondsSinceEpoch}.${file.extension}',
    );
    final task = ref.putData(
      file.bytes,
      SettableMetadata(contentType: file.contentType),
    );
    _task = task;
    final subscription = task.snapshotEvents.listen((event) {
      if (event.totalBytes > 0) {
        progress(event.bytesTransferred / event.totalBytes);
      }
    }, onError: (Object _) {});
    try {
      final result = await task;
      return await result.ref.getDownloadURL();
    } finally {
      await subscription.cancel();
      _task = null;
    }
  }

  @override
  Future<void> cancel() async {
    await _task?.cancel();
  }
}

/// La demo no finge almacenar archivos ni devuelve enlaces inexistentes.
class UnavailableMediaService implements MediaService {
  @override
  bool get available => false;
  @override
  Future<String> upload(
    String uid,
    MediaFile file,
    void Function(double) progress,
  ) =>
      Future.error(StateError('Storage no está habilitado en esta ejecución.'));
  @override
  Future<void> cancel() async {}
}
