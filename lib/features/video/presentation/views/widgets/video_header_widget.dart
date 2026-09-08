import 'package:flutter/material.dart';
import 'package:truthworld/features/analytics/presentation/widgets/live_viewer_widget.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular video header widget displaying title, view count, and channel info.
class VideoHeaderWidget extends StatelessWidget {
  const VideoHeaderWidget({
    required this.video,
    super.key,
    this.onChannelTap,
  });

  final Video video;
  final VoidCallback? onChannelTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video.title,
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${video.views} views',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Text(
              video.category,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            LiveViewerWidget(
              videoId: video.id,
              isCompact: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onChannelTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.bgSurfaceHover,
                  child: Text(
                    video.channelName.isNotEmpty ? video.channelName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.channelName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'Subscribers',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _buildJoinButton(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    if (video.channelId.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ChannelMembershipJoinSheet.show(
            context,
            channelId: video.channelId,
          ),
          borderRadius: BorderRadius.circular(17),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Join',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
