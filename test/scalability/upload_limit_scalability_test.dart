// Upload Rate Limit Scalability Tests
//
// Verifies ContentValidator.validateChannelVideoUpload() correctness across
// hundreds of channels simultaneously, exact boundary conditions, custom-channel
// overrides, and batch throughput at creator scale.
//
// All tests are pure Dart — no Flutter widgets, no Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/channel.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Channel _makeStandardChannel(String id) => Channel(
      id: id,
      name: 'Standard Channel $id',
      nameLowercase: 'standard channel $id',
      handle: '@standard_$id',
      handleLowercase: '@standard_$id',
      description: 'Standard channel for scalability test',
      avatarUrl: 'https://example.com/avatar.jpg',
      bannerUrl: 'https://example.com/banner.jpg',
      ownerId: 'owner_$id',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      // channelType defaults to ChannelType.standard
    );

Channel _makeCustomChannel(String id) => Channel(
      id: id,
      name: 'Custom Channel $id',
      nameLowercase: 'custom channel $id',
      handle: '@custom_$id',
      handleLowercase: '@custom_$id',
      description: 'Custom channel for scalability test',
      avatarUrl: 'https://example.com/avatar.jpg',
      bannerUrl: 'https://example.com/banner.jpg',
      ownerId: 'owner_$id',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      channelType: ChannelType.custom,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Group 1: Standard Limit Boundary Conditions ────────────────────────

  group('Standard Channel — Limit Boundary Conditions', () {
    const maxDailySeconds = 600; // 10 minutes

    test('Boundary: uploading exactly 10 min (600s) with 0s already uploaded — VALID', () {
      final channel = _makeStandardChannel('ch_exact_boundary');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: maxDailySeconds, // exactly at the cap
      );
      expect(result.isValid, isTrue,
          reason: 'A 10-minute upload with 0s used must be valid (at-boundary, not over).');
    });

    test('Boundary: uploading 601s single video — BLOCKED (over single-video cap)', () {
      final channel = _makeStandardChannel('ch_over_single');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 601, // 1 second over 10-minute cap
      );
      expect(result.isValid, isFalse);
      expect(result.message, contains('Standard channel video duration cannot exceed 10 minutes'));
    });

    test('Boundary: daily quota exactly reached (600s used) — any upload BLOCKED', () {
      final channel = _makeStandardChannel('ch_quota_exact');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 1, // even 1 second
        dailyUploadedDurationSeconds: maxDailySeconds, // exactly at cap
      );
      expect(result.isValid, isFalse);
      expect(result.message, contains('Daily upload limit reached'));
    });

    test('Boundary: 1s remaining quota — 1s upload VALID, 2s upload BLOCKED', () {
      final channel = _makeStandardChannel('ch_1s_remaining');
      const usedSeconds = maxDailySeconds - 1; // 599s used

      final validResult = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 1,
        dailyUploadedDurationSeconds: usedSeconds,
        enforceMinimumDuration: false,
      );
      expect(validResult.isValid, isTrue,
          reason: 'Exactly 1 second remaining must allow a 1-second upload.');

      final blockedResult = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 2,
        dailyUploadedDurationSeconds: usedSeconds,
        enforceMinimumDuration: false,
      );
      expect(blockedResult.isValid, isFalse,
          reason: 'A 2-second upload when only 1s remains must be blocked.');
      expect(blockedResult.message, contains('Daily limit exceeded'));
    });

    test('Zero-duration upload (0s) with 0s used — VALID (edge case)', () {
      final channel = _makeStandardChannel('ch_zero_duration');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 0,
      );
      // 0 is not > 600, 0 used is not >= 600, 0+0 is not > 600
      expect(result.isValid, isTrue);
    });

    test('Partial daily quota used: correct remaining amount in error message', () {
      final channel = _makeStandardChannel('ch_partial_quota');
      const used = 7 * 60; // 420s = 7 min
      const newVideo = 4 * 60; // 240s = 4 min (over the 3 min remaining)

      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: newVideo,
        dailyUploadedDurationSeconds: used,
      );
      expect(result.isValid, isFalse);
      expect(result.message, contains('7 min today'));
      expect(result.message, contains('3 min remaining'));
      expect(result.message, contains('4 min'));
    });
  });

  // ── Group 2: Custom Channel — Unlimited Uploads ────────────────────────

  group('Custom Channel — Unlimited Uploads', () {
    test('Custom channel: 24-hour (86400s) video upload with no prior uploads — VALID', () {
      final channel = _makeCustomChannel('ch_custom_max');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 86400, // 24 hours
      );
      expect(result.isValid, isTrue);
      expect(result.message, equals('Valid'));
    });

    test('Custom channel: upload after 24h already uploaded today — VALID (unlimited)', () {
      final channel = _makeCustomChannel('ch_custom_unlimited');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 3600, // 1 more hour
        dailyUploadedDurationSeconds: 86400, // already uploaded 24h today
      );
      expect(result.isValid, isTrue,
          reason: 'Custom channels have no daily upload ceiling.');
    });

    test('Custom channel: very large video (10-hour = 36000s) — VALID', () {
      final channel = _makeCustomChannel('ch_custom_long_video');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 36000, // 10 hours
      );
      expect(result.isValid, isTrue);
    });
  });

  // ── Group 3: Cross-Channel Isolation ──────────────────────────────────

  group('Cross-Channel Isolation at Volume', () {
    test(
        '100 standard channels checked simultaneously: '
        'each enforces its own independent quota (no bleed-across)', () {
      final results = <String, bool>{};

      for (var i = 0; i < 100; i++) {
        final channel = _makeStandardChannel('ch_isolation_$i');
        // Odd channels: 7 min used, 4 min new video → 7+4=11 min > 10 min → BLOCKED
        // Even channels: 5 min used, 3 min new video → 5+3=8 min ≤ 10 min → VALID
        final usedSeconds = i.isOdd ? 7 * 60 : 5 * 60;
        final newVideoSeconds = i.isOdd ? 4 * 60 : 3 * 60;

        final result = ContentValidator.validateChannelVideoUpload(
          channel,
          durationSeconds: newVideoSeconds,
          dailyUploadedDurationSeconds: usedSeconds,
        );
        results['ch_isolation_$i'] = result.isValid;
      }

      // Odd channels (1, 3, 5, ... 99) must all be BLOCKED
      // Even channels (0, 2, 4, ... 98) must all be VALID
      for (var i = 0; i < 100; i++) {
        final expectedValid = i.isEven;
        expect(results['ch_isolation_$i'], equals(expectedValid),
            reason: 'Channel ch_isolation_$i: expected isValid=$expectedValid '
                'but got ${results['ch_isolation_$i']}. '
                'Channel quotas must be completely independent.');
      }
    });

    test(
        'Channel model getters maxDailyVideoDurationSeconds and maxVideoDurationSeconds '
        'are correct for standard vs custom at 100 channels each', () {
      for (var i = 0; i < 100; i++) {
        final standard = _makeStandardChannel('std_$i');
        final custom = _makeCustomChannel('cust_$i');

        expect(standard.maxDailyVideoDurationSeconds, equals(600),
            reason: 'Standard channel $i must report 600s daily limit.');
        expect(standard.maxVideoDurationSeconds, equals(600),
            reason: 'Standard channel $i must report 600s single-video limit.');

        expect(custom.maxDailyVideoDurationSeconds, equals(86400),
            reason: 'Custom channel $i must report 86400s (24h) daily limit.');
        expect(custom.maxVideoDurationSeconds, equals(86400),
            reason: 'Custom channel $i must report 86400s (24h) single-video limit.');
      }
    });
  });

  // ── Group 4: Batch Throughput ──────────────────────────────────────────

  group('Batch Throughput at Creator Scale', () {
    test(
        'Validate 1,000 channels sequentially in under 100 ms '
        '(validation must not be a bottleneck at platform scale)', () {
      final channels = List.generate(1000, (i) => _makeStandardChannel('ch_throughput_$i'));

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        ContentValidator.validateChannelVideoUpload(
          channels[i],
          durationSeconds: 300, // 5 minutes
          dailyUploadedDurationSeconds: (i % 3) * 200, // 0s, 200s, 400s cycling
        );
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Validating 1,000 channels must complete within 100 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test(
        'Mixed standard/custom 500-channel batch: all results are correct '
        'with no cross-type contamination', () {
      var validCount = 0;
      var blockedCount = 0;

      for (var i = 0; i < 500; i++) {
        final isCustom = i % 2 == 0;
        final channel = isCustom
            ? _makeCustomChannel('ch_mixed_$i')
            : _makeStandardChannel('ch_mixed_$i');

        // Upload a 15-minute video (900s) — over standard limit (600s), fine for custom
        final result = ContentValidator.validateChannelVideoUpload(
          channel,
          durationSeconds: 15 * 60, // 900s
        );

        if (isCustom) {
          expect(result.isValid, isTrue,
              reason: 'Custom channel ch_mixed_$i must accept a 15-min upload.');
          validCount++;
        } else {
          expect(result.isValid, isFalse,
              reason: 'Standard channel ch_mixed_$i must reject a 15-min single video.');
          blockedCount++;
        }
      }

      // 250 custom (valid) + 250 standard (blocked)
      expect(validCount, equals(250));
      expect(blockedCount, equals(250));
    });
  });

  // ── Group 5: currentTotalDurationSeconds fallback ──────────────────────

  group('effectiveDailyUploaded — Parameter Fallback Logic', () {
    test(
        'currentTotalDurationSeconds is used as fallback when '
        'dailyUploadedDurationSeconds is 0', () {
      final channel = _makeStandardChannel('ch_fallback');
      // currentTotalDurationSeconds=420 (7 min), dailyUploadedDurationSeconds=0 (default)
      // effectiveDailyUploaded should be 420
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 4 * 60, // 4 min — would push 7+4=11 min over 10 min cap
        currentTotalDurationSeconds: 7 * 60, // 420s
      );
      expect(result.isValid, isFalse,
          reason: 'currentTotalDurationSeconds must be used as the effective daily usage '
              'when dailyUploadedDurationSeconds is 0.');
    });

    test(
        'dailyUploadedDurationSeconds takes precedence over '
        'currentTotalDurationSeconds when both are provided', () {
      final channel = _makeStandardChannel('ch_precedence');
      // dailyUploadedDurationSeconds=300 (5 min) → 5+3=8 min ≤ 10 min → VALID
      // currentTotalDurationSeconds=420 (7 min) → 7+3=10 min ≤ 10 min → also VALID
      // But if dailyUploadedDurationSeconds=550, that + 100 = 650 > 600 → BLOCKED
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 100, // ~1.6 min
        dailyUploadedDurationSeconds: 550, // 9.16 min → takes precedence
        currentTotalDurationSeconds: 300,   // 5 min — should be ignored
      );
      expect(result.isValid, isFalse,
          reason: 'dailyUploadedDurationSeconds=550 should take precedence over '
              'currentTotalDurationSeconds=300. Upload of 100s should be blocked.');
    });
  });

  // ── Group 6: Truthworld Short Media Support (even 7s allowed, no 2-min limit) ─────

  group('Truthworld Short Media Support (Allows Even 7s Video/Audio)', () {
    test('Standard channel: video of 7s is VALID (allows short media)', () {
      final channel = _makeStandardChannel('ch_min_7s_std');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 7,
      );
      expect(result.isValid, isTrue);
      expect(result.message, equals('Valid'));
    });

    test('Standard channel: video shorter than 120s (e.g. 45s, 119s) is VALID', () {
      final channel = _makeStandardChannel('ch_min_std');
      final result45 = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 45,
      );
      expect(result45.isValid, isTrue);

      final result119 = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 119,
      );
      expect(result119.isValid, isTrue);
    });

    test('Standard channel: video exactly 120s (2 minutes) is VALID', () {
      final channel = _makeStandardChannel('ch_min_std_exact');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 120,
      );
      expect(result.isValid, isTrue);
    });

    test('Custom channel: short video (e.g. 7s or 45s) is VALID', () {
      final channel = _makeCustomChannel('ch_min_custom');
      final result7 = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 7,
      );
      expect(result7.isValid, isTrue);

      final result45 = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 45,
      );
      expect(result45.isValid, isTrue);
    });

    test('Custom channel: video of 120s or more is VALID', () {
      final channel = _makeCustomChannel('ch_min_custom_valid');
      final result = ContentValidator.validateChannelVideoUpload(
        channel,
        durationSeconds: 120,
      );
      expect(result.isValid, isTrue);
    });
  });
}
