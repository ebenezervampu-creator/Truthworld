import 'package:flutter/material.dart';
import 'package:truthworld/shared/skeletons/skeleton_base.dart';

class VideoListSkeleton extends StatelessWidget {
  const VideoListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonBase(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            SkeletonBox(width: 160, height: 90, borderRadius: 8),
            SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 16, width: double.infinity),
                  SizedBox(height: 8),
                  SkeletonBox(height: 14, width: 200),
                  SizedBox(height: 12),
                  SkeletonBox(height: 12, width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
