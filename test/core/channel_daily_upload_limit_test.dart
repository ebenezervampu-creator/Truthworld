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
      expect(ContentValidationMixin.formatDurationMinutesSeconds(300), equals('5 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(330), equals('5m 30s'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(0), equals('0 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(-5), equals('0 min'));
      expect(ContentValidationMixin.formatDurationMinutesSeconds(1200), equals('20 min'));
    });

    test('Standard channel: Uploading 15m video with 0m uploaded today is VALID', () {
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 15 * 60, // 15 minutes = 900 seconds
      );
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('Standard channel: Uploading 5m video when 15m already uploaded today is VALID', () {
      // 15m used + 5m new = 20m total (exact 20 min cap)
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 5 * 60, // 5 minutes = 300 seconds
        dailyUploadedDurationSeconds: 15 * 60, // 15 minutes = 900 seconds
      );
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('Standard channel: Uploading 6m video when 15m already uploaded today is BLOCKED', () {
      // 15m used + 6m new = 21m total (> 20m cap)
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 6 * 60, // 6 minutes = 360 seconds
        dailyUploadedDurationSeconds: 15 * 60, // 15 minutes = 900 seconds
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Daily limit exceeded'));
      expect(res.message, contains('15 min today'));
      expect(res.message, contains('5 min remaining'));
      expect(res.message, contains('6 min'));
    });

    test('Standard channel: Any upload when 20m already uploaded today is BLOCKED', () {
      // 20m already used today
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 60, // 1 minute
        dailyUploadedDurationSeconds: 20 * 60, // 20 minutes = 1200 seconds
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Daily upload limit reached'));
      expect(res.message, contains('20-minute daily limit for today'));
    });

    test('Standard channel: Single video exceeding 20m (>1200s) is BLOCKED', () {
      final res = ContentValidator.validateChannelVideoUpload(
        standardChannel,
        durationSeconds: 25 * 60, // 25 minutes = 1500 seconds
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Standard channel video duration cannot exceed 20 minutes'));
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

    test('Channel model getters reflect 20 min daily duration constraint for Standard', () {
      expect(standardChannel.maxDailyVideoDurationSeconds, equals(1200));
      expect(standardChannel.maxVideoDurationSeconds, equals(1200));
      expect(customChannel.maxDailyVideoDurationSeconds, equals(86400));
      expect(customChannel.maxVideoDurationSeconds, equals(86400));
    });
  });
}
