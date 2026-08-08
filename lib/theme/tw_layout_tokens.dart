import 'package:flutter/material.dart';
import 'package:truthworld/theme/device_state.dart';

class TWLayoutTokens extends ThemeExtension<TWLayoutTokens> {
  const TWLayoutTokens({
    required this.sidebarWidth,
    required this.compactSidebarWidth,
    required this.navigationRailWidth,
    required this.contentMaxWidth,
    required this.dialogMaxWidth,
    required this.sheetMaxWidth,
    required this.bottomSheetMaxWidth,
    required this.videoPlayerMaxWidth,
    required this.feedMaxWidth,
    required this.analyticsPanelWidth,
  });

  factory TWLayoutTokens.fromDevice(DeviceState device) {
    if (device.isMobile) {
      return const TWLayoutTokens(
        sidebarWidth: 0,
        compactSidebarWidth: 0,
        navigationRailWidth: 0,
        contentMaxWidth: double.infinity,
        dialogMaxWidth: 320,
        sheetMaxWidth: double.infinity,
        bottomSheetMaxWidth: double.infinity,
        videoPlayerMaxWidth: double.infinity,
        feedMaxWidth: double.infinity,
        analyticsPanelWidth: double.infinity,
      );
    } else if (device.isTablet) {
      return const TWLayoutTokens(
        sidebarWidth: 240,
        compactSidebarWidth: 80,
        navigationRailWidth: 72,
        contentMaxWidth: 1000,
        dialogMaxWidth: 480,
        sheetMaxWidth: 400,
        bottomSheetMaxWidth: 600,
        videoPlayerMaxWidth: 800,
        feedMaxWidth: 700,
        analyticsPanelWidth: 300,
      );
    } else if (device.isDesktop) {
      return const TWLayoutTokens(
        sidebarWidth: 280,
        compactSidebarWidth: 80,
        navigationRailWidth: 88,
        contentMaxWidth: 1280,
        dialogMaxWidth: 600,
        sheetMaxWidth: 480,
        bottomSheetMaxWidth: 800,
        videoPlayerMaxWidth: 1000,
        feedMaxWidth: 900,
        analyticsPanelWidth: 400,
      );
    } else if (device.isLargeDesktop) {
      return const TWLayoutTokens(
        sidebarWidth: 320,
        compactSidebarWidth: 80,
        navigationRailWidth: 96,
        contentMaxWidth: 1440,
        dialogMaxWidth: 800,
        sheetMaxWidth: 560,
        bottomSheetMaxWidth: 1000,
        videoPlayerMaxWidth: 1200,
        feedMaxWidth: 1100,
        analyticsPanelWidth: 500,
      );
    } else {
      // Ultra-wide
      return const TWLayoutTokens(
        sidebarWidth: 360,
        compactSidebarWidth: 80,
        navigationRailWidth: 104,
        contentMaxWidth: 1920,
        dialogMaxWidth: 1000,
        sheetMaxWidth: 640,
        bottomSheetMaxWidth: 1200,
        videoPlayerMaxWidth: 1440,
        feedMaxWidth: 1440,
        analyticsPanelWidth: 600,
      );
    }
  }
  final double sidebarWidth;
  final double compactSidebarWidth;
  final double navigationRailWidth;
  final double contentMaxWidth;
  final double dialogMaxWidth;
  final double sheetMaxWidth;
  final double bottomSheetMaxWidth;
  final double videoPlayerMaxWidth;
  final double feedMaxWidth;
  final double analyticsPanelWidth;

  @override
  TWLayoutTokens copyWith({
    double? sidebarWidth,
    double? compactSidebarWidth,
    double? navigationRailWidth,
    double? contentMaxWidth,
    double? dialogMaxWidth,
    double? sheetMaxWidth,
    double? bottomSheetMaxWidth,
    double? videoPlayerMaxWidth,
    double? feedMaxWidth,
    double? analyticsPanelWidth,
  }) {
    return TWLayoutTokens(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      compactSidebarWidth: compactSidebarWidth ?? this.compactSidebarWidth,
      navigationRailWidth: navigationRailWidth ?? this.navigationRailWidth,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth,
      sheetMaxWidth: sheetMaxWidth ?? this.sheetMaxWidth,
      bottomSheetMaxWidth: bottomSheetMaxWidth ?? this.bottomSheetMaxWidth,
      videoPlayerMaxWidth: videoPlayerMaxWidth ?? this.videoPlayerMaxWidth,
      feedMaxWidth: feedMaxWidth ?? this.feedMaxWidth,
      analyticsPanelWidth: analyticsPanelWidth ?? this.analyticsPanelWidth,
    );
  }

  @override
  TWLayoutTokens lerp(ThemeExtension<TWLayoutTokens>? other, double t) {
    if (other is! TWLayoutTokens) return this;
    return TWLayoutTokens(
      sidebarWidth: _lerp(sidebarWidth, other.sidebarWidth, t),
      compactSidebarWidth: _lerp(
        compactSidebarWidth,
        other.compactSidebarWidth,
        t,
      ),
      navigationRailWidth: _lerp(
        navigationRailWidth,
        other.navigationRailWidth,
        t,
      ),
      contentMaxWidth: _lerp(contentMaxWidth, other.contentMaxWidth, t),
      dialogMaxWidth: _lerp(dialogMaxWidth, other.dialogMaxWidth, t),
      sheetMaxWidth: _lerp(sheetMaxWidth, other.sheetMaxWidth, t),
      bottomSheetMaxWidth: _lerp(
        bottomSheetMaxWidth,
        other.bottomSheetMaxWidth,
        t,
      ),
      videoPlayerMaxWidth: _lerp(
        videoPlayerMaxWidth,
        other.videoPlayerMaxWidth,
        t,
      ),
      feedMaxWidth: _lerp(feedMaxWidth, other.feedMaxWidth, t),
      analyticsPanelWidth: _lerp(
        analyticsPanelWidth,
        other.analyticsPanelWidth,
        t,
      ),
    );
  }

  double _lerp(double a, double b, double t) {
    if (a == b) return a;
    if (a.isInfinite || b.isInfinite) return t < 0.5 ? a : b;
    return a + (b - a) * t;
  }
}

extension TWLayoutTokensExtension on BuildContext {
  TWLayoutTokens get layoutTokens =>
      Theme.of(this).extension<TWLayoutTokens>()!;
}
