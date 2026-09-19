import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/comment_report.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('CommentService Modular Architecture Tests', () {
    test('1. CommentService singleton returns identical instance', () {
      final instance1 = CommentService();
      final instance2 = CommentService();

      expect(identical(instance1, instance2), isTrue);
    });

    test('2. CommentServiceBase collection paths and getters match constants', () {
      final service = CommentService();

      expect(CommentServiceBase.videosPath, equals('videos'));
      expect(CommentServiceBase.commentsPath, equals('comments'));
      expect(CommentServiceBase.repliesPath, equals('replies'));
      expect(CommentServiceBase.reportsPath, equals('reports'));

      expect(service.videosCollection, equals('videos'));
      expect(service.commentsCollection, equals('comments'));
      expect(service.repliesCollection, equals('replies'));
      expect(service.reportsCollection, equals('reports'));
    });

    test('3. addComment validates empty comment text', () async {
      final service = CommentService();

      expect(
        () => service.addComment(
          videoId: 'v123',
          userId: 'u123',
          userName: 'Test User',
          userProfilePicUrl: 'https://example.com/pic.jpg',
          channelId: 'ch123',
          text: '   ',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Comment cannot be empty'),
          ),
        ),
      );
    });

    test('4. addComment validates maximum comment length', () async {
      final service = CommentService();
      final longText = 'a' * 5001;

      expect(
        () => service.addComment(
          videoId: 'v123',
          userId: 'u123',
          userName: 'Test User',
          userProfilePicUrl: 'https://example.com/pic.jpg',
          channelId: 'ch123',
          text: longText,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Comment exceeds maximum length of 5000 characters'),
          ),
        ),
      );
    });

    test('5. addComment validates empty userId', () async {
      final service = CommentService();

      expect(
        () => service.addComment(
          videoId: 'v123',
          userId: '   ',
          userName: 'Test User',
          userProfilePicUrl: 'https://example.com/pic.jpg',
          channelId: 'ch123',
          text: 'Valid comment text',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('User ID is required'),
          ),
        ),
      );
    });

    test('6. addComment validates empty videoId', () async {
      final service = CommentService();

      expect(
        () => service.addComment(
          videoId: '   ',
          userId: 'u123',
          userName: 'Test User',
          userProfilePicUrl: 'https://example.com/pic.jpg',
          channelId: 'ch123',
          text: 'Valid comment text',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Video ID is required'),
          ),
        ),
      );
    });

    test('7. Stream methods return valid Stream instances', () {
      final service = CommentService();

      final commentsStream = service.getCommentsStream(videoId: 'v123');
      expect(commentsStream, isA<Stream<List<Comment>>>());

      final repliesStream = service.getRepliesStream(
        videoId: 'v123',
        commentId: 'c123',
      );
      expect(repliesStream, isA<Stream<List<Reply>>>());

      final reportsStream = service.getReportsStream('c123');
      expect(reportsStream, isA<Stream<List<CommentReport>>>());

      final studioCommentsStream = service.getVideoCommentsForStudio('v123');
      expect(studioCommentsStream, isA<Stream<List<Comment>>>());

      final answeredStream = service.getAnsweredComments('v123');
      expect(answeredStream, isA<Stream<List<Comment>>>());

      final unansweredStream = service.getUnansweredComments('v123');
      expect(unansweredStream, isA<Stream<List<Comment>>>());

      final sortedByLikesStream = service.getCommentsSortedByLikes('v123');
      expect(sortedByLikesStream, isA<Stream<List<Comment>>>());
    });

    test('8. Custom constructor allows custom service instance creation', () {
      final customService = CommentService.custom();
      expect(customService, isA<CommentService>());
      expect(customService.videosCollection, equals('videos'));
    });
  });
}
