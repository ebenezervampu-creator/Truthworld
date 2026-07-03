import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Wraps [child] in a shimmer animation using the app's dark-theme palette.
class SkeletonBase extends StatelessWidget {
  final Widget child;

  const SkeletonBase({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A2E),
      highlightColor: const Color(0xFF2A2A4E),
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

/// A rectangular placeholder box used inside [SkeletonBase].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular placeholder (avatars, profile pictures).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
