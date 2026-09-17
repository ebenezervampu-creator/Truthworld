import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Video aspect ratio zoom and scale panel.
class ZoomPanel extends StatelessWidget {
  const ZoomPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  static const List<double> _scales = [1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 8.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Zoom',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        const PlayerDivider(),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  final isFill = ctrl.isZoomToFill.value;
                  return SelectTile(
                    label: 'Fill screen (Crop)',
                    selected: isFill,
                    onTap: () {
                      ctrl.setZoomScale(1.0, fill: true);
                      ctrl.closeSettings();
                    },
                  );
                }),
                for (final s in _scales)
                  Obx(() {
                    final isSel =
                        !ctrl.isZoomToFill.value && ctrl.zoomScale.value == s;
                    final label = s == 1.0
                        ? 'Fit to screen (1.0x)'
                        : '${s % 1 == 0 ? s.toInt() : s}x';
                    return SelectTile(
                      label: label,
                      selected: isSel,
                      onTap: () {
                        ctrl.setZoomScale(s);
                        ctrl.closeSettings();
                      },
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Playback speed selection panel (0.25x - 2.0x).
class SpeedPanel extends StatelessWidget {
  const SpeedPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Playback Speed',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        const PlayerDivider(),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._speeds.map(
                  (s) => Obx(
                    () => SelectTile(
                      label: s == 1.0 ? 'Normal' : '$s×',
                      selected: ctrl.playbackSpeed.value == s,
                      onTap: () => ctrl.setSpeed(s),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sleep timer duration configuration panel.
class SleepTimerPanel extends StatelessWidget {
  const SleepTimerPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final options = [
      ('Off', const Duration()),
      (
        'End of video',
        Duration(
          seconds: (ctrl.activePlayback.duration - ctrl.activePlayback.position)
              .inSeconds,
        ),
      ),
      ('10 minutes', const Duration(minutes: 10)),
      ('15 minutes', const Duration(minutes: 15)),
      ('20 minutes', const Duration(minutes: 20)),
      ('30 minutes', const Duration(minutes: 30)),
      ('45 minutes', const Duration(minutes: 45)),
      ('60 minutes', const Duration(minutes: 60)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Sleep timer',
          onBack: () => ctrl.activePanel.value = 'more',
          onClose: null,
        ),
        const PlayerDivider(),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Obx(() {
              final isActive = ctrl.isSleepTimerActive.value;
              final isAtEnd = ctrl.isSleepTimerAtEndOfVideo.value;
              final rem = ctrl.sleepTimerRemainingSeconds.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive && !isAtEnd)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time remaining: ${rem ~/ 60}:${(rem % 60).toString().padLeft(2, '0')}',
                            style: TS.bodySm.copyWith(color: AppColors.brand),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              side: const BorderSide(color: AppColors.brand),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            onPressed: () => ctrl.extendSleepTimer(
                              const Duration(minutes: 5),
                            ),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text(
                              '+5 min',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...options.map((opt) {
                    final label = opt.$1;
                    final duration = opt.$2;

                    var isSelected = false;
                    if (label == 'Off') {
                      isSelected = !isActive;
                    } else if (isActive) {
                      if (label == 'End of video') {
                        isSelected = isAtEnd;
                      } else if (!isAtEnd) {
                        final diff =
                            (ctrl.sleepTimerRemainingSeconds.value -
                                    duration.inSeconds)
                                .abs();
                        isSelected = diff < 15;
                      }
                    }

                    return SelectTile(
                      label: label,
                      selected: isSelected,
                      onTap: () {
                        if (label == 'Off') {
                          ctrl.cancelSleepTimer();
                        } else {
                          ctrl.setSleepTimer(
                            duration,
                            isEndOfVideo: label == 'End of video',
                          );
                        }
                        ctrl.activePanel.value = 'more';
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
