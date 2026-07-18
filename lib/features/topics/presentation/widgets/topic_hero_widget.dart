import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

/// Topic Hero Widget
///
/// Displays:
/// - Cover image (gradient fallback if no image)
/// - Topic title
/// - Description
/// - Category badge
/// - Video count
class TopicHeroWidget extends StatelessWidget {
  final Topic? topic;
  final bool isDesktop;
  final bool isTablet;

  const TopicHeroWidget({
    super.key,
    this.topic,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    if (topic == null) {
      return _buildSkeleton();
    }

    final height = isDesktop ? 500.0 : (isTablet ? 400.0 : 320.0);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image or gradient
          _buildBackground(),

          // Dark gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bgPage.withValues(alpha: 0.3),
                  AppColors.bgPage.withValues(alpha: 0.9),
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
                vertical: isDesktop ? 48 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category badge
                  _buildCategoryBadge(),
                  SizedBox(height: isDesktop ? 16 : 12),

                  // Title
                  Text(
                    topic!.title,
                    style: GoogleFonts.roboto(
                      fontSize: isDesktop ? 48 : (isTablet ? 36 : 28),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isDesktop ? 16 : 12),

                  // Description
                  Text(
                    topic!.description,
                    style: GoogleFonts.roboto(
                      fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    maxLines: isDesktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isDesktop ? 24 : 16),

                  // Stats row
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final bgUrl =
        (topic?.coverImage != null && topic!.coverImage!.isNotEmpty)
        ? topic!.coverImage
        : (topic?.thumbnailUrl != null && topic!.thumbnailUrl!.isNotEmpty)
        ? topic!.thumbnailUrl
        : null;

    if (bgUrl != null) {
      return Image.network(
        bgUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildGradientBackground();
        },
      );
    }
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brand.withValues(alpha: 0.3),
            AppColors.brand.withValues(alpha: 0.15),
            AppColors.bgPage,
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        topic!.category.toUpperCase(),
        style: GoogleFonts.roboto(
          fontSize: isDesktop ? 12 : 11,
          fontWeight: FontWeight.w500,
          color: AppColors.brand,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final followingController = Get.put(FollowingTopicsController());
    return Obx(() {
      final isFollowed = followingController.isTopicFollowed(topic!.id);
      return Row(
        children: [
          Icon(
            Icons.videocam_rounded,
            color: AppColors.textSecondary,
            size: isDesktop ? 20 : 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${topic!.videoCount} videos',
            style: GoogleFonts.roboto(
              fontSize: isDesktop ? 16 : 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 24),
          Icon(
            Icons.people_rounded,
            color: AppColors.textSecondary,
            size: isDesktop ? 20 : 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${topic!.followerCount} followers',
            style: GoogleFonts.roboto(
              fontSize: isDesktop ? 16 : 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => followingController.toggleFollowTopic(topic!),
            icon: Icon(
              isFollowed ? Icons.check : Icons.add,
              size: 16,
              color: isFollowed ? AppColors.textPrimary : Colors.black,
            ),
            label: Text(
              isFollowed ? 'Following' : 'Follow',
              style: TextStyle(
                color: isFollowed ? AppColors.textPrimary : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowed ? Colors.white12 : AppColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSkeleton() {
    final height = isDesktop ? 500.0 : (isTablet ? 400.0 : 320.0);

    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceHover,
      highlightColor: Colors.white12,
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }
}





