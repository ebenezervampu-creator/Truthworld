import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_video_grid.dart';
import 'package:truthworld/theme/device_state.dart';
import 'package:truthworld/theme/tw_breakpoints.dart';
import 'package:truthworld/theme/tw_layout_tokens.dart';

void main() {
  group('DeviceState Classification', () {
    test('Should classify as mobile when width < 600', () {
      final state = DeviceState.fromSize(599, 800, 1);
      expect(state.isMobile, isTrue);
      expect(state.type, DeviceType.mobile);
    });

    test('Should classify as tablet when 600 <= width < 1024', () {
      final state = DeviceState.fromSize(600, 800, 1);
      expect(state.isTablet, isTrue);
      expect(state.type, DeviceType.tablet);

      final state2 = DeviceState.fromSize(1023, 800, 1);
      expect(state2.isTablet, isTrue);
    });

    test('Should classify as desktop when 1024 <= width < 1440', () {
      final state = DeviceState.fromSize(1024, 800, 1);
      expect(state.isDesktop, isTrue);
    });

    test('Should classify as largeDesktop when 1440 <= width < 1920', () {
      final state = DeviceState.fromSize(1440, 800, 1);
      expect(state.isLargeDesktop, isTrue);
    });

    test('Should classify as ultraWide when width >= 1920', () {
      final state = DeviceState.fromSize(1920, 1080, 1);
      expect(state.isUltraWide, isTrue);
    });
  });

  group('TWLayoutTokens Derivation', () {
    test('Should provide mobile tokens with zero sidebar width', () {
      final device = DeviceState.fromSize(400, 800, 1);
      final tokens = TWLayoutTokens.fromDevice(device);
      expect(tokens.sidebarWidth, 0);
      expect(tokens.contentMaxWidth, double.infinity);
    });

    test('Should provide desktop tokens with 280 sidebar width', () {
      final device = DeviceState.fromSize(1200, 800, 1);
      final tokens = TWLayoutTokens.fromDevice(device);
      expect(tokens.sidebarWidth, 280);
      expect(tokens.contentMaxWidth, 1280);
    });

    test('Should scale layout tokens for ultraWide', () {
      final device = DeviceState.fromSize(2000, 1080, 1);
      final tokens = TWLayoutTokens.fromDevice(device);
      expect(tokens.sidebarWidth, 360);
      expect(tokens.contentMaxWidth, 1920);
    });
  });

  group('Responsive Grid Column Scaling', () {
    int calculateColumns({required double width, required bool isMobile, required bool isTablet}) {
      if (isMobile) return 1;
      if (isTablet) return 2;
      if (width >= 2200) return 5;
      if (width >= 1600) return 4;
      return 3;
    }

    test('Should return 1 column on mobile screens', () {
      expect(calculateColumns(width: 390, isMobile: true, isTablet: false), 1);
    });

    test('Should return 2 columns on tablet screens', () {
      expect(calculateColumns(width: 820, isMobile: false, isTablet: true), 2);
    });

    test('Should return 3 columns on standard desktop (1080p)', () {
      expect(calculateColumns(width: 1440, isMobile: false, isTablet: false), 3);
    });

    test('Should return 4 columns on large desktop (1440p+)', () {
      expect(calculateColumns(width: 1920, isMobile: false, isTablet: false), 4);
    });

    test('Should return 5 columns on ultrawide & 4K displays', () {
      expect(calculateColumns(width: 2560, isMobile: false, isTablet: false), 5);
      expect(calculateColumns(width: 3840, isMobile: false, isTablet: false), 5);
    });
  });

  group('Search Thumbnail Clamping', () {
    double calculateThumbWidth(double screenWidth) {
      final isWide = screenWidth >= 600;
      return isWide
          ? (screenWidth * 0.32).clamp(240.0, 360.0)
          : (screenWidth * 0.38).clamp(140.0, 200.0);
    }

    test('Should clamp mobile search thumbnails between 140 and 200', () {
      expect(calculateThumbWidth(320), 140.0);
      expect(calculateThumbWidth(390), closeTo(148.2, 0.1));
      expect(calculateThumbWidth(590), 200.0);
    });

    test('Should clamp desktop search thumbnails to maximum 360 to prevent ballooning', () {
      expect(calculateThumbWidth(1080), closeTo(345.6, 0.1));
      expect(calculateThumbWidth(1920), 360.0);
      expect(calculateThumbWidth(2560), 360.0);
      expect(calculateThumbWidth(3840), 360.0);
    });
  });

  group('Tablet Navigation & Landscape Overlay Guards', () {
    test('Should enforce mutually exclusive side navigation and bottom navigation on tablets', () {
      bool isSideNavVisible(double width) => width >= 1024 || (width >= 600 && width >= 850);
      bool isBottomNavVisible(double width) => !isSideNavVisible(width);

      // On 900px tablet, side nav is shown and bottom nav is hidden
      expect(isSideNavVisible(900), isTrue);
      expect(isBottomNavVisible(900), isFalse);

      // On 768px tablet, side nav is hidden and bottom nav is shown
      expect(isSideNavVisible(768), isFalse);
      expect(isBottomNavVisible(768), isTrue);
    });

    test('Should optimize fullscreen overlay padding for landscape phones', () {
      double overlayPadding(double playerHeight) => playerHeight < 500 ? 16.0 : 80.0;

      // Phone in landscape (height ~375)
      expect(overlayPadding(375), 16.0);

      // Desktop or tablet in landscape (height >= 500)
      expect(overlayPadding(800), 80.0);
    });
  });

  group('Miniplayer Layout Mode Decoupling (RESP-10)', () {
    test('Should identify width < 600 as mobile layout', () {
      expect(MiniplayerConfig.isMobileLayout(320), isTrue);
      expect(MiniplayerConfig.isMobileLayout(390), isTrue);
      expect(MiniplayerConfig.isMobileLayout(599), isTrue);
    });

    test('Should unlock tablet/desktop layout for iPads and Android tablets (>= 600px)', () {
      expect(MiniplayerConfig.isMobileLayout(600), isFalse);
      expect(MiniplayerConfig.isMobileLayout(768), isFalse);
      expect(MiniplayerConfig.isMobileLayout(834), isFalse);
      expect(MiniplayerConfig.isMobileLayout(1024), isFalse);
      expect(MiniplayerConfig.isMobileLayout(1280), isFalse);
    });
  });

  group('Topic Video Grid Responsive Configuration (RESP-13)', () {
    test('Should assign 1 column with 1.05 aspect ratio on compact mobile (<480px)', () {
      final config = TopicVideoGrid.calculateGridConfigForWidth(360);
      expect(config.crossAxisCount, 1);
      expect(config.childAspectRatio, 1.05);
    });

    test('Should assign 2 columns on normal mobile (480px–767px)', () {
      final config = TopicVideoGrid.calculateGridConfigForWidth(500);
      expect(config.crossAxisCount, 2);
      expect(config.childAspectRatio, 0.9);
    });

    test('Should assign 3 columns on tablets (768px–1023px)', () {
      final config = TopicVideoGrid.calculateGridConfigForWidth(768);
      expect(config.crossAxisCount, 3);
      expect(config.childAspectRatio, 0.95);
    });

    test('Should assign 4 columns on desktop (1024px–1599px)', () {
      final config = TopicVideoGrid.calculateGridConfigForWidth(1280);
      expect(config.crossAxisCount, 4);
      expect(config.childAspectRatio, 0.95);
    });

    test('Should assign 5 columns on ultrawide displays (>=1600px)', () {
      final config = TopicVideoGrid.calculateGridConfigForWidth(1920);
      expect(config.crossAxisCount, 5);
      expect(config.childAspectRatio, 0.95);

      final ultrawide = TopicVideoGrid.calculateGridConfigForWidth(2560);
      expect(ultrawide.crossAxisCount, 5);
    });
  });

  group('Discover Channel Responsive Scaling (RESP-15)', () {
    double getAvatarDiameter(double width) => width < 380 ? 56.0 : (width < 600 ? 68.0 : 80.0);
    double getAvatarGap(double width) => width < 380 ? 10.0 : 16.0;

    test('Should scale down avatar and gap on small phones (<=375px)', () {
      expect(getAvatarDiameter(320), 56.0);
      expect(getAvatarDiameter(360), 56.0);
      expect(getAvatarGap(360), 10.0);
    });

    test('Should provide intermediate avatar size on standard mobile (380–599px)', () {
      expect(getAvatarDiameter(390), 68.0);
      expect(getAvatarDiameter(428), 68.0);
      expect(getAvatarGap(390), 16.0);
    });

    test('Should use full 80px avatar on tablets and desktop (>=600px)', () {
      expect(getAvatarDiameter(768), 80.0);
      expect(getAvatarDiameter(1280), 80.0);
      expect(getAvatarGap(768), 16.0);
    });
  });

  group('Creator Studio Stats Grid Scaling', () {
    ({int cols, double ratio}) getStatsConfig(double width, double textScale, bool isDesktop) {
      final cols = (isDesktop && width >= 860) ? 4 : (width >= 480 ? 2 : 1);
      final baseRatio = cols == 4 ? 1.25 : (cols == 2 ? 1.5 : 2.4);
      final childAspectRatio = (baseRatio / textScale.clamp(1.0, 1.5)).clamp(0.85, 3.0);
      return (cols: cols, ratio: childAspectRatio);
    }

    test('Should provide 4 columns on desktop with width >= 860', () {
      final config = getStatsConfig(1024, 1.0, true);
      expect(config.cols, 4);
      expect(config.ratio, closeTo(1.25, 0.01));
    });

    test('Should adapt ratio dynamically under accessibility text scale (1.3x)', () {
      final config = getStatsConfig(1024, 1.3, true);
      expect(config.cols, 4);
      expect(config.ratio, closeTo(1.25 / 1.3, 0.01));
    });

    test('Should drop to 2 columns on tablet or smaller desktop window (< 860px)', () {
      final config = getStatsConfig(768, 1.0, false);
      expect(config.cols, 2);
      expect(config.ratio, closeTo(1.5, 0.01));
    });

    test('Should drop to 1 column on compact mobile (< 480px)', () {
      final config = getStatsConfig(360, 1.0, false);
      expect(config.cols, 1);
      expect(config.ratio, closeTo(2.4, 0.01));
    });
  });

  group('Admin Overview Tab Grid Scaling', () {
    ({int cols, double ratio}) getOverviewGridConfig(double width, double textScale) {
      final int cols;
      final double baseRatio;
      if (width >= 1200) {
        cols = 4;
        baseRatio = 1.45;
      } else if (width >= 800) {
        cols = 3;
        baseRatio = 1.45;
      } else if (width >= 500) {
        cols = 2;
        baseRatio = 1.5;
      } else {
        cols = 1;
        baseRatio = 2.4;
      }
      final childAspectRatio = (baseRatio / textScale.clamp(1.0, 1.5)).clamp(0.9, 2.6);
      return (cols: cols, ratio: childAspectRatio);
    }

    test('Should allocate 4 columns on screens >= 1200px', () {
      final config = getOverviewGridConfig(1440, 1.0);
      expect(config.cols, 4);
    });

    test('Should allocate 3 columns on tablet landscape / smaller desktop (800-1199px)', () {
      final config = getOverviewGridConfig(1024, 1.0);
      expect(config.cols, 3);
    });

    test('Should allocate 2 columns on portrait tablet (500-799px)', () {
      final config = getOverviewGridConfig(768, 1.0);
      expect(config.cols, 2);
    });

    test('Should allocate 1 column on mobile (< 500px)', () {
      final config = getOverviewGridConfig(390, 1.0);
      expect(config.cols, 1);
    });
  });

  group('Clip Card Thumbnail Scaling (RESP-20)', () {
    ({double width, double height}) getThumbSize(double screenWidth) {
      final isCompact = screenWidth < 360;
      return (
        width: isCompact ? 120.0 : 160.0,
        height: isCompact ? 68.0 : 90.0,
      );
    }

    test('Should scale thumbnail down to 120x68 on compact phones (<360px)', () {
      final size = getThumbSize(320);
      expect(size.width, 120.0);
      expect(size.height, 68.0);
    });

    test('Should use standard 160x90 thumbnail on standard phones (>=360px)', () {
      final size = getThumbSize(390);
      expect(size.width, 160.0);
      expect(size.height, 90.0);
    });
  });
}
