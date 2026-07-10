import 'package:flutter/material.dart';

enum DeviceType { mobile, tablet, desktop }

class Responsive {
  static DeviceType getDeviceType(double width) {
    if (width < 600) return DeviceType.mobile;
    if (width < 1024) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static bool isMobile(dynamic value) {
    if (value is BuildContext) return MediaQuery.of(value).size.width < 600;
    if (value is double) return value < 600;
    return false;
  }

  static bool isTablet(dynamic value) {
    if (value is BuildContext) {
      final w = MediaQuery.of(value).size.width;
      return w >= 600 && w < 1024;
    }
    if (value is double) return value >= 600 && value < 1024;
    return false;
  }
  
  static bool isDesktop(dynamic value) {
    if (value is BuildContext) return MediaQuery.of(value).size.width >= 1024;
    if (value is double) return value >= 1024;
    return false;
  }

  static bool isMobileSmall(dynamic value) {
    if (value is BuildContext) return MediaQuery.of(value).size.width < 360;
    if (value is double) return value < 360;
    return false;
  }

  static int getGridColumns(double width, {int maxColumns = 4}) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return maxColumns;
  }
}

typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context, DeviceType deviceType);

class ResponsiveBuilder extends StatelessWidget {
  final ResponsiveWidgetBuilder builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, Responsive.getDeviceType(constraints.maxWidth));
      },
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool centerContent;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget current = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (maxWidth != null || centerContent) {
      current = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? 1440),
          child: current,
        ),
      );
    }

    return current;
  }
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobileSmall => screenWidth < 360;
  bool get isMobile => screenWidth < 600;
  bool get isTabletSmall => screenWidth >= 600 && screenWidth < 768;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  DeviceType get deviceType => Responsive.getDeviceType(screenWidth);

  double get layoutSpacing => isMobile ? 12.0 : 16.0;
  EdgeInsets get contentPadding => EdgeInsets.all(layoutSpacing);
  EdgeInsets get cardPadding => EdgeInsets.all(isMobile ? 12.0 : 16.0);
  double get fontScale => (screenWidth / 1440.0).clamp(0.8, 1.2);
  
  bool get showSideNav => isDesktop || (isTablet && screenWidth > 800);
}

