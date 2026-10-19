import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/post.dart';

/// Imágenes y videos de URL directa; los archivos se subirán en PV8.
class PostMedia extends StatelessWidget {
  const PostMedia({required this.url, required this.type, super.key});
  final String url;
  final PostMediaType type;

  @override
  Widget build(BuildContext context) {
    if (type == PostMediaType.video) return _PostVideo(url: url);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ColoredBox(
        color: const Color(0xFFFFF1EB),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => const _MediaError(
            message: 'No se pudo cargar la imagen. Revisa su enlace.',
          ),
        ),
      ),
    );
  }
}

class _PostVideo extends StatefulWidget {
  const _PostVideo({required this.url});
  final String url;

  @override
  State<_PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<_PostVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      // La reproducción comienza silenciada para respetar las políticas web.
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() => _loading = false);
    } on Object {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: _MediaError(
          message: 'No se pudo reproducir el video. Usa un enlace directo '
              'compatible con tu navegador, por ejemplo MP4.',
        ),
      );
    }
    if (controller == null || _loading || !controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: const Color(0xFF292323),
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reproducir video'),
                  ),
          ),
        ),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        children: [
          AspectRatio(
            aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
            child: VideoPlayer(controller),
          ),
          VideoProgressIndicator(controller, allowScrubbing: true),
          Row(
            children: [
              IconButton(
                tooltip: value.isPlaying ? 'Pausar video' : 'Reproducir video',
                onPressed: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: value.volume == 0 ? 'Activar sonido' : 'Silenciar',
                onPressed: () =>
                    controller.setVolume(value.volume == 0 ? 1 : 0),
                icon: Icon(
                    value.volume == 0 ? Icons.volume_off : Icons.volume_up),
              ),
              if (value.isBuffering)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 40),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
