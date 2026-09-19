import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategoryVideoGridShimmer extends StatelessWidget {
  const CategoryVideoGridShimmer({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.isMobile = false,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isDesktop ? 1.1 : (isTablet ? 1.0 : 0.78);

    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.3),
      highlightColor: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.1),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 16,
                width: double.infinity,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 4),
              Container(
                height: 14,
                width: 100,
                color: AppColors.textPrimary,
              ),
            ],
          );
        },
      ),
    );
  }
}

class CategoryVideoListShimmer extends StatelessWidget {
  const CategoryVideoListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.3),
      highlightColor: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.1),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            height: 100,
          );
        },
      ),
    );
  }
}

class CategoryHorizontalShimmer extends StatelessWidget {
  const CategoryHorizontalShimmer({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.3),
      highlightColor: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.1),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: isDesktop ? 280 : (isTablet ? 240 : 200),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}

class CategoryErrorWidget extends StatelessWidget {
  const CategoryErrorWidget({
    required this.message,
    super.key,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryEmptyWidget extends StatelessWidget {
  const CategoryEmptyWidget({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 36,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                'No content found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
