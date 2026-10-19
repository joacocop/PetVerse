import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/post.dart';
import '../providers/feed_provider.dart';
import '../providers/pet_provider.dart';
import '../widgets/feed_author.dart';
import '../widgets/post_media.dart';
import 'pet_form_screen.dart';

/// Crea una publicación asociada a una mascota del usuario.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({required this.user, super.key});
  final AppUser user;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caption = TextEditingController();
  final _mediaUrl = TextEditingController();
  PostMediaType _type = PostMediaType.image;
  String? _petId;
  String? _previewUrl;
  PostMediaType _previewType = PostMediaType.image;

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final pets = context.read<PetProvider>().pets;
    final selected = pets.where((pet) => pet.id == _petId);
    if (selected.isEmpty) return;
    final author = feedAuthor(context, widget.user);
    final feed = context.read<FeedProvider>();
    final success = await feed.publish(
      petId: selected.first.id,
      petName: publicName(selected.first.name),
      authorName: author.displayName!,
      authorPhotoUrl: author.photoUrl ?? '',
      caption: _caption.text,
      mediaUrl: _mediaUrl.text,
      mediaType: _type,
    );
    if (mounted && success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación compartida.')),
      );
    }
  }

  String? _validateUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? null
        : 'Ingresa un enlace directo válido (https://…).';
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final pets = context.watch<PetProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Un nuevo momento de tu mascota',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      if (pets.isLoading)
                        const LinearProgressIndicator()
                      else if (pets.pets.isEmpty) ...[
                        const Text(
                            'Registra una mascota para compartir su historia.'),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PetFormScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.pets),
                          label: const Text('Registrar mascota'),
                        ),
                      ] else
                        DropdownButtonFormField<String>(
                          initialValue: _petId,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Mascota *'),
                          items: pets.pets
                              .map((pet) => DropdownMenuItem(
                                    value: pet.id,
                                    child: Text(pet.name,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: feed.isPublishing
                              ? null
                              : (value) => setState(() => _petId = value),
                          validator: (value) => value == null ||
                                  !pets.pets.any((pet) => pet.id == value)
                              ? 'Selecciona una mascota.'
                              : null,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _caption,
                        enabled: !feed.isPublishing,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2200,
                        decoration: const InputDecoration(
                          labelText: '¿Qué está haciendo tu mascota?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PostMediaType>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                            labelText: 'Tipo de contenido'),
                        items: const [
                          DropdownMenuItem(
                              value: PostMediaType.image,
                              child: Text('Imagen')),
                          DropdownMenuItem(
                              value: PostMediaType.video, child: Text('Video')),
                        ],
                        onChanged: feed.isPublishing
                            ? null
                            : (value) => setState(() => _type = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mediaUrl,
                        enabled: !feed.isPublishing,
                        keyboardType: TextInputType.url,
                        maxLength: 4096,
                        decoration: InputDecoration(
                          labelText: _type == PostMediaType.image
                              ? 'URL de la imagen *'
                              : 'URL del video *',
                          helperText: _type == PostMediaType.image
                              ? 'Enlace directo a una imagen disponible en la web.'
                              : 'Enlace directo a un video compatible, por ejemplo MP4.',
                          helperMaxLines: 3,
                        ),
                        validator: _validateUrl,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            if (_validateUrl(_mediaUrl.text) != null) {
                              _formKey.currentState!.validate();
                              return;
                            }
                            setState(() {
                              _previewUrl = _mediaUrl.text.trim();
                              _previewType = _type;
                            });
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Vista previa'),
                        ),
                      ),
                      if (_previewUrl != null)
                        PostMedia(
                          key: ValueKey('$_previewType-$_previewUrl'),
                          url: _previewUrl!,
                          type: _previewType,
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: feed.isPublishing || pets.pets.isEmpty
                            ? null
                            : _publish,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                            feed.isPublishing ? 'Publicando…' : 'Publicar'),
                      ),
                      if (feed.actionError != null) ...[
                        const SizedBox(height: 12),
                        Text(feed.actionError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _caption.dispose();
    _mediaUrl.dispose();
    super.dispose();
  }
}
