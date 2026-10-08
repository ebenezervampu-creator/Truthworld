import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';

class TestDownloadsController extends DownloadsController {
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineVideo Model Audio-Only Tests', () {
    test('OfflineVideo defaults isAudioOnly to false', () {
      final item = OfflineVideo(
        id: 'vid1',
        title: 'Video Title',
        channelName: 'Truth Channel',
        channelImage: '',
        views: '100',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        downloadedAt: DateTime(2026),
      );

      expect(item.isAudioOnly, isFalse);
      expect(item.quality, isNull);

      final json = item.toJson();
      expect(json['isAudioOnly'], isFalse);
      expect(json.containsKey('quality'), isFalse);
    });

    test('OfflineVideo correctly serializes and deserializes audio-only metadata', () {
      final item = OfflineVideo(
        id: 'audio1',
        title: 'Audio Podcast (Audio)',
        channelName: 'Audio Channel',
        channelImage: 'https://example.com/avatar.jpg',
        views: '1500',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        downloadedAt: DateTime(2026, 2),
        isAudioOnly: true,
        quality: 'Audio only',
      );

      expect(item.isAudioOnly, isTrue);
      expect(item.quality, equals('Audio only'));

      final json = item.toJson();
      expect(json['isAudioOnly'], isTrue);
      expect(json['quality'], equals('Audio only'));

      final restored = OfflineVideo.fromJson(json);
      expect(restored.id, equals('audio1'));
      expect(restored.title, equals('Audio Podcast (Audio)'));
      expect(restored.isAudioOnly, isTrue);
      expect(restored.quality, equals('Audio only'));
    });

    test('OfflineVideo copyWith works properly', () {
      final item = OfflineVideo(
        id: 'item1',
        title: 'Original Title',
        channelName: 'Channel',
        channelImage: '',
        views: '10',
        thumbnailUrl: '',
        downloadedAt: DateTime(2026),
      );

      final updated = item.copyWith(
        isAudioOnly: true,
        quality: 'Audio only',
        title: 'Original Title (Audio)',
      );

      expect(updated.id, equals('item1'));
      expect(updated.title, equals('Original Title (Audio)'));
      expect(updated.isAudioOnly, isTrue);
      expect(updated.quality, equals('Audio only'));
    });
  });

  group('DownloadsController Category Filtering Tests', () {
    late TestDownloadsController controller;

    setUp(() {
      controller = TestDownloadsController();
      controller.videos.value = [
        OfflineVideo(
          id: 'v1',
          title: 'Full Video Lecture',
          channelName: 'Edu Channel',
          channelImage: '',
          views: '500',
          thumbnailUrl: '',
          downloadedAt: DateTime(2026),
          quality: '1080p',
        ),
        OfflineVideo(
          id: 'a1',
          title: 'Podcast Episode (Audio)',
          channelName: 'Edu Channel',
          channelImage: '',
          views: '300',
          thumbnailUrl: '',
          downloadedAt: DateTime(2026, 1, 2),
          isAudioOnly: true,
          quality: 'Audio only',
        ),
        OfflineVideo(
          id: 'v2',
          title: 'Truth Documentary',
          channelName: 'Truth Docs',
          channelImage: '',
          views: '1200',
          thumbnailUrl: '',
          downloadedAt: DateTime(2026, 1, 3),
          quality: '720p',
        ),
        OfflineVideo(
          id: 'a2',
          title: 'Audio Discourse (Audio)',
          channelName: 'Philosophy Network',
          channelImage: '',
          views: '800',
          thumbnailUrl: '',
          downloadedAt: DateTime(2026, 1, 4),
          isAudioOnly: true,
          quality: 'Audio only',
        ),
      ];
    });

    test('All category returns all items', () {
      controller.setCategory('All');
      expect(controller.filteredVideos.length, equals(4));
    });

    test('Videos category returns only video items', () {
      controller.setCategory('Videos');
      final filtered = controller.filteredVideos;
      expect(filtered.length, equals(2));
      expect(filtered.every((v) => !v.isAudioOnly), isTrue);
      expect(filtered.map((v) => v.id), containsAll(['v1', 'v2']));
    });

    test('Audio category returns only audio items', () {
      controller.setCategory('Audio');
      final filtered = controller.filteredVideos;
      expect(filtered.length, equals(2));
      expect(filtered.every((v) => v.isAudioOnly), isTrue);
      expect(filtered.map((v) => v.id), containsAll(['a1', 'a2']));
    });

    test('Search filter combined with Audio category works correctly', () {
      controller.setCategory('Audio');
      controller.setSearchQuery('Podcast');
      final filtered = controller.filteredVideos;
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('a1'));
    });

    test('getOfflineVideo finds item in downloaded list', () async {
      final item = await controller.getOfflineVideo('a1');
      expect(item, isNotNull);
      expect(item!.isAudioOnly, isTrue);
      expect(item.quality, equals('Audio only'));
    });
  });

  group('Offline Audio & Format Locking Playback Tests', () {
    test('OfflineVideo preserves selected format and audio-only mode', () {
      final audioItem = OfflineVideo(
        id: 'audio_track_1',
        title: 'Interview Track',
        channelName: 'Truth Studio',
        channelImage: '',
        views: '450',
        thumbnailUrl: '',
        downloadedAt: DateTime.now(),
        isAudioOnly: true,
        quality: 'Audio only',
      );

      final video720pItem = OfflineVideo(
        id: 'video_720p_1',
        title: 'Debate in HD',
        channelName: 'Truth Debate',
        channelImage: '',
        views: '12000',
        thumbnailUrl: '',
        downloadedAt: DateTime.now(),
        quality: '720p',
      );

      expect(audioItem.isAudioOnly, isTrue);
      expect(audioItem.quality, equals('Audio only'));

      expect(video720pItem.isAudioOnly, isFalse);
      expect(video720pItem.quality, equals('720p'));
    });
  });
}
