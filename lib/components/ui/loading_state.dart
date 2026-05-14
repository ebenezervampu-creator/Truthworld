import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

enum LoadingSize { small, medium, large }

/// LoadingState: Consistent loading indicator across the platform
///
/// Provides:
/// - Multiple size variants
/// - Custom color support
/// - Semantic accessibility labels
class LoadingState extends StatelessWidget {
  final LoadingSize size;
  final Color? color;
  final String? semanticLabel;
  final double? customSize;

  const LoadingState({
    super.key,
    this.size = LoadingSize.medium,
    this.color,
    this.semanticLabel,
    this.customSize,
  });

  double _getSize() {
    return customSize ??
        switch (size) {
          LoadingSize.small => AppTheme.sizes.iconMd,
          LoadingSize.medium => 40.0,
          LoadingSize.large => 56.0,
        };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Loading',
      button: false,
      enabled: false,
      child: Center(
        child: SizedBox(
          width: _getSize(),
          height: _getSize(),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(
              color ?? AppTheme.colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// SkeletonLoader: Animated placeholder for content loading
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.borderRadius ?? AppTheme.radius.md,
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _shimmerController.value - 0.1,
                _shimmerController.value,
                _shimmerController.value + 0.1,
              ],
              colors: [
                AppTheme.colors.surface,
                AppTheme.colors.surface.withValues(alpha: 0.5),
                AppTheme.colors.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}





