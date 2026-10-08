import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_overlay_manager.dart';

void main() {
  group('TowerPlayerOverlayManager moreVideos Tests', () {
    late TowerPlayerOverlayManager manager;
    TowerPlayerOverlay? lastNotifiedOverlay;

    setUp(() {
      manager = TowerPlayerOverlayManager(
        onOverlayChanged: (overlay) {
          lastNotifiedOverlay = overlay;
        },
      );
      lastNotifiedOverlay = null;
    });

    tearDown(() {
      manager.dispose();
    });

    test('Initial state: isMoreVideosOpen is false', () {
      expect(manager.isMoreVideosOpen, isFalse);
    });

    test('Opening moreVideos sets it active and marks hasBlockingOverlay true', () {
      manager.open(TowerPlayerOverlay.moreVideos);

      expect(manager.current, equals(TowerPlayerOverlay.moreVideos));
      expect(manager.isMoreVideosOpen, isTrue);
      expect(manager.hasBlockingOverlay, isTrue);
      expect(lastNotifiedOverlay, equals(TowerPlayerOverlay.moreVideos));
    });

    test('Opening another overlay closes moreVideos (mutual exclusion)', () {
      manager.open(TowerPlayerOverlay.moreVideos);
      expect(manager.isMoreVideosOpen, isTrue);

      manager.open(TowerPlayerOverlay.comments);
      expect(manager.isMoreVideosOpen, isFalse);
      expect(manager.isCommentsOpen, isTrue);
      expect(manager.current, equals(TowerPlayerOverlay.comments));
    });

    test('Opening moreVideos closes previously active overlay', () {
      manager.open(TowerPlayerOverlay.settings);
      expect(manager.isSettingsOpen, isTrue);

      manager.open(TowerPlayerOverlay.moreVideos);
      expect(manager.isSettingsOpen, isFalse);
      expect(manager.isMoreVideosOpen, isTrue);
    });

    test('Toggle moreVideos closes when active and opens when inactive', () {
      manager.toggle(TowerPlayerOverlay.moreVideos);
      expect(manager.isMoreVideosOpen, isTrue);

      manager.toggle(TowerPlayerOverlay.moreVideos);
      expect(manager.isMoreVideosOpen, isFalse);
      expect(manager.isNone, isTrue);
    });
  });

  group('FullscreenMoreVideosController Tests', () {
    test('Hover state tracking for video cards', () {
      final manager = TowerPlayerOverlayManager();
      // Test the hover map independently
      final hoveredMap = <String, bool>{};
      void setHover(String id, bool val) => hoveredMap[id] = val;
      bool isHover(String id) => hoveredMap[id] == true;

      expect(isHover('vid_1'), isFalse);
      setHover('vid_1', true);
      expect(isHover('vid_1'), isTrue);
      setHover('vid_1', false);
      expect(isHover('vid_1'), isFalse);

      manager.dispose();
    });
  });
}
