import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('VideoSanitizer returns a modifiable list that supports sorting', () {
    final video1 = Video(
      id: 'v1',
      title: 'Video 1',
      description: 'Desc 1',
      thumbnailUrl: 'https://example.com/v1.jpg',
      ownerId: 'owner1',
      channelId: 'ch1',
      channelName: 'Channel 1',
      category: 'General',
      tags: [],
      videoUrl: 'https://example.com/v1.mp4',
      views: 100,
      createdAt: Timestamp.now(),
      status: VideoStatus.ready,
    );

    final video2 = Video(
      id: 'v2',
      title: 'Video 2',
      description: 'Desc 2',
      thumbnailUrl: 'https://example.com/v2.jpg',
      ownerId: 'owner2',
      channelId: 'ch2',
      channelName: 'Channel 2',
      category: 'General',
      tags: [],
      videoUrl: 'https://example.com/v2.mp4',
      views: 500,
      createdAt: Timestamp.now(),
      status: VideoStatus.ready,
    );

    final sanitized = VideoSanitizer.sanitizeForFeed([video1, video2]);

    expect(() => sanitized.sort((a, b) => b.views.compareTo(a.views)), returnsNormally);
    expect(sanitized.first.id, equals('v2'));
  });
}
