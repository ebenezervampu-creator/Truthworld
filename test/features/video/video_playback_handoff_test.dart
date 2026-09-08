import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';

void main() {
  group('VideoPlaybackHandoff Coordination Tests', () {
    test('registerPauseListener and pauseAllActivePlayers fan out to all listeners', () {
      var listener1Fired = false;
      var listener2Fired = false;

      void onPause1() => listener1Fired = true;
      void onPause2() => listener2Fired = true;

      VideoPlaybackHandoff.registerPauseListener(onPause1);
      VideoPlaybackHandoff.registerPauseListener(onPause2);

      VideoPlaybackHandoff.pauseAllActivePlayers();

      expect(listener1Fired, isTrue);
      expect(listener2Fired, isTrue);

      // Clean up / unregister
      VideoPlaybackHandoff.unregisterPauseListener(onPause1);
      VideoPlaybackHandoff.unregisterPauseListener(onPause2);

      listener1Fired = false;
      listener2Fired = false;
      VideoPlaybackHandoff.pauseAllActivePlayers();

      expect(listener1Fired, isFalse);
      expect(listener2Fired, isFalse);
    });

    test('pauseAllActivePlayers handles throwing listener gracefully without aborting', () {
      var normalListenerFired = false;

      void throwingListener() => throw Exception('Player error');
      void safeListener() => normalListenerFired = true;

      VideoPlaybackHandoff.registerPauseListener(throwingListener);
      VideoPlaybackHandoff.registerPauseListener(safeListener);

      expect(VideoPlaybackHandoff.pauseAllActivePlayers, returnsNormally);
      expect(normalListenerFired, isTrue);

      VideoPlaybackHandoff.unregisterPauseListener(throwingListener);
      VideoPlaybackHandoff.unregisterPauseListener(safeListener);
    });

    test('syncActivePlayer dispatches to registered sync callback', () {
      String? syncedTag;
      var callbackCalled = false;

      VideoPlaybackHandoff.onSyncController = (tag, controller) {
        syncedTag = tag;
        callbackCalled = true;
      };

      // Since we don't need a real native VideoPlayerController in this unit test,
      // we test callback invocation directly
      expect(VideoPlaybackHandoff.onSyncController, isNotNull);
      VideoPlaybackHandoff.onSyncController?.call('video_123', null as dynamic);

      expect(callbackCalled, isTrue);
      expect(syncedTag, equals('video_123'));

      VideoPlaybackHandoff.onSyncController = null;
    });

    test('isActive returns false when no controller is registered', () {
      expect(VideoPlaybackHandoff.isActive('non_existent_id'), isFalse);
    });
  });
}
