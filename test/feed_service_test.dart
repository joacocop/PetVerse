import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petverse/models/post.dart';
import 'package:petverse/models/post_comment.dart';
import 'package:petverse/providers/feed_provider.dart';
import 'package:petverse/services/feed_service.dart';

Post post(String caption, DateTime date,
        {PostMediaType type = PostMediaType.image}) =>
    Post(
        id: '',
        authorId: 'alice',
        authorName: 'Alice',
        authorPhotoUrl: '',
        petId: 'luna',
        petName: 'Luna',
        caption: caption,
        mediaUrl: 'https://example.com/media',
        mediaType: type,
        createdAt: date);

PostComment comment(String postId, String userId, String text) => PostComment(
    id: '',
    postId: postId,
    authorId: userId,
    authorName: userId,
    authorPhotoUrl: '',
    text: text,
    createdAt: DateTime.now());

void main() {
  late DemoFeedService service;
  setUp(() => service = DemoFeedService());
  tearDown(() => service.dispose());

  test('Dos lectores reciben las publicaciones ordenadas por fecha', () async {
    final first = StreamIterator(service.watchPosts());
    final second = StreamIterator(service.watchPosts());
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    await first.moveNext();
    await second.moveNext();
    expect(first.current, isEmpty);
    await service.createPost(post('Nueva', DateTime(2026, 10, 20)));
    await first.moveNext();
    await second.moveNext();
    await service.createPost(
        post('Anterior', DateTime(2026, 10, 19), type: PostMediaType.video));
    await first.moveNext();
    await second.moveNext();
    expect(first.current.map((item) => item.caption), ['Nueva', 'Anterior']);
    expect(second.current.map((item) => item.id),
        first.current.map((item) => item.id));
    expect(first.current.last.mediaType, PostMediaType.video);
  });

  test('Likes idempotentes preservan las reacciones de otros usuarios',
      () async {
    await service.createPost(post('Luna', DateTime.now()));
    final id = (await service.watchPosts().first).single.id;
    await Future.wait([
      service.setLiked(id, 'alice', true),
      service.setLiked(id, 'bob', true),
    ]);
    await service.setLiked(id, 'alice', true);
    final liked = (await service.watchPosts().first).single;
    expect(liked.likeCount, 2);
    expect(liked.likedBy, {'alice', 'bob'});
    await service.setLiked(id, 'alice', false);
    expect((await service.watchPosts().first).single.likedBy, {'bob'});
  });

  test('Comentarios en tiempo real y eliminación solo por el autor', () async {
    await service.createPost(post('Luna', DateTime.now()));
    final id = (await service.watchPosts().first).single.id;
    final first = StreamIterator(service.watchComments(id));
    final second = StreamIterator(service.watchComments(id));
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    await first.moveNext();
    await second.moveNext();
    await service.addComment(comment(id, 'bob', '¡Qué linda!'));
    await first.moveNext();
    await second.moveNext();
    expect(second.current.single.text, '¡Qué linda!');
    final saved = first.current.single;
    final forged = PostComment(
        id: saved.id,
        postId: saved.postId,
        authorId: 'alice',
        authorName: 'Alice',
        authorPhotoUrl: '',
        text: saved.text,
        createdAt: saved.createdAt);
    await expectLater(service.deleteComment(forged, 'alice'), throwsStateError);
    expect(await service.watchComments(id).first, hasLength(1));
    await service.deleteComment(saved, 'bob');
    await first.moveNext();
    await second.moveNext();
    expect(first.current, isEmpty);
    expect(second.current, isEmpty);
  });

  test('Provider rechaza vacíos y limpia los datos al cerrar sesión', () async {
    final ownedService = DemoFeedService();
    final feed = FeedProvider(service: ownedService)..bindUser('alice');
    addTearDown(feed.dispose);
    expect(
        await feed.publish(
            petId: 'luna',
            petName: 'Luna',
            authorName: 'Alice',
            authorPhotoUrl: '',
            caption: '',
            mediaUrl: 'javascript:alert(1)',
            mediaType: PostMediaType.image),
        isFalse);
    expect(
        await feed.comment(
            postId: 'missing',
            authorName: 'Alice',
            authorPhotoUrl: '',
            text: '   '),
        isFalse);
    await ownedService.createPost(post('Luna', DateTime.now()));
    await Future<void>.delayed(Duration.zero);
    expect(feed.posts, hasLength(1));
    feed.bindUser(null);
    expect(feed.posts, isEmpty);
    expect(feed.isLoading, isFalse);
  });
}
