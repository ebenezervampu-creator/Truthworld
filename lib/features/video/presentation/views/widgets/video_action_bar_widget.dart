import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular action bar widget for video player (like, share, download, save).
class VideoActionBarWidget extends StatelessWidget {
  const VideoActionBarWidget({
    required this.likeCount,
    required this.isLiked,
    super.key,
    this.onLike,
    this.onShare,
    this.onDownload,
    this.onSave,
  });

  final int likeCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionButton(
            icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
            label: '$likeCount',
            onTap: onLike,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: onShare,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.download_outlined,
            label: 'Download',
            onTap: onDownload,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.playlist_add_rounded,
            label: 'Save',
            onTap: onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceHover,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
