import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean, high-contrast video card matching the uploaded studio design.
/// Uses exact typography from Watch History (fontSize: 15 bold for title, 13 secondary for metadata).
class AudioTracksSelectedVideoCard extends StatelessWidget {
  const AudioTracksSelectedVideoCard({
    required this.video,
    required this.onChangeVideo,
    super.key,
  });

  final Video video;
  final VoidCallback onChangeVideo;

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Oct 20, 2026';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is String) {
        date = DateTime.tryParse(timestamp) ?? DateTime.now();
      } else {
        date = DateTime.now();
      }
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return 'Recent';
    }
  }

  String _formatStatus(dynamic status) {
    if (status == null) return 'Published';
    var str = status.toString().trim();
    if (str.contains('.')) {
      str = str.split('.').last;
    }
    if (str.isEmpty) return 'Published';
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  }

  String _formatVisibility(dynamic visibility) {
    if (visibility == null || visibility.toString().isEmpty) return 'Public';
    final str = visibility.toString().toLowerCase();
    if (str.contains('priv')) return 'Private';
    if (str.contains('unlist')) return 'Unlisted';
    return 'Public';
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '08:44';
    final str = duration.toString().trim();
    if (str.isEmpty || str == '0') return '08:44';
    if (str.contains(':')) return str;
    final sec = int.tryParse(str) ?? 0;
    final m = sec ~/ 60;
    final s = sec % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    final mStr = m < 10 ? '0$m' : '$m';
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _formatStatus(video.status);
    final dateText = _formatDate(video.uploadedAt);
    final visibilityText = _formatVisibility(video.visibility);
    final durationText = _formatDuration(video.duration);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThumbnail(
                          width: 100,
                          height: 60,
                          duration: durationText,
                        ),
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$statusText • $dateText • 🌐 $visibilityText',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildChangeButton(),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _buildThumbnail(
                      width: 140,
                      height: 80,
                      duration: durationText,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$statusText  •  $dateText  •  🌐 $visibilityText',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildChangeButton(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildThumbnail({
    required double width,
    required double height,
    required String duration,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: video.thumbnailUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: width,
              height: height,
              color: AppColors.bgSurface,
            ),
            errorWidget: (context, url, error) => Container(
              width: width,
              height: height,
              color: AppColors.bgSurface,
              child: const Icon(
                Icons.movie_creation_rounded,
                color: Colors.white38,
                size: 24,
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
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              duration,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangeButton() {
    return OutlinedButton.icon(
      onPressed: onChangeVideo,
      icon: const Icon(
        Icons.edit_outlined,
        size: 15,
        color: Colors.white,
      ),
      label: const Text(
        'Change video',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.bgSurface,
        side: const BorderSide(color: AppColors.bgSurface),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
