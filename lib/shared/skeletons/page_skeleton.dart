import 'package:flutter/material.dart';

import 'package:truthworld/shared/skeletons/skeleton_base.dart';

/// A generic page skeleton used as a fallback loading state.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: SafeArea(
        child: SkeletonBase(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App-bar placeholder
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    SkeletonBox(height: 28, width: 28, borderRadius: 6),
                    SizedBox(width: 16),
                    SkeletonBox(height: 18, width: 140),
                    Spacer(),
                    SkeletonCircle(size: 32),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Content blocks
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContentBlockSkeleton(),
                      SizedBox(height: 24),
                      _ContentBlockSkeleton(),
                      SizedBox(height: 24),
                      _ContentBlockSkeleton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single content-block placeholder (title line + 3 body lines).
class _ContentBlockSkeleton extends StatelessWidget {
  const _ContentBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 16, width: 200),
        SizedBox(height: 12),
        SkeletonBox(height: 12, width: double.infinity),
        SizedBox(height: 8),
        SkeletonBox(height: 12, width: double.infinity),
        SizedBox(height: 8),
        SkeletonBox(height: 12, width: 260),
      ],
    );
  }
}
