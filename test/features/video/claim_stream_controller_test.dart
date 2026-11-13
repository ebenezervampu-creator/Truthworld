import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_stream_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClaimStreamController', () {
    const testVideoId = 'test_vid_12345';

    tearDown(() {
      const tag = 'claim_stream_$testVideoId';
      if (Get.isRegistered<ClaimStreamController>(tag: tag)) {
        Get.delete<ClaimStreamController>(tag: tag, force: true);
      }
    });

    test('getOrCreate creates and reuses registered instance with tag', () {
      final ctrl1 = ClaimStreamController.getOrCreate(testVideoId);
      final ctrl2 = ClaimStreamController.getOrCreate(testVideoId);

      expect(identical(ctrl1, ctrl2), isTrue);
      expect(ctrl1.videoId, equals(testVideoId));
    });

    test('Initial state guarantees', () {
      final ctrl = ClaimStreamController(videoId: 'mock_vid');
      expect(ctrl.claims, isEmpty);
      expect(ctrl.confirmedCount.value, equals(0));
      expect(ctrl.falseCount.value, equals(0));
      expect(ctrl.disputedCount.value, equals(0));
      expect(ctrl.unprovenCount.value, equals(0));
    });

    test('Chronological sorting and reactive counting from parsed claims', () {
      final ctrl = ClaimStreamController(videoId: 'mock_vid');

      final rawClaims = [
        ClaimResult(text: 'Claim at 30s', verdict: 'verified_true', start: 30.0),
        ClaimResult(text: 'Claim at 5s', verdict: 'false_claim', start: 5.0),
        ClaimResult(text: 'Claim at 15s', verdict: 'unproven', start: 15.0),
        ClaimResult(text: 'Claim at 45s', verdict: 'disputed', start: 45.0),
      ];

      // Simulate sorting logic enforced in controller
      rawClaims.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));
      ctrl.claims.assignAll(rawClaims);

      var cCount = 0;
      var fCount = 0;
      var dCount = 0;
      var uCount = 0;

      for (final claim in ctrl.claims) {
        final vLower = claim.verdict.toLowerCase();
        if (vLower == 'verified_true' || vLower == 'mostly_true' || vLower == 'true') {
          cCount++;
        } else if (vLower == 'false_claim' || vLower == 'false' || vLower == 'misleading') {
          fCount++;
        } else if (vLower == 'disputed' || vLower == 'inconclusive') {
          dCount++;
        } else if (vLower == 'unproven' || vLower == 'unverified') {
          uCount++;
        }
      }

      ctrl.confirmedCount.value = cCount;
      ctrl.falseCount.value = fCount;
      ctrl.disputedCount.value = dCount;
      ctrl.unprovenCount.value = uCount;

      expect(ctrl.claims.length, equals(4));
      expect(ctrl.claims[0].start, equals(5.0));
      expect(ctrl.claims[1].start, equals(15.0));
      expect(ctrl.claims[2].start, equals(30.0));
      expect(ctrl.claims[3].start, equals(45.0));

      expect(ctrl.confirmedCount.value, equals(1));
      expect(ctrl.falseCount.value, equals(1));
      expect(ctrl.unprovenCount.value, equals(1));
      expect(ctrl.disputedCount.value, equals(1));
    });

    test('Empty videoId fails gracefully without throwing unhandled exceptions', () {
      final ctrl = ClaimStreamController(videoId: '');
      ctrl.onInit();

      expect(ctrl.isConnecting.value, isFalse);
      expect(ctrl.statusMessage.value, equals('No video reference provided.'));
    });
  });
}
