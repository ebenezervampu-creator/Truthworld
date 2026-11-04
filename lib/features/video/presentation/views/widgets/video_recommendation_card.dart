import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Video recommendation card matching the Homepage video card design exactly:
/// - 16:9 thumbnail with rounded top corners (16px), duration badge, verified badge, progress bar, hover preview.
/// - Elevated dark surface container (0xFF0F0F11) with rounded corners (16px) and subtle drop shadow.
/// - Channel circular avatar, bold 2-line title, metadata (Channel • Views • Time ago), and 3-dots action menu (`Icons.more_vert`).
class RecommendationVideoCard extends StatelessWidget {
  const RecommendationVideoCard({
    required this.video,
    super.key,
    this.heroPrefix = 'rec_video',
    this.onTap,
    this.disableHoverPreview,
  });

  final Video video;
  final String heroPrefix;
  final VoidCallback? onTap;
  final bool? disableHoverPreview;

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return VideoCard(
      key: ValueKey('rec_${heroPrefix}_${video.id}'),
      video: video,
      isGrid: true,
      heroPrefix: heroPrefix,
      onTap: onTap,
      disableHoverPreview: disableHoverPreview ?? isMobile,
    );
  }

  /// Strips redundant leading zeroes on single-digit minutes (e.g. "07:37" -> "7:37").
  static String formatDurationBadge(String rawDuration) {
    var dur = rawDuration.trim();
    if (dur.isEmpty) return '';
    if (dur.length == 5 && dur.startsWith('0') && dur[1] != '0' && dur[1] != ':') {
      dur = dur.substring(1);
    }
    return dur;
  }
}
