import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Renders adaptive resolution transcoding variant status chips.
class PipelineResolutionChips extends StatelessWidget {
  const PipelineResolutionChips({
    required this.variants,
    super.key,
  });

  final Map<String, dynamic> variants;

  @override
  Widget build(BuildContext context) {
    const standard = ['1080p', '720p', '480p', '360p', '240p', '144p'];
    final dynamicKeys = variants.keys.where((k) => !standard.contains(k)).toList();
    dynamicKeys.sort((a, b) {
      final hA = DownloadResolutionManager.inferHeightFromLabel(a);
      final hB = DownloadResolutionManager.inferHeightFromLabel(b);
      final cmp = hB.compareTo(hA);
      if (cmp != 0) return cmp;
      final fpsA = VideoResolutionV2.inferFpsFromLabel(a);
      final fpsB = VideoResolutionV2.inferFpsFromLabel(b);
      return fpsB.compareTo(fpsA);
    });

    final resolutions = [...dynamicKeys, ...standard];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: resolutions.map((res) {
        return _buildResolutionChip(res, variants[res]);
      }).toList(),
    );
  }

  Widget _buildResolutionChip(String label, dynamic variantData) {
    final status = (variantData is Map)
        ? (variantData['status'] as String? ?? 'pending')
        : 'pending';

    Color chipColor;
    IconData icon;

    switch (status) {
      case 'completed':
        chipColor = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
      case 'processing':
        chipColor = AppColors.brand;
        icon = Icons.sync_rounded;
      case 'failed':
        chipColor = AppColors.error;
        icon = Icons.error_outline_rounded;
      case 'pending':
      default:
        chipColor = AppColors.textTertiary;
        icon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
