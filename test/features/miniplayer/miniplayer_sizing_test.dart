import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';

void main() {
  group('Miniplayer Sizing & Layout Tests', () {
    test('MiniplayerConfig constants correctly reflect mobile layout', () {
      expect(MiniplayerConfig.mobileWidthFraction, equals(0.50));
      expect(MiniplayerConfig.videoAspectRatio, equals(16.0 / 9.0));
      expect(MiniplayerConfig.mobileDockInset, equals(12.0));
      expect(MiniplayerConfig.mobileDockBottomInset, equals(70.0));
      expect(MiniplayerConfig.minMobileWidth, equals(160.0));
      expect(MiniplayerConfig.maxMobileWidth, equals(240.0));
      expect(MiniplayerConfig.defaultWidth, equals(400.0));
    });

    test('isMobileLayout identifies mobile viewport widths', () {
      expect(MiniplayerConfig.isMobileLayout(360.0), isTrue);
      expect(MiniplayerConfig.isMobileLayout(390.0), isTrue);
      expect(MiniplayerConfig.isMobileLayout(412.0), isTrue);
      expect(MiniplayerConfig.isMobileLayout(599.0), isTrue);
    });

    test('widthForScreen returns 50% screen width on mobile viewports', () {
      // 360 * 0.50 = 180.0
      expect(MiniplayerConfig.widthForScreen(360.0), equals(180.0));
      // 390 * 0.50 = 195.0
      expect(MiniplayerConfig.widthForScreen(390.0), equals(195.0));
      // 412 * 0.50 = 206.0
      expect(MiniplayerConfig.widthForScreen(412.0), equals(206.0));
      // Clamp testing
      expect(MiniplayerConfig.widthForScreen(200.0), equals(160.0)); // clamped to min 160
      expect(MiniplayerConfig.widthForScreen(550.0), equals(240.0)); // clamped to max 240
    });

    test('widthForScreen handles edge cases gracefully', () {
      expect(MiniplayerConfig.widthForScreen(0), equals(MiniplayerConfig.defaultWidth));
      expect(MiniplayerConfig.widthForScreen(-100), equals(MiniplayerConfig.defaultWidth));
    });

    test('heightForWidth returns pure 16:9 on mobile without info bar', () {
      const width = 180.0;
      const expectedMobileHeight = width / (16.0 / 9.0);
      expect(
        MiniplayerConfig.heightForWidth(width, isMobile: true),
        equals(expectedMobileHeight),
      );
    });

    test('heightForWidth includes infoBarHeight on desktop', () {
      const width = 400.0;
      const expectedDesktopHeight = width / (16.0 / 9.0) + MiniplayerConfig.infoBarHeight;
      expect(
        MiniplayerConfig.heightForWidth(width),
        equals(expectedDesktopHeight),
      );
    });

    test('MiniplayerController calculates mobile docking offset correctly', () {
      Get.testMode = true;
      Get.put<ConnectivityService>(ConnectivityService());
      final controller = Get.put(MiniplayerController(), tag: 'test_miniplayer');
      addTearDown(() {
        Get.delete<MiniplayerController>(tag: 'test_miniplayer');
        Get.delete<ConnectivityService>();
      });

      const mobileScreenSize = Size(390.0, 844.0);
      const cardSize = Size(195.0, 110.0);

      // On mobile, card is docked at bottom-right with mobileDockInset and mobileDockBottomInset
      final offset = controller.effectiveOffset(cardSize, mobileScreenSize);
      expect(offset.dx, equals(390.0 - 195.0 - MiniplayerConfig.mobileDockInset));
      expect(offset.dy, equals(844.0 - 110.0 - MiniplayerConfig.mobileDockBottomInset));
    });
  });
}
