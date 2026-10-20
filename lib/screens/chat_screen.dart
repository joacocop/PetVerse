import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/community.dart';
import '../services/community_service.dart';
import '../widgets/feed_author.dart';

/// Abre la misma conversación desde el directorio, feed o adopción.
Future<void> openConversation(
  BuildContext context,
  AppUser user,
  String peerId,
  String peerName, {
  String? contactText,
}) async {
  final service = context.read<CommunityService>();
  try {
    final id = await service.openChat(user.id, peerId);
    if (contactText != null) await service.send(id, user.id, contactText);
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          key: ValueKey('${user.id}-$id'),
          user: user,
          chatId: id,
          peerName: peerName,
        ),
      ),
    );
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir la conversación. Revisá la conexión y las reglas de Firestore.',
          ),
        ),
      );
    }
    rethrow;
  }
}

/// Bandeja privada, ordenada por actividad sin requerir un índice compuesto.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({required this.user, super.key});
  final AppUser user;
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final _chats = context.read<CommunityService>().chats(widget.user.id);
  late final _users = context.read<CommunityService>().users();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<CommunityUser>>(
    stream: _users,
    builder: (context, people) {
      final users = people.data ?? [];
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Text(
                      'Mensajes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _PeopleDialog(user: widget.user, users: users),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Nuevo chat'),
                    ),
                  ],
                ),
              ),
              if (people.hasError)
                const Text(
                  'No se pudo cargar el directorio. Revisá las reglas de Firestore.',
                ),
              Expanded(
                child: StreamBuilder<List<Chat>>(
                  stream: _chats,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('No se pudieron cargar los chats.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final chats = snapshot.data!;
                    if (chats.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Todavía no hay conversaciones. Elegí Nuevo chat o escribile a alguien desde una publicación.',
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, i) {
                        final chat = chats[i];
                        final peer = chat.other(widget.user.id);
                        final person = users
                            .where((u) => u.id == peer)
                            .firstOrNull;
                        return ListTile(
                          leading: FeedAvatar(url: person?.photoUrl ?? ''),
                          title: Text(person?.name ?? 'Miembro de PetVerse'),
                          subtitle: Text(
                            chat.lastText.isEmpty
                                ? 'Iniciá la conversación'
                                : chat.lastText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: MediaQuery.sizeOf(context).width < 600
                              ? null
                              : Text(feedDate(chat.updatedAt)),
                          onTap: () async {
                            try {
                              await openConversation(
                                context,
                                widget.user,
                                peer,
                                person?.name ?? 'Conversación',
                              );
                            } on Object {
                              /* El helper ya muestra el error. */
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PeopleDialog extends StatefulWidget {
  const _PeopleDialog({required this.user, required this.users});
  final AppUser user;
  final List<CommunityUser> users;
  @override
  State<_PeopleDialog> createState() => _PeopleDialogState();
}

class _PeopleDialogState extends State<_PeopleDialog> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final people = widget.users
        .where(
          (u) =>
              u.id != widget.user.id &&
              normalized(u.name).contains(normalized(_query)),
        )
        .toList();
    return AlertDialog(
      title: const Text('Nueva conversación'),
      content: SizedBox(
        width: 420,
        height: MediaQuery.sizeOf(context).height < 550 ? 220 : 360,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Buscar por nombre'),
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: people.isEmpty
                  ? const Center(
                      child: Text('No hay otros miembros disponibles.'),
                    )
                  : ListView(
                      children: people
                          .map(
                            (person) => ListTile(
                              leading: FeedAvatar(url: person.photoUrl),
                              title: Text(person.name),
                              onTap: () async {
                                final parent = Navigator.of(context).context;
                                Navigator.pop(context);
                                try {
                                  await openConversation(
                                    parent,
                                    widget.user,
                                    person.id,
                                    person.name,
                                  );
                                } on Object {
                                  /* Error visible en el helper. */
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Historial en tiempo real; enviar conserva el borrador si falla.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.user,
    required this.chatId,
    required this.peerName,
    super.key,
  });
  final AppUser user;
  final String chatId;
  final String peerName;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  late final _messages = context.read<CommunityService>().messages(
    widget.chatId,
    widget.user.id,
  );
  bool _sending = false;
  String? _error;
  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    final draft = _text.text;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<CommunityService>().send(
        widget.chatId,
        widget.user.id,
        draft,
      );
      if (mounted && _text.text == draft) _text.clear();
    } on Object {
      if (mounted) {
        setState(() => _error = 'No se envió el mensaje. Podés reintentarlo.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.peerName)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Sin acceso a esta conversación o sin conexión.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Escribí el primer mensaje.'),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[messages.length - 1 - i];
                      final own = m.senderId == widget.user.id;
                      return Align(
                        alignment: own
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Card(
                            color: own
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(m.text),
                                  const SizedBox(height: 4),
                                  Text(
                                    feedDate(m.timestamp),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null) Text(_error!),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(labelText: 'Mensaje'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Enviar mensaje',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
