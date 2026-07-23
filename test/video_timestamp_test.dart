import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('Video Timestamp Parsing Tests', () {
    test('Should parse uploadedAt correctly when data has only uploadedAt', () {
      final now = Timestamp.now();
      final threeHoursAgo = Timestamp.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch - 3 * 60 * 60 * 1000,
      );

      final data = {
        'id': 'test_video_1',
        'title': 'Test Video',
        'description': 'Description',
        'thumbnailUrl': 'https://example.com/thumb.png',
        'ownerId': 'owner_1',
        'channelId': 'channel_1',
        'channelName': 'Channel Name',
        'category': 'Education',
        'tags': ['test'],
        'uploadedAt': threeHoursAgo,
      };

      final video = Video.fromMap(data);
      expect(video.uploadedAt, threeHoursAgo);
      expect(video.createdAt, threeHoursAgo);
    });

    test('Should fallback to publishedAt if uploadedAt is missing but publishedAt is present', () {
      final now = Timestamp.now();
      final oneDayAgo = Timestamp.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch - 24 * 60 * 60 * 1000,
      );

      final data = {
        'id': 'test_video_2',
        'title': 'Test Video 2',
        'description': 'Description 2',
        'thumbnailUrl': 'https://example.com/thumb2.png',
        'ownerId': 'owner_2',
        'channelId': 'channel_2',
        'channelName': 'Channel Name 2',
        'category': 'Entertainment',
        'tags': ['test'],
        'publishedAt': oneDayAgo,
      };

      final video = Video.fromMap(data);
      expect(video.uploadedAt, oneDayAgo);
      expect(video.createdAt, oneDayAgo);
    });

    test('Should parse createdAt when it is present in the map', () {
      final now = Timestamp.now();
      final tenDaysAgo = Timestamp.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch - 10 * 24 * 60 * 60 * 1000,
      );

      final data = {
        'id': 'test_video_3',
        'title': 'Test Video 3',
        'description': 'Description 3',
        'thumbnailUrl': 'https://example.com/thumb3.png',
        'ownerId': 'owner_3',
        'channelId': 'channel_3',
        'channelName': 'Channel Name 3',
        'category': 'Music',
        'tags': ['test'],
        'createdAt': tenDaysAgo,
      };

      final video = Video.fromMap(data);
      expect(video.uploadedAt, tenDaysAgo);
      expect(video.createdAt, tenDaysAgo);
    });
  });
}
