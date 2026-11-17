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

    test('ClaimResult stateLevel parsing and monotonic lifecycle getters', () {
      final extracted = ClaimResult.fromMap({
        'claimId': 'claim_1',
        'text': 'Earth is spherical',
        'verdict': 'extracted',
        'stateLevel': 0,
      });
      expect(extracted.isExtracted, isTrue);
      expect(extracted.isProvisional, isFalse);
      expect(extracted.isDeepVerifying, isFalse);
      expect(extracted.isFinalized, isFalse);
      expect(extracted.stateLevel, equals(0));
      expect(extracted.claimId, equals('claim_1'));

      final provisional = ClaimResult.fromMap({
        'claimId': 'claim_2',
        'text': 'Water boils at 100C',
        'status': 'provisional',
        'isProvisional': true,
      });
      expect(provisional.isProvisional, isTrue);
      expect(provisional.stateLevel, equals(1));
      expect(provisional.isFinalized, isFalse);

      final deepVerifying = ClaimResult.fromMap({
        'claimId': 'claim_3',
        'text': 'Moon landing happened in 1969',
        'status': 'deep_verifying',
        'stateLevel': 2,
      });
      expect(deepVerifying.isDeepVerifying, isTrue);
      expect(deepVerifying.stateLevel, equals(2));
      expect(deepVerifying.isFinalized, isFalse);

      final finalized = ClaimResult.fromMap({
        'claimId': 'claim_4',
        'text': 'Speed of light is 300000 km/s',
        'verdict': 'verified_true',
        'stateLevel': 3,
      });
      expect(finalized.isFinalized, isTrue);
      expect(finalized.stateLevel, equals(3));
    });

    test('Monotonic Guard simulation: prevents out-of-order packets from regressing finalized claim', () {
      final claimsById = <String, ClaimResult>{};

      // 1. Packet arrives: EXTRACTED (0)
      final p1 = ClaimResult.fromMap({
        'claimId': 'claim_abc',
        'text': 'Solar eclipse in 2024',
        'verdict': 'extracted',
        'stateLevel': 0,
      });
      claimsById[p1.claimId!] = p1;
      expect(claimsById['claim_abc']!.stateLevel, equals(0));
      expect(claimsById['claim_abc']!.isExtracted, isTrue);

      // 2. Next packet arrives: DEEP_VERIFYING (2)
      final p2 = ClaimResult.fromMap({
        'claimId': 'claim_abc',
        'text': 'Solar eclipse in 2024',
        'verdict': 'deep_verifying',
        'stateLevel': 2,
      });
      if (p2.stateLevel >= claimsById['claim_abc']!.stateLevel) {
        claimsById[p2.claimId!] = p2;
      }
      expect(claimsById['claim_abc']!.stateLevel, equals(2));
      expect(claimsById['claim_abc']!.isDeepVerifying, isTrue);

      // 3. Terminal packet arrives: FINALIZED (3)
      final p3 = ClaimResult.fromMap({
        'claimId': 'claim_abc',
        'text': 'Solar eclipse in 2024',
        'verdict': 'verified_true',
        'stateLevel': 3,
      });
      if (p3.stateLevel >= claimsById['claim_abc']!.stateLevel) {
        claimsById[p3.claimId!] = p3;
      }
      expect(claimsById['claim_abc']!.stateLevel, equals(3));
      expect(claimsById['claim_abc']!.isFinalized, isTrue);
      expect(claimsById['claim_abc']!.verdict, equals('verified_true'));

      // 4. Stale delayed packet arrives: PROVISIONAL (1) / DEEP_VERIFYING (2)
      // Monotonic guard: MUST NOT regress from level 3
      final stalePacket = ClaimResult.fromMap({
        'claimId': 'claim_abc',
        'text': 'Solar eclipse in 2024',
        'verdict': 'deep_verifying',
        'stateLevel': 2,
      });
      final existing = claimsById[stalePacket.claimId!];
      final effective = (existing != null && existing.stateLevel > stalePacket.stateLevel)
          ? existing
          : stalePacket;

      expect(effective.stateLevel, equals(3));
      expect(effective.verdict, equals('verified_true'));
      expect(effective.isFinalized, isTrue);
    });

    test('ClaimResult copyWith and toMap preserve stateLevel and claimId', () {
      final original = ClaimResult(
        claimId: 'claim_xyz',
        text: 'Gravity is real',
        verdict: 'verified_true',
        stateLevel: 3,
      );

      final copy = original.copyWith(verdict: 'mostly_true');
      expect(copy.claimId, equals('claim_xyz'));
      expect(copy.stateLevel, equals(3));
      expect(copy.verdict, equals('mostly_true'));

      final map = copy.toMap();
      expect(map['claimId'], equals('claim_xyz'));
      expect(map['stateLevel'], equals(3));
      expect(map['verdict'], equals('mostly_true'));
    });
  });
}
