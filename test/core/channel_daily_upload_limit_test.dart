import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/channel.dart';

void main() {
  group('Standard Channel Daily Video Upload Limit Tests', () {
    late Channel standardChannel;
    late Channel customChannel;

    setUp(() {
      standardChannel = Channel(
        id: 'std_channel_123',
        name: 'Standard Creator',
        nameLowercase: 'standard creator',
        handle: '@standardcreator',
        handleLowercase: '@standardcreator',
        description: 'Standard channel test',
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        ownerId: 'user_std_1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      customChannel = Channel(
        id: 'cust_channel_456',
        name: 'Custom Creator',
        nameLowercase: 'custom creator',
        handle: '@customcreator',
        handleLowercase: '@customcreator',
        description: 'Custom channel test',
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        ownerId: 'user_cust_1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        channelType: ChannelType.custom,
      );
    });

    test('Helper formatDurationMinutesSeconds formats correctly', () {
      expect(ContentValidationMixin.formatDurationMinutesSeconds(900), equals('15 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(600), equals('10 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(300), equals('5 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(330), equals('5m 30s'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(0), equals('0 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(-5), equals('0 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(1200), equals('20 min'));
    });

    test('Standard channel: Uploading 7s video or audio with 0m uploaded today is VALID', () {
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 7, // 7 seconds (short media allowed)
      );
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('Standard channel: Uploading 7m video with 0m uploaded today is VALID', () {
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 7 * 60, // 7 minutes = 420 seconds
      );
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('Standard channel: Uploading 3m video when 7m already uploaded today is VALID', () {
      // 7m used + 3m new = 10m total (exact 10 min cap)
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 3 * 60, // 3 minutes = 180 seconds
        dailyUploadedDurationSeconds: 7 * 60, // 7 minutes = 420 seconds
      );
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('Standard channel: Uploading 4m video when 7m already uploaded today is BLOCKED', () {
      // 7m used + 4m new = 11m total (> 10m cap)
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 4 * 60, // 4 minutes = 240 seconds
        dailyUploadedDurationSeconds: 7 * 60, // 7 minutes = 420 seconds
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Daily limit exceeded'));
      expect(res.message, contains('7 min today'));
      expect(res.message, contains('3 min remaining'));
      expect(res.message, contains('4 min'));
    });

    test('Standard channel: Any upload when 10m already uploaded today is BLOCKED', () {
      // 10m already used today
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 60, // 1 minute
        dailyUploadedDurationSeconds: 10 * 60, // 10 minutes = 600 seconds
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Daily upload limit reached'));
      expect(res.message, contains('10-minute daily limit for today'));
    });

    test('Standard channel: Single video exceeding 10m (>600s) is BLOCKED', () {
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 15 * 60, // 15 minutes = 900 seconds
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Standard channel video duration cannot exceed 10 minutes'));
    });

    test('Custom channel: Uploading 60m or 120m video with existing daily duration is VALID', () {
      final res = ContentValidator.validateChannelVideoUpload(
        customChannel,
        durationSeconds: 60 * 60, // 1 hour = 3600 seconds
        dailyUploadedDurationSeconds: 120 * 60, // 2 hours already uploaded today
      );
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('Channel model getters reflect 10 min daily duration constraint for Standard', () {
      expect(standardChannel.maxDailyVideoDurationSeconds, equals(600));
      expect(standardChannel.maxVideoDurationSeconds, equals(600));
      expect(customChannel.maxDailyVideoDurationSeconds, equals(86400));
      expect(customChannel.maxVideoDurationSeconds, equals(86400));
    });

    test('Standard channel with Admin increased quota (30 min / 1800s): Allows longer uploads', () {
      final increasedChannel = standardChannel.copyWith(
        customDailyVideoDurationSeconds: 30 * 60, // 30 minutes = 1800s
        customMaxVideoDurationSeconds: 30 * 60,
        quotaIncreasedBy: 'admin@truthworld.in',
        quotaIncreaseReason: 'Documentary creator expansion',
      );

      expect(increasedChannel.maxDailyVideoDurationSeconds, equals(1800));
      expect(increasedChannel.maxVideoDurationSeconds, equals(1800));
      expect(increasedChannel.hasCustomQuota, isTrue);

      // 1. Single 15-minute video is now VALID (was blocked under 10m default cap)
      final res15m = ContentValidator.validateChannelVideoUpload(
        increasedChannel,
        durationSeconds: 15 * 60,
      );
      expect(res15m.isValid, isTrue);
      expect(res15m.message, equals('Valid'));

      // 2. Uploading 15m when 10m already uploaded is VALID (10m + 15m = 25m <= 30m)
      final resCombine = ContentValidator.validateChannelVideoUpload(
        increasedChannel,
        durationSeconds: 15 * 60,
        dailyUploadedDurationSeconds: 10 * 60,
      );
      expect(resCombine.isValid, isTrue);

      // 3. Uploading 25m when 10m already uploaded is BLOCKED (10m + 25m = 35m > 30m)
      final resExceed = ContentValidator.validateChannelVideoUpload(
        increasedChannel,
        durationSeconds: 25 * 60,
        dailyUploadedDurationSeconds: 10 * 60,
      );
      expect(resExceed.isValid, isFalse);
      expect(resExceed.message, contains('Daily limit exceeded'));
      expect(resExceed.message, contains('30 min per day'));

      // 4. Single 35m video is BLOCKED (> 30m max single video)
      final resSingleExceed = ContentValidator.validateChannelVideoUpload(
        increasedChannel,
        durationSeconds: 35 * 60,
      );
      expect(resSingleExceed.isValid, isFalse);
      expect(resSingleExceed.message, contains('Standard channel video duration cannot exceed 30 min (1800 seconds)'));
    });

    test('Standard channel: Resetting custom quota restores standard 10-minute limits', () {
      final increasedChannel = standardChannel.copyWith(
        customDailyVideoDurationSeconds: 45 * 60,
        quotaIncreasedBy: 'admin@truthworld.in',
      );
      expect(increasedChannel.hasCustomQuota, isTrue);

      final resetChannel = increasedChannel.copyWith(clearCustomQuota: true);
      expect(resetChannel.hasCustomQuota, isFalse);
      expect(resetChannel.maxDailyVideoDurationSeconds, equals(600));
      expect(resetChannel.maxVideoDurationSeconds, equals(600));
      expect(resetChannel.customDailyVideoDurationSeconds, isNull);
    });

    test('Channel serialization handles customDailyUploadLimitMinutes and quota audit info', () {
      final channelMap = {
        'id': 'std_quota_test',
        'name': 'Quota Creator',
        'handle': '@quotacreator',
        'description': 'Channel with increased quota',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'bannerUrl': 'https://example.com/banner.jpg',
        'ownerId': 'user_quota_1',
        'channelType': 'standard',
        'customDailyUploadLimitMinutes': 25, // 25 minutes
        'quotaIncreasedBy': 'admin@truthworld.in',
        'quotaIncreaseReason': 'Verified partner request',
      };

      final channel = Channel.fromMap(channelMap, 'std_quota_test');
      expect(channel.customDailyVideoDurationSeconds, equals(25 * 60)); // 1500 seconds
      expect(channel.maxDailyVideoDurationSeconds, equals(1500));
      expect(channel.hasCustomQuota, isTrue);
      expect(channel.quotaIncreasedBy, equals('admin@truthworld.in'));
      expect(channel.quotaIncreaseReason, equals('Verified partner request'));

      final serialized = channel.toMap();
      expect(serialized['customDailyVideoDurationSeconds'], equals(1500));
      expect(serialized['customDailyUploadLimitMinutes'], equals(25));
      expect(serialized['hasCustomQuota'], isTrue);
      expect(serialized['quotaIncreasedBy'], equals('admin@truthworld.in'));
    });
  });
}
