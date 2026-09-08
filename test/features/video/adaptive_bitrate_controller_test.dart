import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResolutionTier.fromVideoResolution Unit Tests', () {
    test('converts bps bitrate (> 50,000) to kbps and computes accurate minBandwidth', () {
      final res1080 = VideoResolutionV2(
        label: '1080p',
        url: 'https://example.com/1080.mp4',
        width: 1920,
        height: 1080,
        bitrate: 4500000, // 4.5 Mbps in bps
      );

      final tier = ResolutionTier.fromVideoResolution(res1080);
      expect(tier.label, '1080p');
      expect(tier.height, 1080);
      expect(tier.bitrate, 4500); // 4500 kbps
      expect(tier.minBandwidth, 5400); // 4500 * 1.2
    });

    test('preserves kbps bitrate (<= 50,000) and computes accurate minBandwidth', () {
      final res720 = VideoResolutionV2(
        label: '720p',
        url: 'https://example.com/720.mp4',
        width: 1280,
        height: 720,
        bitrate: 2500, // already in kbps
      );

      final tier = ResolutionTier.fromVideoResolution(res720);
      expect(tier.label, '720p');
      expect(tier.height, 720);
      expect(tier.bitrate, 2500);
      expect(tier.minBandwidth, 3000); // 2500 * 1.2
    });

    test('falls back to default bitrate for height when bitrate is 0 or negative', () {
      final res480 = VideoResolutionV2(
        label: '480p',
        url: 'https://example.com/480.mp4',
        width: 854,
        height: 480,
        bitrate: 0,
      );

      final tier = ResolutionTier.fromVideoResolution(res480);
      expect(tier.label, '480p');
      expect(tier.height, 480);
      expect(tier.bitrate, 1000); // default for 480p
      expect(tier.minBandwidth, 1200); // 1000 * 1.2
    });
  });

  group('AdaptiveBitrateController Quality Ladder Tests', () {
    test('standard ladder contains expected tiers and bandwidth requirements', () {
      final ladder = [
        ResolutionTier.fromVideoResolution(
          VideoResolutionV2(label: '144p', url: '', width: 256, height: 144, bitrate: 200000),
        ),
        ResolutionTier.fromVideoResolution(
          VideoResolutionV2(label: '240p', url: '', width: 426, height: 240, bitrate: 400000),
        ),
        ResolutionTier.fromVideoResolution(
          VideoResolutionV2(label: '360p', url: '', width: 640, height: 360, bitrate: 800000),
        ),
        ResolutionTier.fromVideoResolution(
          VideoResolutionV2(label: '480p', url: '', width: 854, height: 480, bitrate: 1200000),
        ),
        ResolutionTier.fromVideoResolution(
          VideoResolutionV2(label: '720p', url: '', width: 1280, height: 720, bitrate: 2500000),
        ),
        ResolutionTier.fromVideoResolution(
          VideoResolutionV2(label: '1080p', url: '', width: 1920, height: 1080, bitrate: 4500000),
        ),
      ];

      expect(ladder.length, 6);
      expect(ladder[0].minBandwidth, 240); // 144p: 200 kbps * 1.2 = 240 kbps
      expect(ladder[3].minBandwidth, 1440); // 480p: 1200 kbps * 1.2 = 1440 kbps
      expect(ladder[5].minBandwidth, 5400); // 1080p: 4500 kbps * 1.2 = 5400 kbps

      // A 10 Mbps connection (10000 kbps) with 80% safety factor (8000 kbps)
      // easily satisfies 1080p (5400 kbps <= 8000 kbps)
      const effectiveBw = 10000 * 0.8;
      var bestTierIndex = 0;
      for (var i = ladder.length - 1; i >= 0; i--) {
        if (effectiveBw >= ladder[i].minBandwidth) {
          bestTierIndex = i;
          break;
        }
      }

      expect(bestTierIndex, 5);
      expect(ladder[bestTierIndex].label, '1080p');
    });
  });
}
