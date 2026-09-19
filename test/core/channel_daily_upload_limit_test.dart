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
  });
}
