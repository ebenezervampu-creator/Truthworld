import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_control_row.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/progress_bar.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    required this.ctrl,
    required this.isNarrow,
    required this.isMedium,
    super.key,
  });
  final TowerPlayerController ctrl;
  final bool isNarrow;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0, 0.08, 0.6, 1],
          colors: [
            AppColors.bgPage,
            AppColors.bgPage.withValues(alpha: 0.96),
            AppColors.bgPage.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ControlRow(ctrl: ctrl, isNarrow: isNarrow, isMedium: isMedium),
          const SizedBox(height: 6),
          ProgressBar(ctrl: ctrl),
        ],
      ),
    );
  }
}
