import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/post_comment.dart';
import '../providers/feed_provider.dart';
import 'feed_author.dart';

/// Lista y formulario de comentarios conectados al stream de una publicación.
class PostComments extends StatefulWidget {
  const PostComments({required this.postId, required this.user, super.key});
  final String postId;
  final AppUser user;

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> {
  final _text = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Stream<List<PostComment>>? _comments;
  bool _sending = false;
  final Set<String> _deleting = {};
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _comments ??= context.read<FeedProvider>().commentsFor(widget.postId);
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final feed = context.read<FeedProvider>();
    final author = feedAuthor(context, widget.user);
    setState(() {
      _sending = true;
      _error = null;
    });
    final success = await feed.comment(
      postId: widget.postId,
      authorName: author.displayName!,
      authorPhotoUrl: author.photoUrl ?? '',
      text: _text.text,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (success) {
        _text.clear();
      } else {
        _error = feed.actionError ?? 'No se pudo enviar el comentario.';
      }
    });
  }

  Future<void> _delete(PostComment comment) async {
    final feed = context.read<FeedProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text('¿Quieres eliminar este comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _deleting.add(comment.id));
    final success = await feed.deleteComment(comment);
    if (!mounted) return;
    setState(() {
      _deleting.remove(comment.id);
      if (!success) _error = feed.actionError;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            StreamBuilder<List<PostComment>>(
              stream: _comments,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text('No se pudieron cargar los comentarios.'),
                      TextButton(
                        onPressed: () => setState(() {
                          _comments = context
                              .read<FeedProvider>()
                              .commentsFor(widget.postId);
                        }),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Comentarios (${comments.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    if (comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Sé el primero en comentar.'),
                      ),
                    for (final comment in comments)
                      Padding(
                        key: ValueKey('comment-${comment.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FeedAvatar(url: comment.authorPhotoUrl),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment.authorName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(feedDate(comment.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 4),
                                  Text(comment.text),
                                ],
                              ),
                            ),
                            if (comment.authorId == widget.user.id)
                              IconButton(
                                tooltip: 'Eliminar comentario',
                                onPressed: _deleting.contains(comment.id)
                                    ? null
                                    : () => _delete(comment),
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _text,
                enabled: !_sending,
                minLines: 1,
                maxLines: 3,
                maxLength: 1000,
                decoration:
                    const InputDecoration(labelText: 'Escribe un comentario'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un comentario.'
                    : null,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Enviando…' : 'Comentar'),
              ),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
