import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class TranscriptSegmentTile extends StatelessWidget {
  final SubtitleSegment seg;
  final TowerPlayerController? playerCtrl;
  final String videoId;

  const TranscriptSegmentTile({
    required this.seg,
    required this.playerCtrl,
    required this.videoId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = playerCtrl?.activeSubtitleSegment.value == seg;
      return InkWell(
        onTap: () {
          final activeCtrl = TowerPlayerController.getForTagOrActive(videoId);
          activeCtrl?.seekTo(seg.start);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.brand.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  FormatUtils.formatDuration(seg.start),
                  style: GoogleFonts.robotoMono(
                    color: isActive
                        ? AppColors.brand
                        : Colors.white70,
                    fontSize: 12,
                    fontWeight: isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  seg.text,
                  style: GoogleFonts.roboto(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
