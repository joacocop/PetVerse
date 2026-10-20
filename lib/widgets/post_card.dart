import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/post.dart';
import '../providers/feed_provider.dart';
import 'feed_author.dart';
import 'post_comments.dart';
import 'post_media.dart';
import '../screens/chat_screen.dart';

/// Publicación con reacción animada por botón o doble toque sobre el medio.
class PostCard extends StatefulWidget {
  const PostCard({required this.post, required this.user, super.key});
  final Post post;
  final AppUser user;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late final _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 40),
  ]).animate(_heart);
  bool _showComments = false;

  Future<void> _like({bool? liked}) async {
    final feed = context.read<FeedProvider>();
    if (feed.isLiking(widget.post.id)) return;
    final shouldLike = liked ?? !widget.post.isLikedBy(widget.user.id);
    if (shouldLike) _heart.forward(from: 0);
    final success = await feed.like(widget.post, liked: shouldLike);
    if (!mounted || success) return;
    _heart.reset();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feed.actionError ?? 'No se pudo actualizar el like.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final liked = post.isLikedBy(widget.user.id);
    final pending = context.select<FeedProvider, bool>(
      (feed) => feed.isLiking(post.id),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FeedAvatar(url: post.authorPhotoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('Con ${post.petName}'),
                      Text(
                        feedDate(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (post.authorId != widget.user.id)
                  IconButton(
                    tooltip: 'Escribir a ${post.authorName}',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () async {
                      try {
                        await openConversation(
                          context,
                          widget.user,
                          post.authorId,
                          post.authorName,
                        );
                      } on Object {
                        /* Error mostrado por el helper. */
                      }
                    },
                  )
                else
                  const Icon(Icons.pets_outlined),
              ],
            ),
          ),
          GestureDetector(
            key: ValueKey('post-media-${post.id}'),
            onDoubleTap: () => _like(liked: true),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PostMedia(
                  key: ValueKey(post.mediaUrl),
                  url: post.mediaUrl,
                  type: post.mediaType,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _opacity,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.5, end: 1.15).animate(
                          CurvedAnimation(
                            parent: _heart,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 96,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(post.caption),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                IconButton(
                  key: ValueKey('like-${post.id}'),
                  tooltip: liked ? 'Quitar me gusta' : 'Me gusta',
                  onPressed: pending ? null : _like,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(liked),
                      color: liked
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                Text(
                  '${post.likeCount} me gusta',
                  key: ValueKey('like-count-${post.id}'),
                ),
                TextButton.icon(
                  key: ValueKey('comments-${post.id}'),
                  onPressed: () =>
                      setState(() => _showComments = !_showComments),
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: Text(
                    _showComments ? 'Ocultar comentarios' : 'Comentarios',
                  ),
                ),
              ],
            ),
          ),
          if (_showComments)
            PostComments(
              key: ValueKey('comments-${post.id}-${widget.user.id}'),
              postId: post.id,
              user: widget.user,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }
}
