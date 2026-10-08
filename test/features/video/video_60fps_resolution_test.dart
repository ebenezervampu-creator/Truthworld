import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoResolutionV2 & 60fps Parsing Tests', () {
    test('inferFpsFromLabel correctly extracts frame rates', () {
      expect(VideoResolutionV2.inferFpsFromLabel('1080p60'), 60);
      expect(VideoResolutionV2.inferFpsFromLabel('720p60'), 60);
      expect(VideoResolutionV2.inferFpsFromLabel('2160p60'), 60);
      expect(VideoResolutionV2.inferFpsFromLabel('1440p60'), 60);
      expect(VideoResolutionV2.inferFpsFromLabel('1080p 60fps'), 60);
      expect(VideoResolutionV2.inferFpsFromLabel('1080p'), 30);
      expect(VideoResolutionV2.inferFpsFromLabel('720p'), 30);
      expect(VideoResolutionV2.inferFpsFromLabel('480p'), 30);
    });

    test('VideoResolutionV2.fromMap detects 60fps and maps properties', () {
      final map60 = {
        'label': '1080p60',
        'url': 'https://example.com/1080p60.mp4',
        'width': 1920,
        'height': 1080,
        'bitrate': 7500000,
      };

      final res = VideoResolutionV2.fromMap(map60);
      expect(res.label, '1080p60');
      expect(res.height, 1080);
      expect(res.fps, 60);
      expect(res.is60Fps, isTrue);

      final serialized = res.toMap();
      expect(serialized['fps'], 60);
    });

    test('inferHeightFromLabel accurately parses 60fps and 4K labels', () {
      expect(DownloadResolutionManager.inferHeightFromLabel('1080p60'), 1080);
      expect(DownloadResolutionManager.inferHeightFromLabel('720p60'), 720);
      expect(DownloadResolutionManager.inferHeightFromLabel('2160p60'), 2160);
      expect(DownloadResolutionManager.inferHeightFromLabel('1440p60'), 1440);
      expect(DownloadResolutionManager.inferHeightFromLabel('1080p'), 1080);
      expect(DownloadResolutionManager.inferHeightFromLabel('4K UHD'), 2160);
      expect(DownloadResolutionManager.inferHeightFromLabel('4K 60FPS'), 2160);
    });

    test('getResolutionBadge generates expected 60fps and 30fps badges', () {
      expect(
        DownloadResolutionManager.getResolutionBadge('1080p60', 1080, fps: 60),
        'FHD 60FPS',
      );
      expect(
        DownloadResolutionManager.getResolutionBadge('720p60', 720, fps: 60),
        'HD 60FPS',
      );
      expect(
        DownloadResolutionManager.getResolutionBadge('2160p60', 2160, fps: 60),
        '4K 60FPS',
      );
      expect(
        DownloadResolutionManager.getResolutionBadge('1440p60', 1440, fps: 60),
        '2K 60FPS',
      );
      expect(
        DownloadResolutionManager.getResolutionBadge('1080p', 1080),
        'Full HD',
      );
      expect(
        DownloadResolutionManager.getResolutionBadge('720p', 720),
        'HD',
      );
      expect(
        DownloadResolutionManager.getResolutionBadge('480p', 480),
        'SD',
      );
    });
  });

  group('AdaptiveBitrateController 60fps ResolutionTier Tests', () {
    test('ResolutionTier.fromVideoResolution correctly sets higher bitrate for 60fps', () {
      final res30 = VideoResolutionV2(
        label: '1080p',
        url: 'https://example.com/1080p.mp4',
        width: 1920,
        height: 1080,
        bitrate: 0, // Fallback to default
      );
      final tier30 = ResolutionTier.fromVideoResolution(res30);
      expect(tier30.bitrate, 5000);
      expect(tier30.fps, 30);
      expect(tier30.is60Fps, isFalse);

      final res60 = VideoResolutionV2(
        label: '1080p60',
        url: 'https://example.com/1080p60.mp4',
        width: 1920,
        height: 1080,
        bitrate: 0, // Fallback to default 60fps
        fps: 60,
      );
      final tier60 = ResolutionTier.fromVideoResolution(res60);
      expect(tier60.bitrate, 7500);
      expect(tier60.fps, 60);
      expect(tier60.is60Fps, isTrue);
      expect(tier60.minBandwidth, 9000); // 7500 * 1.2
    });

    test('defaultBitrateForHeight scales across 720p, 1080p, 1440p, 2160p for 60fps', () {
      expect(ResolutionTier.defaultBitrateForHeight(720, fps: 60), 3800);
      expect(ResolutionTier.defaultBitrateForHeight(720), 2500);

      expect(ResolutionTier.defaultBitrateForHeight(1080, fps: 60), 7500);
      expect(ResolutionTier.defaultBitrateForHeight(1080), 5000);

      expect(ResolutionTier.defaultBitrateForHeight(1440, fps: 60), 14000);
      expect(ResolutionTier.defaultBitrateForHeight(1440), 10000);

      expect(ResolutionTier.defaultBitrateForHeight(2160, fps: 60), 22000);
      expect(ResolutionTier.defaultBitrateForHeight(2160), 15000);

      // Lower tiers stay at 30fps default
      expect(ResolutionTier.defaultBitrateForHeight(480, fps: 60), 1000);
      expect(ResolutionTier.defaultBitrateForHeight(360, fps: 60), 600);
    });

    test('sorting orders 60fps higher than 30fps for matching heights', () {
      final list = [
        VideoResolutionV2(label: '1080p', url: '', width: 1920, height: 1080, bitrate: 5000),
        VideoResolutionV2(label: '1080p60', url: '', width: 1920, height: 1080, bitrate: 7500, fps: 60),
        VideoResolutionV2(label: '720p60', url: '', width: 1280, height: 720, bitrate: 3800, fps: 60),
        VideoResolutionV2(label: '720p', url: '', width: 1280, height: 720, bitrate: 2500),
      ];

      list.sort((a, b) {
        final cmp = b.height.compareTo(a.height);
        if (cmp != 0) return cmp;
        return b.fps.compareTo(a.fps);
      });

      expect(list[0].label, '1080p60');
      expect(list[1].label, '1080p');
      expect(list[2].label, '720p60');
      expect(list[3].label, '720p');
    });
  });
}
