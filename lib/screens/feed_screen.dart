import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/feed_provider.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';

/// Feed cronológico de publicaciones de toda la comunidad autenticada.
class FeedScreen extends StatelessWidget {
  const FeedScreen({required this.user, super.key});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          key: const PageStorageKey('community-feed'),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          itemCount: feed.posts.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Momentos de la comunidad',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Las últimas historias, con sus protagonistas.'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePostScreen(user: user),
                      ),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Nueva publicación'),
                  ),
                  const SizedBox(height: 20),
                  if (feed.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (feed.feedError != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(feed.feedError!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: feed.retry,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (feed.posts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.pets_outlined, size: 56),
                            SizedBox(height: 16),
                            Text('Todavía no hay publicaciones.'),
                            SizedBox(height: 8),
                            Text('Comparte el primer momento de tu mascota.',
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }
            final post = feed.posts[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: PostCard(
                key: ValueKey('${user.id}-${post.id}'),
                post: post,
                user: user,
              ),
            );
          },
        ),
      ),
    );
  }
}
