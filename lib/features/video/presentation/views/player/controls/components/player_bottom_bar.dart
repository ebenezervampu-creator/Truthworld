import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_control_row.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/truthworld_player_timeline.dart';

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
          stops: const [0.0, 0.35, 0.75, 1.0],
          colors: [
            Colors.black,
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TruthWorldPlayerTimeline(ctrl: ctrl),
          const SizedBox(height: 2),
          ControlRow(ctrl: ctrl, isNarrow: isNarrow, isMedium: isMedium),
        ],
      ),
    );
  }
}
