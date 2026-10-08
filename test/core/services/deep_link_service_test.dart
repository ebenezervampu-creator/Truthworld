import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = DeepLinkService.instance;

  group('DeepLinkService URL Parsing Tests', () {
    test('Parses standard /watch?v=videoId with timestamp', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/watch?v=v12345&t=1m30s');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('v12345'));
      expect(parsed.timestamp, equals(const Duration(minutes: 1, seconds: 30)));
    });

    test('Parses /watch/videoId path-based URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/watch/v99999');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('v99999'));
    });

    test('Parses /v/videoId short URL', () {
      final parsed = DeepLinkService.parseUrl('https://truthworld.in/v/vShort1');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('vShort1'));
    });

    test('Parses /shorts/videoId URL', () {
      final parsed = DeepLinkService.parseUrl('https://truthworld.in/shorts/vShorts2');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('vShorts2'));
    });

    test('Parses custom scheme truthworld://watch?v=videoId', () {
      final parsed = DeepLinkService.parseUrl('truthworld://watch?v=vScheme');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('vScheme'));
    });

    test('Parses custom scheme truthworld:/watch?v=videoId (single slash)', () {
      final parsed = DeepLinkService.parseUrl('truthworld:/watch?v=vSchemeSingle');
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('vSchemeSingle'));
    });

    test('Parses Android intent:// URL correctly', () {
      final parsed = DeepLinkService.parseUrl(
        'intent://www.truthworld.in/watch?v=vIntent#Intent;scheme=https;package=com.truthworld.app;end',
      );
      expect(parsed.type, equals(TruthworldUrlType.video));
      expect(parsed.id, equals('vIntent'));
    });

    test('Parses /channel/channelId URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/channel/chan_abc123');
      expect(parsed.type, equals(TruthworldUrlType.channel));
      expect(parsed.id, equals('chan_abc123'));
    });

    test('Parses /@handle channel URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/@tech_creator');
      expect(parsed.type, equals(TruthworldUrlType.channel));
      expect(parsed.handle, equals('tech_creator'));
    });

    test('Parses /playlist/playlistId URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/playlist/pl_learn_dart');
      expect(parsed.type, equals(TruthworldUrlType.playlist));
      expect(parsed.id, equals('pl_learn_dart'));
    });

    test('Parses /playlist?list=playlistId query parameter', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/playlist?list=pl_learn_flutter');
      expect(parsed.type, equals(TruthworldUrlType.playlist));
      expect(parsed.playlistId, equals('pl_learn_flutter'));
    });

    test('Parses /topic/slug URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/topic/artificial-intelligence');
      expect(parsed.type, equals(TruthworldUrlType.topic));
      expect(parsed.id, equals('artificial-intelligence'));
    });

    test('Parses /T/slug URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/T/machine-learning');
      expect(parsed.type, equals(TruthworldUrlType.topic));
      expect(parsed.id, equals('machine-learning'));
    });

    test('Parses /community/postId URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/community/post_999');
      expect(parsed.type, equals(TruthworldUrlType.post));
      expect(parsed.id, equals('post_999'));
    });

    test('Parses /post/postId URL', () {
      final parsed = DeepLinkService.parseUrl('https://www.truthworld.in/post/post_888');
      expect(parsed.type, equals(TruthworldUrlType.post));
      expect(parsed.id, equals('post_888'));
    });

    test('Parses /upload and /upload/video routes', () {
      final upload1 = DeepLinkService.parseUrl('https://www.truthworld.in/upload');
      expect(upload1.type, equals(TruthworldUrlType.upload));

      final upload2 = DeepLinkService.parseUrl('https://www.truthworld.in/upload/video');
      expect(upload2.type, equals(TruthworldUrlType.upload));
    });

    test('Parses /studio route', () {
      final studio = DeepLinkService.parseUrl('https://studio.truthworld.in');
      expect(studio.type, equals(TruthworldUrlType.studio));
    });

    test('Parses /admin route', () {
      final admin = DeepLinkService.parseUrl('https://admin.truthworld.in');
      expect(admin.type, equals(TruthworldUrlType.admin));
    });

    test('Parses /settings route', () {
      final settings = DeepLinkService.parseUrl('https://www.truthworld.in/settings');
      expect(settings.type, equals(TruthworldUrlType.settings));
    });

    test('Parses /community-guidelines and other policy routes as policy type', () {
      final guidelines = DeepLinkService.parseUrl('https://www.truthworld.in/community-guidelines');
      expect(guidelines.type, equals(TruthworldUrlType.policy));
      expect(guidelines.id, equals('community-guidelines'));

      final terms = DeepLinkService.parseUrl('/terms');
      expect(terms.type, equals(TruthworldUrlType.policy));
      expect(terms.id, equals('terms'));

      final privacy = DeepLinkService.parseUrl('/privacy');
      expect(privacy.type, equals(TruthworldUrlType.policy));
      expect(privacy.id, equals('privacy'));

      final about = DeepLinkService.parseUrl('/about');
      expect(about.type, equals(TruthworldUrlType.policy));
      expect(about.id, equals('about'));

      final feedback = DeepLinkService.parseUrl('/feedback');
      expect(feedback.type, equals(TruthworldUrlType.policy));
      expect(feedback.id, equals('feedback'));
    });

    test('Defensively rejects spoofed domains containing truthworld.in substring', () {
      final spoof1 = DeepLinkService.parseUrl('https://truthworld.in.attacker.com/watch?v=123');
      expect(spoof1.type, equals(TruthworldUrlType.external));

      final spoof2 = DeepLinkService.parseUrl('https://evil-truthworld.in/watch?v=123');
      expect(spoof2.type, equals(TruthworldUrlType.external));

      final spoof3 = DeepLinkService.parseUrl('https://attacker.org/?redirect=truthworld.in');
      expect(spoof3.type, equals(TruthworldUrlType.external));
    });
  });

  group('DeepLinkService Timestamp Parsing Tests', () {
    test('Parses pure seconds string: "120"', () {
      expect(DeepLinkService.parseTimestamp('120'), equals(const Duration(seconds: 120)));
    });

    test('Parses seconds with suffix: "90s"', () {
      expect(DeepLinkService.parseTimestamp('90s'), equals(const Duration(seconds: 90)));
    });

    test('Parses minutes and seconds: "1m30s"', () {
      expect(DeepLinkService.parseTimestamp('1m30s'), equals(const Duration(minutes: 1, seconds: 30)));
    });

    test('Parses hours, minutes, and seconds: "1h2m3s"', () {
      expect(
        DeepLinkService.parseTimestamp('1h2m3s'),
        equals(const Duration(hours: 1, minutes: 2, seconds: 3)),
      );
    });

    test('Parses hours and minutes: "2h15m"', () {
      expect(
        DeepLinkService.parseTimestamp('2h15m'),
        equals(const Duration(hours: 2, minutes: 15)),
      );
    });

    test('Handles invalid or null timestamps gracefully', () {
      expect(DeepLinkService.parseTimestamp(null), isNull);
      expect(DeepLinkService.parseTimestamp(''), isNull);
      expect(DeepLinkService.parseTimestamp('abc'), isNull);
    });
  });

  group('DeepLinkService LRU Cache Tests', () {
    test('Caches and retrieves video correctly', () {
      final testVideo = Video(
        id: 'vid_cache_1',
        title: 'Cache Test Video',
        description: 'Test Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/video.mp4',
        ownerId: 'owner1',
        channelId: 'chan1',
        channelName: 'Test Channel',
        category: 'Tech',
        tags: const ['test'],
        createdAt: Timestamp.now(),
      );

      service.cacheVideo(testVideo);

      final retrieved = service.getVideoFromCache('vid_cache_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('vid_cache_1'));
      expect(retrieved.title, equals('Cache Test Video'));
    });

    test('Caches and retrieves channel correctly by ID and handle', () {
      final testChannel = Channel(
        id: 'chan_cache_1',
        name: 'Channel Cache Test',
        nameLowercase: 'channel cache test',
        handle: 'cachechannel',
        handleLowercase: 'cachechannel',
        description: 'Test Channel Description',
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        ownerId: 'owner2',
        subscriberCount: 100,
        videoCount: 10,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      service.cacheChannel(testChannel);

      final byId = service.getChannelFromCache('chan_cache_1');
      expect(byId, isNotNull);
      expect(byId!.channelName, equals('Channel Cache Test'));

      final byHandle = service.getChannelFromCache('@cachechannel');
      expect(byHandle, isNotNull);
      expect(byHandle!.channelId, equals('chan_cache_1'));
    });

    test('Caches and retrieves playlist correctly', () {
      final testPlaylist = PlaylistModel(
        id: 'pl_cache_1',
        ownerId: 'user1',
        channelId: 'chan1',
        playlistName: 'Playlist Cache Test',
        description: 'Test Playlist',
        videoIds: const ['v1', 'v2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.cachePlaylist(testPlaylist);

      final retrieved = service.getPlaylistFromCache('pl_cache_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.playlistName, equals('Playlist Cache Test'));
    });

    test('Caches and retrieves topic correctly by ID and slug', () {
      final testTopic = Topic(
        id: 'topic_cache_1',
        title: 'AI Trends',
        slug: 'ai-trends',
        handle: 'aitrends',
        handleLowercase: 'aitrends',
        category: 'Tech',
        description: 'Trending AI topic',
        videoCount: 5,
        followerCount: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      service.cacheTopic(testTopic);

      final byId = service.getTopicFromCache('topic_cache_1');
      expect(byId, isNotNull);
      expect(byId!.title, equals('AI Trends'));

      final bySlug = service.getTopicFromCache('ai-trends');
      expect(bySlug, isNotNull);
      expect(bySlug!.id, equals('topic_cache_1'));
    });
  });
}
