import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Base shimmer effect wrapper that animates child bone containers.
class ShimmerBase extends StatelessWidget {
  const ShimmerBase({
    required this.child,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? AppColors.bgSurfaceHover,
      highlightColor: highlightColor ?? AppColors.bgDivider,
      child: child,
    );
  }
}

/// Standard skeleton bone primitive shape with configurable width, height, and border radius.
Widget shimmerBone({
  double? width,
  double height = 14,
  double radius = 4,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
