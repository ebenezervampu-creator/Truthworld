import 'package:truthworld/theme/tw_breakpoints.dart';

class DeviceState {

  const DeviceState({
    required this.width,
    required this.height,
    required this.type,
    required this.fontScale,
  });

  factory DeviceState.fromSize(double width, double height, double fontScale) {
    DeviceType type;
    if (width < TWBreakpoints.tablet) {
      type = DeviceType.mobile;
    } else if (width < TWBreakpoints.desktop) {
      type = DeviceType.tablet;
    } else if (width < TWBreakpoints.largeDesktop) {
      type = DeviceType.desktop;
    } else if (width < TWBreakpoints.ultraWide) {
      type = DeviceType.largeDesktop;
    } else {
      type = DeviceType.ultraWide;
    }

    return DeviceState(
      width: width,
      height: height,
      type: type,
      fontScale: fontScale,
    );
  }
  final double width;
  final double height;
  final DeviceType type;
  final double fontScale;

  bool get isMobile => type == DeviceType.mobile;
  bool get isTablet => type == DeviceType.tablet;
  bool get isDesktop => type == DeviceType.desktop;
  bool get isLargeDesktop => type == DeviceType.largeDesktop;
  bool get isUltraWide => type == DeviceType.ultraWide;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceState &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          type == other.type &&
          fontScale == other.fontScale;

  @override
  int get hashCode =>
      width.hashCode ^ height.hashCode ^ type.hashCode ^ fontScale.hashCode;
}
