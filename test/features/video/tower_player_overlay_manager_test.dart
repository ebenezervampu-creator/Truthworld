import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_overlay_manager.dart';

void main() {
  group('TowerPlayerOverlayManager State Invariant Tests', () {
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

    test('Initial state is none and hasBlockingOverlay is false', () {
      expect(manager.current, equals(TowerPlayerOverlay.none));
      expect(manager.isNone, isTrue);
      expect(manager.hasBlockingOverlay, isFalse);
      expect(manager.isTruthReportOpen, isFalse);
      expect(manager.isSettingsOpen, isFalse);
    });

    test('Opening an overlay sets it active and notifies callback', () {
      manager.open(TowerPlayerOverlay.truthReport);

      expect(manager.current, equals(TowerPlayerOverlay.truthReport));
      expect(manager.hasBlockingOverlay, isTrue);
      expect(manager.isTruthReportOpen, isTrue);
      expect(lastNotifiedOverlay, equals(TowerPlayerOverlay.truthReport));
    });

    test('Only ONE overlay can be active at a time (mutually exclusive invariant)', () {
      // 1. Open Truth Report
      manager.open(TowerPlayerOverlay.truthReport);
      expect(manager.current, equals(TowerPlayerOverlay.truthReport));
      expect(manager.isTruthReportOpen, isTrue);
      expect(manager.isSettingsOpen, isFalse);

      // 2. Open Settings -> Truth Report is automatically closed
      manager.open(TowerPlayerOverlay.settings);
      expect(manager.current, equals(TowerPlayerOverlay.settings));
      expect(manager.isSettingsOpen, isTrue);
      expect(manager.isTruthReportOpen, isFalse);
      expect(manager.hasBlockingOverlay, isTrue);

      // 3. Open Live Chat -> Settings is closed
      manager.open(TowerPlayerOverlay.liveChat);
      expect(manager.current, equals(TowerPlayerOverlay.liveChat));
      expect(manager.isLiveChatOpen, isTrue);
      expect(manager.isSettingsOpen, isFalse);
    });

    test('Closing active overlay returns to none and unblocks player', () {
      manager.open(TowerPlayerOverlay.factCheck);
      expect(manager.hasBlockingOverlay, isTrue);

      manager.close();
      expect(manager.current, equals(TowerPlayerOverlay.none));
      expect(manager.isNone, isTrue);
      expect(manager.hasBlockingOverlay, isFalse);
      expect(lastNotifiedOverlay, equals(TowerPlayerOverlay.none));
    });

    test('Toggle closes when already active and opens when inactive', () {
      manager.toggle(TowerPlayerOverlay.settings);
      expect(manager.isSettingsOpen, isTrue);

      manager.toggle(TowerPlayerOverlay.settings);
      expect(manager.isSettingsOpen, isFalse);
      expect(manager.isNone, isTrue);
    });
  });
}
