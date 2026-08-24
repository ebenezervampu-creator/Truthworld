import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';

void main() {
  group('VideoPlaybackHandoff Tests', () {
    test('handoff registry initializes and handles nulls gracefully', () {
      expect(VideoPlaybackHandoff.isActive('non-existent-id'), isFalse);
      expect(VideoPlaybackHandoff.retrieveController('non-existent-id'), isNull);
    });
  });
}
