import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/change_video_dialog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesSelectedVideoCard extends StatelessWidget {
  const SubtitlesSelectedVideoCard({
    required this.video,
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final Video video;
  final SubtitlesController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    const primaryText = AppColors.textPrimary;
    const secondaryText = AppColors.textSecondary;
    const cardColor = AppColors.bgSurface;
    const borderColor = AppColors.bgDivider;

    final dateStr = DateFormat('MMM d, yyyy').format(video.createdAt.toDate());
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(video),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildMetadata(dateStr, primaryText, secondaryText),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildChangeVideoButton(context),
                ),
              ],
            )
          : Row(
              children: [
                _buildThumbnail(video),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildMetadata(dateStr, primaryText, secondaryText),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildChangeVideoButton(context),
              ],
            ),
    );
  }

  Widget _buildThumbnail(Video video) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: video.thumbnailUrl,
            width: 136,
            height: 76,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 136,
              height: 76,
              color: AppColors.bgSurfaceHover,
            ),
            errorWidget: (context, url, error) => Container(
              width: 136,
              height: 76,
              color: AppColors.bgSurfaceHover,
              child: const Icon(
                Icons.videocam_off_rounded,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bgPage.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              video.duration.isNotEmpty ? video.duration : '00:00',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata(String dateStr, Color primaryText, Color secondaryText) {
    final visibility = video.visibility.isNotEmpty
        ? video.visibility[0].toUpperCase() + video.visibility.substring(1)
        : 'Public';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Published',
            style: TextStyle(
              fontSize: 13,
              color: secondaryText,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
          ),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 13,
              color: secondaryText,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
          ),
          Icon(
            Icons.public_rounded,
            size: 13,
            color: secondaryText,
          ),
          const SizedBox(width: 4),
          Text(
            visibility,
            style: TextStyle(
              fontSize: 13,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeVideoButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => ChangeVideoDialog.show(
        context,
        controller: controller,
        isDarkMode: isDarkMode,
      ),
      icon: const Icon(
        Icons.edit_outlined,
        size: 15,
        color: AppColors.textPrimary,
      ),
      label: const Text(
        'Change video',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFF282828),
        side: const BorderSide(color: Color(0xFF3E3E3E)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
