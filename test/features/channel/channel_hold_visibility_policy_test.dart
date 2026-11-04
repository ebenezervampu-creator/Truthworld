import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ChannelMemoryCache.clear);

  tearDown(ChannelMemoryCache.clear);

  group('Channel Model On-Hold Tests', () {
    test('Channel.fromMap correctly parses onHold and hold status', () {
      final mapOnHold = {
        'id': 'ch_1',
        'channelName': 'Held Channel',
        'handle': 'held1',
        'status': 'onHold',
        'geminiApproved': true, // should not overwrite onHold
      };

      final ch1 = Channel.fromMap(mapOnHold, 'ch_1');
      expect(ch1.status, equals(ChannelStatus.onHold));
      expect(ch1.isOnHold, isTrue);

      final mapHold = {
        'id': 'ch_2',
        'channelName': 'Held Channel 2',
        'handle': 'held2',
        'status': 'hold',
      };

      final ch2 = Channel.fromMap(mapHold, 'ch_2');
      expect(ch2.status, equals(ChannelStatus.onHold));
      expect(ch2.isOnHold, isTrue);

      final mapActive = {
        'id': 'ch_3',
        'channelName': 'Active Channel',
        'handle': 'active3',
        'status': 'active',
        'geminiApproved': true,
      };

      final ch3 = Channel.fromMap(mapActive, 'ch_3');
      expect(ch3.status, equals(ChannelStatus.active));
      expect(ch3.isOnHold, isFalse);
    });
  });

  group('VideoVisibilityPolicy Channel On-Hold Tests', () {
    test('Videos from on-hold channels are invalid and hidden everywhere', () {
      final heldVideo = Video(
        id: 'v_held_1',
        channelId: 'ch_held_1',
        channelName: 'Held Channel',
        title: 'Video from Held Channel',
        description: 'Test Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/video.mp4',
        ownerId: 'owner_1',
        category: 'Technology',
        tags: const ['test'],
        channelStatus: 'onHold',
        status: VideoStatus.ready,
        visibility: 'public',
        isApproved: true,
        geminiApproved: true,
      );

      expect(VideoVisibilityPolicy.isValidVideo(heldVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForFeed(heldVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForSearch(heldVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForChannel(heldVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForRecommendation(heldVideo), isFalse);

      final activeVideo = Video(
        id: 'v_act_1',
        channelId: 'ch_act_1',
        channelName: 'Active Channel',
        title: 'Video from Active Channel',
        description: 'Test Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/video.mp4',
        ownerId: 'owner_2',
        category: 'Technology',
        tags: const ['test'],
        channelStatus: 'active',
        status: VideoStatus.ready,
        visibility: 'public',
        isApproved: true,
        geminiApproved: true,
      );

      expect(VideoVisibilityPolicy.isValidVideo(activeVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForFeed(activeVideo), isTrue);
    });

    test('isMapValid rejects raw maps with onHold channelStatus', () {
      final heldMap = {
        'id': 'v_map_1',
        'title': 'Test Held Video',
        'videoUrl': 'https://example.com/video.mp4',
        'channelStatus': 'onHold',
        'status': 'published',
        'visibility': 'public',
        'isApproved': true,
        'geminiApproved': true,
      };

      expect(VideoVisibilityPolicy.isMapValid(heldMap), isFalse);

      final activeMap = {
        'id': 'v_map_2',
        'title': 'Test Active Video',
        'videoUrl': 'https://example.com/video.mp4',
        'channelStatus': 'active',
        'status': 'published',
        'visibility': 'public',
        'isApproved': true,
        'geminiApproved': true,
      };

      expect(VideoVisibilityPolicy.isMapValid(activeMap), isTrue);
    });

    test('ChannelMemoryCache propagates onHold status to videos without explicit channelStatus field', () {
      ChannelMemoryCache.set(
        'ch_cached_1',
        Channel(
          id: 'ch_cached_1',
          name: 'Cached Held Channel',
          nameLowercase: 'cached held channel',
          handle: '@cached_held',
          handleLowercase: '@cached_held',
          description: 'A channel on hold in cache',
          avatarUrl: '',
          bannerUrl: '',
          ownerId: 'owner_3',
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          status: ChannelStatus.onHold,
        ),
      );

      final videoFromCachedChannel = Video(
        id: 'v_cached_1',
        channelId: 'ch_cached_1',
        channelName: 'Cached Held Channel',
        title: 'Video from Cached Channel',
        description: 'Test Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/video.mp4',
        ownerId: 'owner_3',
        category: 'Technology',
        tags: const ['test'],
        status: VideoStatus.ready,
        visibility: 'public',
        isApproved: true,
        geminiApproved: true,
      );

      expect(VideoVisibilityPolicy.isValidVideo(videoFromCachedChannel), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForFeed(videoFromCachedChannel), isFalse);
    });
  });

  group('SearchResult & Channel Status On-Hold Tests', () {
    test('SearchResult.isValid rejects held channels and videos', () {
      final heldChannelResult = SearchResult(
        id: 'sr_ch_1',
        title: 'Held Channel',
        thumbnail: '',
        views: 0,
        channelName: 'Held Channel',
        channelImage: '',
        createdAt: Timestamp.now(),
        type: ResultType.channel,
        visibility: 'onHold',
      );
      expect(heldChannelResult.isValid, isFalse);

      final activeChannelResult = SearchResult(
        id: 'sr_ch_2',
        title: 'Active Channel',
        thumbnail: '',
        views: 0,
        channelName: 'Active Channel',
        channelImage: '',
        createdAt: Timestamp.now(),
        type: ResultType.channel,
        visibility: 'active',
      );
      expect(activeChannelResult.isValid, isTrue);
    });

    test('Channel status onHold is correctly verified', () {
      final channel = Channel(
        id: 'c_test_1',
        name: 'Test Channel',
        nameLowercase: 'test channel',
        handle: '@testch',
        handleLowercase: '@testch',
        description: 'Description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_x',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        status: ChannelStatus.onHold,
      );

      expect(channel.isOnHold, isTrue);
      expect(channel.status, equals(ChannelStatus.onHold));
    });
  });
}
