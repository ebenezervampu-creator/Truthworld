import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTube-Style Fullscreen Horizontal Zoom & Pan Controls', () {
    late VideoPlayerController vpc;
    late TowerPlayerController ctrl;

    setUp(() {
      vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      ctrl = TowerPlayerController(videoPlayerController: vpc);
      ctrl.aspectRatio.value = 16 / 9; // standard 16:9 video
    });

    tearDown(() {
      ctrl.onClose();
    });

    test('calculateFillScale expands horizontally to fill wide display (pillarbox)', () {
      // Modern phone screen: 2400 x 1080 (aspect ratio ~2.222 > 16/9 = 1.777)
      const viewport = Size(2400, 1080);
      final fillScale = ctrl.calculateFillScale(viewport);

      // fillScale should equal viewportAspect / videoAspect = (2400/1080) / (16/9) = 1.25
      expect(fillScale, closeTo(1.25, 0.01));
    });

    test('calculateFillScale expands vertically to fill tall/box display (letterbox)', () {
      // 4:3 screen: 1600 x 1200 (aspect ratio 1.333 < 16/9 = 1.777)
      const viewport = Size(1600, 1200);
      final fillScale = ctrl.calculateFillScale(viewport);

      // fillScale should equal videoAspect / viewportAspect = (16/9) / (1600/1200) = 1.333
      expect(fillScale, closeTo(1.333, 0.01));
    });

    test('clampPanOffset keeps video strictly framed within viewport boundaries without black voids', () {
      const viewport = Size(2400, 1080);
      // At fill scale (1.25x), video width is 1080 * (16/9) * 1.25 = 2400px (fills screen width)
      // video height is 1080 * 1.25 = 1350px (exceeds viewport height by 270px)
      // maxDy is (1350 - 1080) / 2 = 135px, maxDx is 0px
      final clampedPan = ctrl.clampPanOffset(const Offset(100, 200), 1.25, viewport);
      expect(clampedPan.dx, 0.0); // No horizontal panning needed since width exactly matches
      expect(clampedPan.dy, 135.0); // Clamped to max vertical overflow

      // At 2.0x magnification:
      // fitWidth = 1920, scaledWidth = 3840 => maxDx = (3840 - 2400)/2 = 720
      // fitHeight = 1080, scaledHeight = 2160 => maxDy = (2160 - 1080)/2 = 540
      final pan2x = ctrl.clampPanOffset(const Offset(1000, -800), 2.0, viewport);
      expect(pan2x.dx, 720.0);
      expect(pan2x.dy, -540.0);

      // Negative overflow clamping
      final pan2xNeg = ctrl.clampPanOffset(const Offset(-900, 700), 2.0, viewport);
      expect(pan2xNeg.dx, -720.0);
      expect(pan2xNeg.dy, 540.0);
    });

    test('clampPanOffset returns Offset.zero when zoom scale is 1.0 (Fit)', () {
      const viewport = Size(2400, 1080);
      final clamped = ctrl.clampPanOffset(const Offset(50, 50), 1.0, viewport);
      expect(clamped, Offset.zero);
    });

    test('isZoomedIn is true when scale > 1.02 or isZoomToFill is true', () {
      expect(ctrl.isZoomedIn, isFalse);

      ctrl.setZoomScale(1.0, fill: true);
      expect(ctrl.isZoomedIn, isTrue);

      ctrl.resetZoom();
      expect(ctrl.isZoomedIn, isFalse);

      ctrl.setZoomScale(2.0);
      expect(ctrl.isZoomedIn, isTrue);
    });

    test('resetZoom completely restores scale and pan offset to standard Fit (1.0x)', () {
      const viewport = Size(2400, 1080);
      ctrl.setZoomScale(2.5, viewportSize: viewport);
      ctrl.zoomPanOffset.value = const Offset(150, 100);

      expect(ctrl.zoomScale.value, 2.5);
      expect(ctrl.zoomPanOffset.value, const Offset(150, 100));

      ctrl.resetZoom();
      expect(ctrl.zoomScale.value, 1.0);
      expect(ctrl.isZoomToFill.value, isFalse);
      expect(ctrl.zoomPanOffset.value, Offset.zero);
    });

    test('Exiting fullscreen automatically invokes resetZoom', () async {
      ctrl.isFullScreen.value = true;
      ctrl.setZoomScale(2.0);
      ctrl.zoomPanOffset.value = const Offset(100, 50);

      await ctrl.toggleFullscreen();
      expect(ctrl.isFullScreen.value, isFalse);
      expect(ctrl.zoomScale.value, 1.0);
      expect(ctrl.zoomPanOffset.value, Offset.zero);
    });
  });
}
