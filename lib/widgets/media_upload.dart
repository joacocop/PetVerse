import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/firebase/firebase_bootstrap.dart';
import '../services/media_service.dart';

/// Selector reutilizable para publicaciones, fotos de perfil y mascotas.
class MediaUpload extends StatefulWidget {
  const MediaUpload({
    required this.uid,
    required this.onUploaded,
    this.onBusy,
    this.imagesOnly = false,
    super.key,
  });
  final String uid;
  final void Function(String url, bool video) onUploaded;
  final ValueChanged<bool>? onBusy;
  final bool imagesOnly;
  @override
  State<MediaUpload> createState() => _MediaUploadState();
}

class _MediaUploadState extends State<MediaUpload> {
  late final MediaService _service =
      FirebaseBootstrap.isReady &&
          const bool.fromEnvironment('FIREBASE_STORAGE_ENABLED')
      ? FirebaseMediaService()
      : UnavailableMediaService();
  bool _busy = false;
  double _progress = 0;
  String? _error;
  String? _uploaded;
  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _uploaded = null;
      _progress = 0;
    });
    widget.onBusy?.call(true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          if (!widget.imagesOnly) ...['mp4', 'webm', 'mov'],
        ],
        withData: false,
        withReadStream: true,
      );
      if (result == null || !mounted) return;
      final selected = result.files.single;
      final limit = widget.imagesOnly ? 10 : 50;
      if (selected.size > limit * 1024 * 1024) {
        throw ArgumentError('El archivo supera el límite de $limit MB.');
      }
      // Se controla tamaño antes de reunir los bytes; evita archivos gigantes.
      final chunks = await selected.readStream!.toList();
      final builder = BytesBuilder(copy: false);
      for (final chunk in chunks) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (!mounted) return;
      final file = MediaFile(selected.name, bytes);
      file.validate();
      final url = await _service.upload(widget.uid, file, (value) {
        if (mounted) setState(() => _progress = value);
      });
      if (!mounted) return;
      widget.onUploaded(url, file.isVideo);
      setState(() => _uploaded = selected.name);
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.code) {
            'canceled' => 'Subida cancelada.',
            'unauthorized' =>
              'Storage rechazó la subida. Revisá las reglas publicadas.',
            _ =>
              'No se pudo subir el archivo (${e.code}). Storage requiere '
                  'estar habilitado con Blaze; podés seguir usando enlaces.',
          },
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ArgumentError
              ? '${e.message}'
              : 'No se pudo seleccionar o subir el archivo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusy?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: !_service.available || _busy ? null : _pick,
        icon: const Icon(Icons.upload_file),
        label: Text(
          widget.imagesOnly
              ? 'Subir foto desde el dispositivo'
              : 'Subir imagen o video',
        ),
      ),
      if (!_service.available)
        Text(
          FirebaseBootstrap.isReady
              ? 'Storage desactivado: seguimos sin facturación. Podés usar una URL.'
              : 'La demo no sube archivos. Podés usar una URL.',
        ),
      if (_busy) ...[
        LinearProgressIndicator(value: _progress),
        Text('Subiendo: ${(_progress * 100).round()}%'),
        TextButton(
          onPressed: _service.cancel,
          child: const Text('Cancelar subida'),
        ),
      ],
      if (_uploaded != null) Text('Archivo subido: $_uploaded'),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
  @override
  void dispose() {
    _service.cancel();
    super.dispose();
  }
}
