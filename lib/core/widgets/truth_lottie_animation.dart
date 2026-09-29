import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Standardized, high-performance Lottie animation widget for TruthWorld.
/// Strictly enforces the YouTube-style monochrome motion design aesthetic (Black & White).
class TruthLottieAnimation extends StatelessWidget {
  const TruthLottieAnimation({
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.animate = true,
    this.fallbackIcon,
    super.key,
  });

  /// Monochromatic concentric radar scanning pulse for AI fact-checking passes.
  factory TruthLottieAnimation.aiScanning({
    double? size,
    double? width,
    double? height,
    bool repeat = true,
    Key? key,
  }) {
    return TruthLottieAnimation(
      key: key,
      assetPath: 'assets/lottie/ai_scanning.json',
      width: size ?? width ?? 40,
      height: size ?? height ?? 40,
      repeat: repeat,
      fallbackIcon: Icons.radar,
    );
  }

  /// High-contrast verified shield entrance and pulse animation.
  factory TruthLottieAnimation.verifiedShield({
    double? size,
    double? width,
    double? height,
    bool repeat = true,
    Key? key,
  }) {
    return TruthLottieAnimation(
      key: key,
      assetPath: 'assets/lottie/verified_shield.json',
      width: size ?? width ?? 32,
      height: size ?? height ?? 32,
      repeat: repeat,
      fallbackIcon: Icons.verified_user_outlined,
    );
  }

  /// Sleek 3-bar equalizer pulse loader.
  factory TruthLottieAnimation.loader({
    double? size,
    double? width,
    double? height,
    Key? key,
  }) {
    return TruthLottieAnimation(
      key: key,
      assetPath: 'assets/lottie/analyzing_loader.json',
      width: size ?? width ?? 36,
      height: size ?? height ?? 36,
      fallbackIcon: Icons.more_horiz,
    );
  }

  /// Minimalist magnifying glass radar search for empty claims state.
  factory TruthLottieAnimation.emptyClaims({
    double? size,
    double? width,
    double? height,
    Key? key,
  }) {
    return TruthLottieAnimation(
      key: key,
      assetPath: 'assets/lottie/empty_claims.json',
      width: size ?? width ?? 72,
      height: size ?? height ?? 72,
      fallbackIcon: Icons.manage_search_outlined,
    );
  }

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;
  final bool animate;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      repeat: repeat,
      animate: animate,
      errorBuilder: (context, error, stackTrace) {
        // Fallback for environments where asset bundles are mocked or unavailable
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Icon(
              fallbackIcon ?? Icons.motion_photos_on_outlined,
              size: (width != null && height != null)
                  ? (width! < height! ? width! * 0.7 : height! * 0.7)
                  : 24,
              color: Colors.white70,
            ),
          ),
        );
      },
    );
  }
}
