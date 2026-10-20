import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_trust_score.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('Channel.fromVideo Optimistic Hydration Tests', () {
    test('Constructs Channel accurately from Video entity', () {
      final video = Video(
        id: 'vid_123',
        title: 'Science and Truth',
        description: 'Testing video description',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
        ownerId: 'owner_abc',
        channelId: 'channel_xyz',
        channelName: 'Ebenezer Vampu',
        channelAvatarUrl: 'https://cdn.example.com/avatar.jpg',
        category: 'Education',
        tags: const ['science'],
        isVerified: true,
      );

      final channel = Channel.fromVideo(video);

      expect(channel.id, equals('channel_xyz'));
      expect(channel.channelId, equals('channel_xyz'));
      expect(channel.name, equals('Ebenezer Vampu'));
      expect(channel.channelName, equals('Ebenezer Vampu'));
      expect(channel.avatarUrl, equals('https://cdn.example.com/avatar.jpg'));
      expect(channel.isVerified, isTrue);
      expect(channel.ownerId, equals('owner_abc'));
      expect(channel.handle, equals('@ebenezervampu'));
    });

    test('Falls back to ownerId if channelId is empty', () {
      final video = Video(
        id: 'vid_456',
        title: 'Fallback Test',
        description: '',
        thumbnailUrl: '',
        ownerId: 'owner_user_789',
        channelId: '',
        channelName: 'Creator Studio',
        category: 'General',
        tags: const [],
      );

      final channel = Channel.fromVideo(video);

      expect(channel.id, equals('owner_user_789'));
      expect(channel.name, equals('Creator Studio'));
    });
  });

  group('ChannelMemoryCache Reactive Tests', () {
    setUp(ChannelMemoryCache.clear);

    test('Stores and retrieves channel by id, ownerId, and handle', () {
      final channel = Channel(
        id: 'ch_main_1',
        name: 'Tech Channel',
        nameLowercase: 'tech channel',
        handle: '@techchannel',
        handleLowercase: '@techchannel',
        description: 'Tech news',
        avatarUrl: 'https://cdn.example.com/tech.jpg',
        bannerUrl: '',
        ownerId: 'owner_tech_99',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        isVerified: true,
      );

      ChannelMemoryCache.set('ch_main_1', channel);

      // Verify retrieval by direct doc ID
      expect(ChannelMemoryCache.get('ch_main_1'), isNotNull);
      expect(ChannelMemoryCache.get('ch_main_1')?.name, equals('Tech Channel'));

      // Verify multi-index lookup by ownerId
      expect(ChannelMemoryCache.get('owner_tech_99'), isNotNull);
      expect(ChannelMemoryCache.get('owner_tech_99')?.id, equals('ch_main_1'));

      // Verify multi-index lookup by handle
      expect(ChannelMemoryCache.get('@techchannel'), isNotNull);
      expect(ChannelMemoryCache.get('techchannel'), isNotNull);
    });

    test('Stores and retrieves ChannelTrustScore', () {
      final trust = ChannelTrustScore(
        averageTrustScore: 95.0,
        totalVideosAnalyzed: 10,
        totalClaimsVerified: 9,
        totalClaimsFalse: 1,
        totalClaimsUnconfirmed: 0,
        verificationRate: 0.9,
        lastUpdated: DateTime.now(),
      );

      ChannelMemoryCache.setTrustScore('ch_main_1', trust);

      final retrieved = ChannelMemoryCache.getTrustScore('ch_main_1');
      expect(retrieved, isNotNull);
      expect(retrieved?.averageTrustScore, equals(95.0));
      expect(retrieved?.trackRecordLabel, equals('Highly Reliable'));
    });

    test('Clears all cached channels on clear()', () {
      final channel = Channel(
        id: 'ch_temp',
        name: 'Temp',
        nameLowercase: 'temp',
        handle: '@temp',
        handleLowercase: '@temp',
        description: '',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'user_temp',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      ChannelMemoryCache.set('ch_temp', channel);
      expect(ChannelMemoryCache.has('ch_temp'), isTrue);

      ChannelMemoryCache.clear();
      expect(ChannelMemoryCache.has('ch_temp'), isFalse);
      expect(ChannelMemoryCache.get('ch_temp'), isNull);
    });

    testWidgets('ChannelMemoryCache.get inside Obx does not bind Obx to cache mutations', (tester) async {
      var buildCount = 0;
      final dummyChannel = Channel(
        id: 'ch_isolated',
        name: 'Isolated',
        nameLowercase: 'isolated',
        handle: '@isolated',
        handleLowercase: '@isolated',
        description: '',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_iso',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      final rxTrigger = 0.obs;
      await tester.pumpWidget(
        MaterialApp(
          home: Obx(() {
            buildCount++;
            final _ = rxTrigger.value;
            final cached = ChannelMemoryCache.get('ch_isolated');
            return Text(cached?.name ?? 'No Channel');
          }),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('No Channel'), findsOneWidget);

      // Mutating cache should NOT trigger a rebuild of the Obx widget
      // because get() reads from internal map without registering RxInterface.proxy.
      ChannelMemoryCache.set('ch_isolated', dummyChannel);
      await tester.pump();

      expect(buildCount, equals(1));
      expect(ChannelMemoryCache.get('ch_isolated')?.name, equals('Isolated'));
    });

    testWidgets('StreamBuilder inside Obx with cached channel builds safely without throwing', (tester) async {
      final channel = Channel(
        id: 'ch_stream_test',
        name: 'Stream Channel',
        nameLowercase: 'stream channel',
        handle: '@streamchannel',
        handleLowercase: '@streamchannel',
        description: '',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_stream',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      ChannelMemoryCache.set('ch_stream_test', channel);

      final rxVideoId = 'vid_123'.obs;
      await tester.pumpWidget(
        MaterialApp(
          home: Obx(() {
            final _ = rxVideoId.value;
            final cached = ChannelMemoryCache.get('ch_stream_test');
            return StreamBuilder<String>(
              stream: Stream.value('snapshot_ready'),
              builder: (context, snapshot) {
                return Text(cached?.name ?? 'Loading');
              },
            );
          }),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Stream Channel'), findsOneWidget);
    });
  });
}
