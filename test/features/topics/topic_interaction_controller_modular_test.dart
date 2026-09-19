import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
  });

  group('TopicInteractionController Modular Architecture Tests', () {
    late TopicInteractionController controller;

    setUp(() {
      Get.reset();
      Get.put(AuthService());
      controller = Get.put(TopicInteractionController());
    });

    tearDown(Get.reset);

    test('1. Initial state is properly configured', () {
      expect(controller.likeCount.value, equals(0));
      expect(controller.isLiked.value, isFalse);
      expect(controller.commentCount.value, equals(0));
      expect(controller.initialDbLikeCount.value, equals(0));
      expect(controller.dbIsLiked.value, isFalse);
      expect(controller.hasCheckedInteraction.value, isFalse);
      expect(controller.comments, isEmpty);
      expect(controller.isLoadingComments.value, isFalse);
      expect(controller.repliesMap, isEmpty);
      expect(controller.userCommentInteractions, isEmpty);
      expect(controller.userReplyInteractions, isEmpty);
    });

    test('2. displayLikeCount reflects optimistic local interactions', () {
      controller.initialDbLikeCount.value = 10;

      // Has not checked interaction yet -> returns initialDbLikeCount
      controller.hasCheckedInteraction.value = false;
      expect(controller.displayLikeCount, equals(10));

      // Checked interaction, user liked locally (not yet synced to db)
      controller.hasCheckedInteraction.value = true;
      controller.dbIsLiked.value = false;
      controller.isLiked.value = true;
      expect(controller.displayLikeCount, equals(11));

      // User unliked locally (was liked in db)
      controller.dbIsLiked.value = true;
      controller.isLiked.value = false;
      expect(controller.displayLikeCount, equals(9));

      // Both synced
      controller.dbIsLiked.value = true;
      controller.isLiked.value = true;
      expect(controller.displayLikeCount, equals(10));
    });

    test('3. updateInitialLikeCount updates like count when changed', () {
      controller.hasCheckedInteraction.value = true;
      controller.dbIsLiked.value = false;
      controller.isLiked.value = false;

      controller.updateInitialLikeCount(25);
      expect(controller.initialDbLikeCount.value, equals(25));
      expect(controller.likeCount.value, equals(25));

      // Optimistically liked
      controller.isLiked.value = true;
      controller.updateLikeCount();
      expect(controller.likeCount.value, equals(26));
    });

    testWidgets('4. initializeTopic configures topic metadata correctly', (tester) async {
      final topic = Topic(
        id: 'topic_abc',
        title: 'Quantum Computing Breakthroughs',
        slug: 'quantum-breakthroughs',
        handle: 'quantum_breakthroughs',
        handleLowercase: 'quantum_breakthroughs',
        description: 'Latest research in quantum supremacy',
        category: 'Science',
        channelId: 'ch_tech',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likeCount: 42,
        commentCount: 7,
      );

      controller.initializeTopic(topic);
      await tester.pump();

      expect(controller.topic?.id, equals('topic_abc'));
      expect(controller.initialDbLikeCount.value, equals(42));
      expect(controller.commentCount.value, equals(7));
      expect(controller.dbIsLiked.value, isFalse);
      expect(controller.isLiked.value, isFalse);
    });

    test('5. addComment ignores empty text without throwing', () async {
      await controller.addComment('topic_abc', '    ');
      expect(controller.comments, isEmpty);
      expect(controller.commentCount.value, equals(0));
    });

    test('6. addReply ignores empty text without throwing', () async {
      await controller.addReply('topic_abc', 'comment_123', '   ');
      expect(controller.repliesMap, isEmpty);
      expect(controller.commentCount.value, equals(0));
    });

    test('7. Controller closes and disposes subscription cleanly', () {
      expect(controller.isClosed, isFalse);
      controller.onClose();
      expect(controller.commentsSubscription, isNull);
    });
  });
}
