import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    ChannelMemoryCache.clear();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(() {
    ChannelMemoryCache.clear();
    Get.reset();
  });

  Channel createTestChannel({
    required String id,
    String name = 'Test Channel',
    bool showDislikeCount = true,
    bool showLikeCount = true,
    bool showSubscriberCount = true,
    bool allowComments = true,
    List<Map<String, String>> customLinks = const [],
    Map<String, dynamic>? socialLinks,
    int subscriberCount = 1000,
  }) {
    return Channel(
      id: id,
      name: name,
      nameLowercase: name.toLowerCase(),
      handle: id,
      handleLowercase: id.toLowerCase(),
      description: 'Channel description for $name',
      avatarUrl: 'https://example.com/avatar.jpg',
      bannerUrl: 'https://example.com/banner.jpg',
      ownerId: 'owner_$id',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      subscriberCount: subscriberCount,
      videoCount: 10,
      showDislikeCount: showDislikeCount,
      showLikeCount: showLikeCount,
      showSubscriberCount: showSubscriberCount,
      allowComments: allowComments,
      customLinks: customLinks,
      socialLinks: socialLinks,
      metrics: ChannelMetricsV2(totalViews: 5000),
    );
  }

  Video createTestVideo({
    required String id,
    required String channelId,
    bool showDislikeCount = true,
    bool showLikeCount = true,
    int dislikeCount = 0,
    int likeCount = 0,
  }) {
    return Video.empty().copyWith(
      id: id,
      title: 'Test Video $id',
      description: 'Test description for $id',
      channelId: channelId,
      showDislikeCount: showDislikeCount,
      showLikeCount: showLikeCount,
      dislikeCount: dislikeCount,
      likeCount: likeCount,
    );
  }

  group('Studio to VideoScreen Synchronization Tests', () {
    test('1. Channel model parses showSubscriberCount and allowComments from Studio Firestore data', () {
      final channelData = <String, dynamic>{
        'name': 'Truth Studio Channel',
        'channelName': 'Truth Studio Channel',
        'handle': '@truthstudio',
        'ownerId': 'owner_123',
        'showSubscriberCount': false,
        'allowComments': false,
        'showLikeCount': false,
        'showDislikeCount': false,
        'socialLinks': {
          'website': 'https://truthworld.com',
          'twitter': 'https://x.com/truthworld',
          'discord': 'https://discord.gg/truthworld',
        },
        'customLinks': [
          {'title': 'Merch Store', 'url': 'https://shop.truthworld.com'},
          {'title': 'Portfolio', 'url': 'https://portfolio.truthworld.com'},
        ],
      };

      final channel = Channel.fromMap(channelData, 'chan_test_01');

      expect(channel.showSubscriberCount, isFalse);
      expect(channel.allowComments, isFalse);
      expect(channel.showLikeCount, isFalse);
      expect(channel.showDislikeCount, isFalse);
      expect(channel.websiteUrl, equals('https://truthworld.com'));
      expect(channel.customLinks.length, equals(2));
      expect(channel.customLinks[0]['title'], equals('Merch Store'));
      expect(channel.customLinks[0]['url'], equals('https://shop.truthworld.com'));

      final entity = channel.toEntity();
      expect(entity.showSubscriberCount, isFalse);
      expect(entity.allowComments, isFalse);
      expect(entity.showLikeCount, isFalse);
      expect(entity.showDislikeCount, isFalse);

      final rehydrated = Channel.fromEntity(entity);
      expect(rehydrated.showSubscriberCount, isFalse);
      expect(rehydrated.allowComments, isFalse);
    });

    test('2. Dislike count is hidden when video has showDislikeCount = false', () {
      final video = createTestVideo(
        id: 'vid_01',
        channelId: 'chan_01',
        showDislikeCount: false,
        dislikeCount: 42,
      );

      final channel = createTestChannel(
        id: 'chan_01',
        showDislikeCount: true,
      );
      ChannelMemoryCache.set('chan_01', channel);

      final effectiveShowDislike = video.showDislikeCount &&
          (ChannelMemoryCache.getReactive('chan_01')?.showDislikeCount ?? true);

      expect(effectiveShowDislike, isFalse);
    });

    test('3. Dislike count is hidden when channel has showDislikeCount = false even if video default is true', () {
      final video = createTestVideo(
        id: 'vid_02',
        channelId: 'chan_02',
        showDislikeCount: true,
        dislikeCount: 99,
      );

      final channel = createTestChannel(
        id: 'chan_02',
        showDislikeCount: false, // Turned off in Studio Customization
      );
      ChannelMemoryCache.set('chan_02', channel);

      final effectiveShowDislike = video.showDislikeCount &&
          (ChannelMemoryCache.getReactive('chan_02')?.showDislikeCount ?? true);

      expect(effectiveShowDislike, isFalse);
    });

    test('4. Like count is hidden when video has showLikeCount = false or channel has showLikeCount = false', () {
      final video = createTestVideo(
        id: 'vid_03',
        channelId: 'chan_03',
        showLikeCount: true,
        likeCount: 500,
      );

      final channel = createTestChannel(
        id: 'chan_03',
        showLikeCount: false, // Studio turned off like count
      );
      ChannelMemoryCache.set('chan_03', channel);

      final effectiveShowLike = video.showLikeCount &&
          (ChannelMemoryCache.getReactive('chan_03')?.showLikeCount ?? true);

      expect(effectiveShowLike, isFalse);
    });

    test('5. Subscriber count is hidden when channel has showSubscriberCount = false', () {
      final channel = createTestChannel(
        id: 'chan_04',
        subscriberCount: 15000,
        showSubscriberCount: false, // Studio turned off subscriber count
      );

      expect(channel.showSubscriberCount, isFalse);
    });

    test('6. Channel custom links and social links are reactive via ChannelMemoryCache', () {
      final channel = createTestChannel(
        id: 'chan_05',
        socialLinks: {'website': 'https://mysite.com'},
        customLinks: [
          {'title': 'Discord Server', 'url': 'https://discord.gg/test'},
        ],
      );

      ChannelMemoryCache.set('chan_05', channel);

      final cached = ChannelMemoryCache.getReactive('chan_05');
      expect(cached, isNotNull);
      expect(cached!.customLinks.length, equals(1));
      expect(cached.customLinks.first['title'], equals('Discord Server'));
      expect(cached.websiteUrl, equals('https://mysite.com'));

      // Studio updates custom links
      final updatedChannel = channel.copyWith(
        customLinks: [
          {'title': 'Discord Server', 'url': 'https://discord.gg/test'},
          {'title': 'Official Store', 'url': 'https://store.mysite.com'},
        ],
      );
      ChannelMemoryCache.set('chan_05', updatedChannel);

      final reCached = ChannelMemoryCache.getReactive('chan_05');
      expect(reCached!.customLinks.length, equals(2));
      expect(reCached.customLinks[1]['title'], equals('Official Store'));
    });

    test('7. Comments are disabled when channel has allowComments = false', () {
      final channel = createTestChannel(
        id: 'chan_06',
        allowComments: false, // Studio turned off comments
      );

      ChannelMemoryCache.set('chan_06', channel);

      final allowComments = ChannelMemoryCache.getReactive('chan_06')?.allowComments ?? true;
      expect(allowComments, isFalse);
    });
  });
}
