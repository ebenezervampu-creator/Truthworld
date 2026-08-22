import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/clip_share_service.dart';

void main() {
  group('ClipShareService', () {
    test('buildClipUrl generates valid deep link URL with encoded title', () {
      final url = ClipShareService.buildClipUrl(
        videoId: 'vid_123',
        startSeconds: 15.0,
        endSeconds: 30.0,
        clipTitle: 'Epic Moment!',
      );

      expect(
        url,
        equals(
          'https://www.truthworld.in/watch?v=vid_123&start=15&end=30&clipTitle=Epic%20Moment!',
        ),
      );
    });

    test('formatClipSegment formats start, end, and duration correctly', () {
      final segment = ClipShareService.formatClipSegment(10.0, 25.0);
      expect(segment, equals('00:10 - 00:25 (15s)'));

      final minuteSegment = ClipShareService.formatClipSegment(65.0, 95.0);
      expect(minuteSegment, equals('01:05 - 01:35 (30s)'));
    });

    test('buildWatermarkCaption includes clean TikTok style caption with title, channel, segment, and watch link', () {
      final clipUrl = ClipShareService.buildClipUrl(
        videoId: 'v123',
        startSeconds: 10.0,
        endSeconds: 25.0,
        clipTitle: 'Key Revelation',
      );

      final caption = ClipShareService.buildWatermarkCaption(
        clipTitle: 'Key Revelation',
        videoTitle: 'The Truth About Everything',
        channelName: 'TruthSeeker',
        startSeconds: 10.0,
        endSeconds: 25.0,
        clipUrl: clipUrl,
      );

      expect(caption, contains('Key Revelation (00:10 - 00:25 (15s)) • TruthSeeker'));
      expect(caption, contains('▶️ Watch full video on Truthworld:'));
      expect(caption, contains(clipUrl));
    });
  });
}
