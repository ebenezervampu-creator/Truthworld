import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class TranscriptSegmentTile extends StatelessWidget {
  final SubtitleSegment seg;
  final TowerPlayerController? playerCtrl;
  final String videoId;
  final int? segmentIndex;
  final VideoTranscriptController? transcriptCtrl;

  static final TextStyle _monoActive = GoogleFonts.robotoMono(
    color: AppColors.brand,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
  static final TextStyle _monoInactive = GoogleFonts.robotoMono(
    color: Colors.white70,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
  static final TextStyle _textActive = GoogleFonts.roboto(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static final TextStyle _textInactive = GoogleFonts.roboto(
    color: Colors.white70,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.3,
  );

  static final BoxDecoration _activeBox = BoxDecoration(
    color: AppColors.brand.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(4),
  );
  static final BoxDecoration _inactiveBox = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(4),
  );

  const TranscriptSegmentTile({
    required this.seg,
    required this.playerCtrl,
    required this.videoId,
    this.segmentIndex,
    this.transcriptCtrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isPlayerActive = playerCtrl?.activeSubtitleSegment.value == seg;
      final isIndexActive = transcriptCtrl != null &&
          segmentIndex != null &&
          transcriptCtrl!.activeSegmentIndex.value == segmentIndex;
      final isActive = isPlayerActive || isIndexActive;

      return InkWell(
        onTap: () {
          final activeCtrl = TowerPlayerController.getForTagOrActive(videoId);
          activeCtrl?.seekTo(seg.start);
          if (segmentIndex != null && transcriptCtrl != null) {
            transcriptCtrl!.activeSegmentIndex.value = segmentIndex!;
            transcriptCtrl!.resumeAutoScroll();
          }
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
                decoration: isActive ? _activeBox : _inactiveBox,
                child: Text(
                  FormatUtils.formatDuration(seg.start),
                  style: isActive ? _monoActive : _monoInactive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  seg.text,
                  style: isActive ? _textActive : _textInactive,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
