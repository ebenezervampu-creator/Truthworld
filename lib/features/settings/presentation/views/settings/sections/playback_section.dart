import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlaybackSection extends StatelessWidget {
  const PlaybackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Playback & Media Preferences',
      children: [
        _buildVideoQualityTile(context),
        _buildVolumeNormalizationTile(context),
        _buildBackgroundPlaybackTile(context),
        _buildAutoplayNextTile(context),
        _buildSeekDurationTile(context),
        _buildStatsForNerdsTile(context),
      ],
    );
  }

  Widget _buildVideoQualityTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(Icons.high_quality, color: AppColors.textPrimary),
        title: const Text(
          'Video Quality Preferences',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Wi-Fi: ${ctrl.playback.value.wifiQuality} • Mobile: ${ctrl.playback.value.cellularQuality}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showVideoQualityDialog(context),
      ),
    );
  }

  void _showVideoQualityDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Video Quality Preferences',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ON WI-FI',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...['Auto', '1080p (HD)', '720p (HD)', '480p (SD)'].map(
                (q) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      q,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    value: q,
                    groupValue: ctrl.playback.value.wifiQuality,
                    onChanged: (val) {
                      if (val != null) ctrl.setWifiQuality(val);
                    },
                  ),
                ),
              ),
              const Divider(color: AppColors.bgDivider),
              const SizedBox(height: 8),
              const Text(
                'ON MOBILE NETWORKS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...[
                'Auto',
                'Data Saver (480p)',
                'Low (360p)',
                'Higher Image Quality (1080p)',
              ].map(
                (q) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      q,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    value: q,
                    groupValue: ctrl.playback.value.cellularQuality,
                    onChanged: (val) {
                      if (val != null) ctrl.setCellularQuality(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Done',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeNormalizationTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(Icons.graphic_eq, color: AppColors.textPrimary),
        title: const Text(
          'Volume Normalization (Stable Volume)',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Mode: ${ctrl.playback.value.volumeNormalizationMode}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showVolumeNormalizationDialog(context),
      ),
    );
  }

  void _showVolumeNormalizationDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Stable Volume Normalization',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Off', 'Light', 'Standard', 'Aggressive']
              .map(
                (mode) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      mode,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: mode,
                    groupValue: ctrl.playback.value.volumeNormalizationMode,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setVolumeNormalization(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPlaybackTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    final isSupported = ctrl.isBackgroundPlaybackSupported;
    return Obx(() {
      final playbackMode = ctrl.playback.value.backgroundPlaybackMode;
      return ListTile(
        leading: Icon(
          Icons.picture_in_picture_alt,
          color: isSupported ? AppColors.textPrimary : Colors.grey,
        ),
        title: const Text(
          'Background Audio Playback',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          isSupported
              ? 'Mode: $playbackMode'
              : 'Unsupported on Web browser',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        enabled: isSupported,
        onTap: () => _showBackgroundPlaybackDialog(context),
      );
    });
  }

  void _showBackgroundPlaybackDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Background Audio Playback',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Off', 'Always On', 'Headphones Only']
              .map(
                (mode) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      mode,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: mode,
                    groupValue: ctrl.playback.value.backgroundPlaybackMode,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setBackgroundPlayback(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoplayNextTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.play_circle_fill_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Autoplay Next Video',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Automatically play recommended videos when current video finishes',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.playback.value.autoplayNext,
        onChanged: ctrl.toggleAutoplayNext,
      ),
    );
  }

  Widget _buildSeekDurationTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.fast_forward_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Double-Tap Seek Duration',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Seek step: ${ctrl.playback.value.seekDurationSeconds} seconds',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showSeekDurationDialog(context),
      ),
    );
  }

  void _showSeekDurationDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Seek Duration',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 30]
              .map(
                (sec) => Obx(
                  () => RadioListTile<int>(
                    title: Text(
                      '$sec seconds',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: sec,
                    groupValue: ctrl.playback.value.seekDurationSeconds,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setSeekDuration(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsForNerdsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.developer_mode,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Stats for Nerds Overlay',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Show bitrate, dropped frames, codec & resolution info on player',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.playback.value.statsForNerdsEnabled,
        onChanged: ctrl.toggleStatsForNerds,
      ),
    );
  }

  // ================= 4. SMART DOWNLOADS & STORAGE TILES =================


}
