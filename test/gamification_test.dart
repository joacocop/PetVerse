import 'package:flutter_test/flutter_test.dart';
import 'package:petverse/models/gamification.dart';
import 'package:petverse/models/post.dart';
import 'package:petverse/models/post_comment.dart';
import 'package:petverse/services/activity_service.dart';
import 'package:petverse/services/feed_service.dart';
import 'package:petverse/providers/gamification_provider.dart';

Post post() => Post(
  id: '',
  authorId: 'alice',
  authorName: 'Alice',
  authorPhotoUrl: '',
  petId: 'luna',
  petName: 'Luna',
  caption: '',
  mediaUrl: 'https://example.com/luna.jpg',
  mediaType: PostMediaType.image,
  createdAt: DateTime.now(),
);
PostComment comment(String id, String uid) => PostComment(
  id: '',
  postId: id,
  authorId: uid,
  authorName: uid,
  authorPhotoUrl: '',
  text: 'Muy linda',
  createdAt: DateTime.now(),
);
void main() {
  test(
    'Acciones reales acreditan una vez; propias y repetir no generan puntos',
    () async {
      final activity = DemoActivityService();
      final feed = DemoFeedService(activityService: activity);
      addTearDown(() {
        feed.dispose();
        activity.dispose();
      });
      await feed.createPost(post());
      final id = (await feed.watchPosts().first).single.id;
      await feed.setLiked(id, 'alice', true);
      await feed.setLiked(id, 'bob', true);
      await feed.setLiked(id, 'bob', false);
      await feed.setLiked(id, 'bob', true);
      await feed.addComment(comment(id, 'alice'));
      await feed.addComment(comment(id, 'bob'));
      await feed.addComment(comment(id, 'bob'));
      final oldComment = (await feed.watchComments(id).first).firstWhere(
        (c) => c.authorId == 'bob',
      );
      await feed.deleteComment(oldComment, 'bob');
      await feed.addComment(comment(id, 'bob'));
      final alice = Gamification(await activity.watch('alice').first);
      final bob = Gamification(await activity.watch('bob').first);
      expect(alice.points, 10);
      expect(bob.points, 5);
      expect(alice.badges.first.unlocked, isTrue);
      expect(bob.count(ActivityKind.comment), 1);
    },
  );
  test(
    'Niveles e insignias se derivan de créditos únicos, incluso duplicados de lectura',
    () {
      final credits = List.generate(
        10,
        (i) => Activity(
          id: 'post_$i',
          kind: ActivityKind.post,
          postId: '$i',
          referenceId: '',
          createdAt: DateTime.now(),
        ),
      );
      final game = Gamification([...credits, credits.first]);
      expect(game.points, 100);
      expect(game.level, 'Embajador');
      expect(game.badges.last.unlocked, isTrue);
      expect(game.progress, 0);
      expect(Gamification([]).level, 'Explorador');
    },
  );
  test('El provider borra el resumen al cambiar de sesión', () async {
    final activity = DemoActivityService();
    final provider = GamificationProvider(service: activity);
    addTearDown(() {
      provider.dispose();
      activity.dispose();
    });
    activity.award('alice', ActivityKind.post, 'p1');
    provider.bindUser('alice');
    await Future<void>.delayed(Duration.zero);
    expect(provider.summary.points, 10);
    provider.bindUser('bob');
    expect(provider.summary.points, 0);
    await Future<void>.delayed(Duration.zero);
    expect(provider.summary.points, 0);
    provider.bindUser(null);
    expect(provider.summary.badges.any((b) => b.unlocked), isFalse);
  });
}
