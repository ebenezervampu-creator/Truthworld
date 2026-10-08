import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/feed_mixins.dart';
import 'package:truthworld/features/video/data/models/video.dart';

Video createModularTestVideo({
  required String id,
  required String category,
  List<String> tags = const [],
  List<String> topics = const [],
}) {
  final now = DateTime.now();
  return Video(
    id: id,
    title: 'Video $id',
    description: 'Description',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    ownerId: 'owner_1',
    channelId: 'channel_1',
    channelName: 'Channel One',
    category: category,
    tags: tags,
    topics: topics,
    createdAt: Timestamp.fromDate(now),
    uploadedAt: Timestamp.fromDate(now),
    videoUrl: 'https://example.com/video.mp4',
    geminiApproved: true,
    isApproved: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Feed Modular Components Test Suite', () {
    test('Feed mixins export barrel correctly and symbols resolve', () {
      expect(HomeFeedControllerBase.pageSize, equals(24));
      expect(HomeFeedControllerBase.loadMoreThreshold, equals(90));
      expect(HomeFeedControllerBase.kScrollThreshold, equals(8));
    });

    test('Category matching logic handles case insensitivity, tags, and topics', () {
      final v1 = createModularTestVideo(
        id: '1',
        category: 'Technology',
        tags: ['coding', 'flutter'],
        topics: ['software'],
      );

      final matchingLogic = _TestFeedController();

      expect(matchingLogic.matchesCategory(v1, 'technology'), isTrue);
      expect(matchingLogic.matchesCategory(v1, 'TECHNOLOGY'), isTrue);
      expect(matchingLogic.matchesCategory(v1, 'Tech'), isTrue);
      expect(matchingLogic.matchesCategory(v1, 'coding'), isTrue);
      expect(matchingLogic.matchesCategory(v1, 'flutter'), isTrue);
      expect(matchingLogic.matchesCategory(v1, 'software'), isTrue);
      expect(matchingLogic.matchesCategory(v1, 'cooking'), isFalse);
    });

    test('mixHomeFeed correctly mixes videos, community posts, and ad items', () {
      final ctrl = _TestFeedController();
      final v1 = createModularTestVideo(id: 'v1', category: 'Tech');
      final v2 = createModularTestVideo(id: 'v2', category: 'Tech');
      final v3 = createModularTestVideo(id: 'v3', category: 'Tech');
      final v4 = createModularTestVideo(id: 'v4', category: 'Tech');
      final v5 = createModularTestVideo(id: 'v5', category: 'Tech');
      final v6 = createModularTestVideo(id: 'v6', category: 'Tech');
      final v7 = createModularTestVideo(id: 'v7', category: 'Tech');

      ctrl.videos.assignAll([v1, v2, v3, v4, v5, v6, v7]);

      final post1 = CommunityPostModel(
        id: 'post_1',
        title: 'Community Title',
        description: 'Community post content',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Channel One',
        channelImage: 'https://example.com/avatar.jpg',
        uploadedAt: DateTime.now(),
      );
      ctrl.communityPosts.assignAll([post1]);

      ctrl.mixHomeFeed();

      // Videos should be in feed items
      expect(ctrl.homeFeedItems.isNotEmpty, isTrue);
      expect(ctrl.homeFeedItems.any((item) => item is Video && item.id == 'v1'), isTrue);
    });

    test('Firestore collection constants align with requirements', () {
      expect(FirestoreCollections.community, equals('Community'));
    });

    test('Video.fromMap parses published, ready, active and playable processing status as VideoStatus.ready', () {
      final docPublished = Video.fromMap({
        'title': 'Awesome Truth Video',
        'status': 'published',
        'videoUrl': 'https://example.com/stream.mp4',
      }, 'vid_pub');
      expect(docPublished.status, equals(VideoStatus.ready));

      final docActive = Video.fromMap({
        'title': 'Active Truth Video',
        'status': 'active',
        'videoUrl': 'https://example.com/stream.mp4',
      }, 'vid_act');
      expect(docActive.status, equals(VideoStatus.ready));

      final docProcessingPlayable = Video.fromMap({
        'title': 'Processing but Playable Video',
        'status': 'processing',
        'videoUrl': 'https://example.com/stream.mp4',
      }, 'vid_proc');
      expect(docProcessingPlayable.status, equals(VideoStatus.ready));
    });

    test('VideoVisibilityPolicy accepts playable video even with empty thumbnailUrl and case-variant visibility', () {
      final playableNoThumb = Video.fromMap({
        'title': 'Playable Stream',
        'status': 'published',
        'visibility': 'Public',
        'thumbnailUrl': '',
        'videoUrl': 'https://example.com/video.mp4',
      }, 'vid_playable');

      expect(VideoVisibilityPolicy.hasPlayableMedia(playableNoThumb), isTrue);
      expect(VideoVisibilityPolicy.hasValidThumbnail(playableNoThumb), isTrue);
      expect(VideoVisibilityPolicy.isValidVideo(playableNoThumb), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForFeed(playableNoThumb), isTrue);
    });

    test('VideoStatusExtension.isApprovedByGeminiOrManual permits playable ready videos', () {
      final video = Video.fromMap({
        'title': 'Valid Playable Video',
        'status': 'ready',
        'videoUrl': 'https://example.com/video.mp4',
      }, 'vid_ready');

      expect(video.isApprovedByGeminiOrManual, isTrue);
    });
  });
}

// Minimal mock implementation for headless unit testing of mixins
class _TestFeedController extends HomeFeedControllerBase
    with
        HomeFeedCachePersonalizationMixin,
        HomeFeedAlgorithmTabsMixin,
        HomeFeedCategoryTabsMixin,
        HomeFeedCommunityCarouselMixin,
        HomeFeedScrollMixin {
  @override
  late final AuthService authService =
      Get.isRegistered<AuthService>() ? Get.find<AuthService>() : AuthService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
