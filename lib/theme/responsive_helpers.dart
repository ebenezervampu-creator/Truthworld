import 'package:flutter/material.dart';
import 'tw_breakpoints.dart';
import 'device_state.dart';
import 'tw_layout_tokens.dart';
import 'tw_typography.dart';

export 'tw_breakpoints.dart';
export 'device_state.dart';
export 'tw_layout_tokens.dart';

class Responsive {
  static DeviceState getDevice(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return DeviceState.fromSize(size.width, size.height, getFontScale(size.width));
  }

  static double getFontScale(double width) {
    return (width / 1440.0).clamp(0.8, 1.2);
  }

  static int getGridColumns(double width, {int maxColumns = 4}) {
    if (width < TWBreakpoints.tablet) return 1;
    if (width < TWBreakpoints.desktop) return 2;
    if (width < TWBreakpoints.largeDesktop) return 3;
    return maxColumns;
  }

  static bool isMobile(double width) => width < TWBreakpoints.tablet;
  static bool isTablet(double width) => width >= TWBreakpoints.tablet && width < TWBreakpoints.desktop;
  static bool isDesktop(double width) => width >= TWBreakpoints.desktop;
  static bool isMobileSmall(double width) => width < 360;
}

typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context, DeviceState device);

class ResponsiveBuilder extends StatelessWidget {
  final ResponsiveWidgetBuilder builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final device = DeviceState.fromSize(
          constraints.maxWidth,
          constraints.maxHeight,
          Responsive.getFontScale(constraints.maxWidth),
        );
        return builder(context, device);
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
    final effectiveMaxWidth = maxWidth ?? context.layoutTokens.contentMaxWidth;

    Widget current = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (effectiveMaxWidth < double.infinity || centerContent) {
      current = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: current,
        ),
      );
    }

    return current;
  }
}

extension ResponsiveContext on BuildContext {
  DeviceState get device => Responsive.getDevice(this);

  bool get isMobile => device.isMobile;
  bool get isTablet => device.isTablet;
  bool get isDesktop => device.isDesktop;
  bool get isLargeDesktop => device.isLargeDesktop;
  bool get isUltraWide => device.isUltraWide;
  bool get isMobileSmall => device.width < 360;
  bool get isTabletSmall => device.width >= 600 && device.width < 900;

  double get screenWidth => device.width;
  double get screenHeight => device.height;
  double get fontScale => device.fontScale;

  double get layoutSpacing => isMobile ? 12.0 : 16.0;
  EdgeInsets get contentPadding => EdgeInsets.all(layoutSpacing);
  EdgeInsets get cardPadding => EdgeInsets.all(isMobile ? 12.0 : 16.0);

  bool get showSideNav => isDesktop || isLargeDesktop || isUltraWide;
}

extension TWTypographyExtension on BuildContext {
  TWTypography get typography {
    final base = Theme.of(this).extension<TWTypography>()!;
    return base.scale(device.fontScale);
  }
}

extension TWTypographyScale on TWTypography {
  TWTypography scale(double factor) {
    return copyWith(
      logo: logo.copyWith(fontSize: logo.fontSize! * factor),
      hero: hero.copyWith(fontSize: hero.fontSize! * factor),
      display: display.copyWith(fontSize: display.fontSize! * factor),
      headline: headline.copyWith(fontSize: headline.fontSize! * factor),
      title: title.copyWith(fontSize: title.fontSize! * factor),
      body: body.copyWith(fontSize: body.fontSize! * factor),
      bodySmall: bodySmall.copyWith(fontSize: bodySmall.fontSize! * factor),
      label: label.copyWith(fontSize: label.fontSize! * factor),
      caption: caption.copyWith(fontSize: caption.fontSize! * factor),
      button: button.copyWith(fontSize: button.fontSize! * factor),
      overline: overline.copyWith(fontSize: overline.fontSize! * factor),
    ) as TWTypography;
  }
}
