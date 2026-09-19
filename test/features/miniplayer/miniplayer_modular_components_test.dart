import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  late MiniplayerController controller;

  setUp(() {
    controller = MiniplayerController();
  });

  tearDown(() {
    controller.onClose();
  });

  group('MiniplayerStateBase Tests', () {
    test('initial state is properly configured', () {
      expect(controller.mode.value, MiniplayerMode.dismissed);
      expect(controller.error.value, isEmpty);
      expect(controller.isPlaying.value, isFalse);
      expect(controller.isVideoReady.value, isFalse);
      expect(controller.dragProgress.value, 0.0);
      expect(controller.isVisible, isFalse);
      expect(controller.isHealthy, isTrue);
    });

    test('formatDuration formats mm:ss and hh:mm:ss correctly', () {
      expect(controller.formatDuration(Duration.zero), '00:00');
      expect(
        controller.formatDuration(const Duration(minutes: 5, seconds: 32)),
        '05:32',
      );
      expect(
        controller.formatDuration(
          const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        '01:23:45',
      );
    });

    test('isIgnorablePlaybackError detects benign browser errors', () {
      expect(controller.isIgnorablePlaybackError(null), isTrue);
      expect(controller.isIgnorablePlaybackError(''), isTrue);
      expect(controller.isIgnorablePlaybackError('User gesture required'), isTrue);
      expect(controller.isIgnorablePlaybackError('The play() request was interrupted'), isTrue);
      expect(controller.isIgnorablePlaybackError('MEDIA_ERR_ABORTED'), isTrue);
      expect(controller.isIgnorablePlaybackError('Fatal hardware crash'), isFalse);
    });

    test('clearError resets error string', () {
      controller.error.value = 'Something went wrong';
      expect(controller.error.value, 'Something went wrong');
      controller.clearError();
      expect(controller.error.value, isEmpty);
    });
  });

  group('MiniplayerGesturesMixin Tests', () {
    test('expand and collapse transition modes and dragProgress', () {
      controller.expand();
      expect(controller.mode.value, MiniplayerMode.expanded);
      expect(controller.dragProgress.value, 1.0);

      controller.collapse();
      expect(controller.mode.value, MiniplayerMode.collapsed);
      expect(controller.dragProgress.value, 0.0);
    });

    test('onDragUpdate modifies dragProgress within 0.0 and 1.0 range', () {
      controller.mode.value = MiniplayerMode.collapsed;
      controller.onDragUpdate(-100, 1000); // dragged up by 100 on 1000px screen = +0.1
      expect(controller.dragProgress.value, closeTo(0.1, 0.001));
      expect(controller.mode.value, MiniplayerMode.dragging);
    });

    test('effectiveOffset defaults to bottom-right dock when not dragged', () {
      const cardSize = Size(200, 100);
      const screenSize = Size(1000, 800);
      final offset = controller.effectiveOffset(cardSize, screenSize);
      final expected = controller.defaultDockOffset(cardSize, screenSize);
      expect(offset, equals(expected));
    });

    test('onPanCard updates and clamps dragOffset within viewport bounds', () {
      controller.mode.value = MiniplayerMode.collapsed;
      const cardSize = Size(200, 100);
      const screenSize = Size(1000, 800);
      controller.onPanCard(const Offset(-50, -50), cardSize, screenSize);
      expect(controller.dragOffset.value, isNotNull);
      final current = controller.dragOffset.value!;
      expect(current.dx, greaterThanOrEqualTo(0.0));
      expect(current.dy, greaterThanOrEqualTo(0.0));
    });

    test('setHovering toggles isHovering state', () {
      expect(controller.isHovering.value, isFalse);
      controller.setHovering(true);
      expect(controller.isHovering.value, isTrue);
      controller.setHovering(false);
      expect(controller.isHovering.value, isFalse);
    });
  });

  group('MiniplayerSubtitlesMixin Tests', () {
    test('toggleSubtitles flips state and clears cues on disable', () {
      controller.subtitlesEnabled.value = true;
      controller.currentSubtitle.value = 'Active subtitle';
      controller.toggleSubtitles();
      expect(controller.subtitlesEnabled.value, isFalse);
      expect(controller.currentSubtitle.value, isEmpty);
      expect(controller.subtitleSegments, isEmpty);
    });

    test('findSubtitle identifies active cue based on timestamp', () {
      const seg1 = SubtitleSegment(
        start: Duration.zero,
        end: Duration(seconds: 5),
        text: 'Hello world',
      );
      const seg2 = SubtitleSegment(
        start: Duration(seconds: 6),
        end: Duration(seconds: 10),
        text: 'Second line',
      );
      controller.subtitleSegments.assignAll([seg1, seg2]);

      final found1 = controller.findSubtitle(const Duration(seconds: 2));
      expect(found1?.text, 'Hello world');

      final found2 = controller.findSubtitle(const Duration(seconds: 8));
      expect(found2?.text, 'Second line');
    });
  });

  group('MiniplayerPlaybackMixin Tests', () {
    test('toggleMobileControls flips visibility', () {
      expect(controller.showMobileControls.value, isFalse);
      controller.toggleMobileControls();
      expect(controller.showMobileControls.value, isTrue);
      controller.toggleMobileControls();
      expect(controller.showMobileControls.value, isFalse);
    });

    test('dismiss resets all player state', () {
      controller.mode.value = MiniplayerMode.expanded;
      controller.error.value = 'An error';
      controller.isPlaying.value = true;
      controller.isVideoReady.value = true;

      controller.dismiss();

      expect(controller.mode.value, MiniplayerMode.dismissed);
      expect(controller.error.value, isEmpty);
      expect(controller.isPlaying.value, isFalse);
      expect(controller.isVideoReady.value, isFalse);
      expect(controller.currentPosition.value, Duration.zero);
      expect(controller.totalDuration.value, Duration.zero);
      expect(controller.dragProgress.value, 0.0);
      expect(controller.dragOffset.value, isNull);
    });
  });
}
