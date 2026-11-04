import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class DownloadsStorageSection extends StatelessWidget {
  const DownloadsStorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Downloads & Smart Storage',
      children: [
        _buildSmartDownloadsTile(context),
        _buildDownloadQualityTile(context),
        _buildDownloadWifiOnlyTile(context),
        _buildStorageLimitTile(context),
        _buildDownloadLocationTile(context),
        _buildClearCacheTile(context),
      ],
    );
  }

  Widget _buildSmartDownloadsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(Icons.auto_awesome, color: AppColors.textPrimary),
        title: const Text(
          'Smart Downloads',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Automatically download 5-10 recommended videos on Wi-Fi',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.downloads.value.smartDownloadsEnabled,
        onChanged: ctrl.toggleSmartDownloads,
      ),
    );
  }

  Widget _buildDownloadQualityTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.file_download_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Download Quality',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Quality: ${ctrl.downloads.value.downloadQuality}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showDownloadQualitySettingDialog(context),
      ),
    );
  }

  void _showDownloadQualitySettingDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    final options = [
      'Ask each time',
      'High (1080p)',
      'Medium (720p)',
      'Low (480p)',
      'Audio only',
    ];
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Default Download Quality',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (q) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      q,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: q,
                    groupValue: ctrl.downloads.value.downloadQuality,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setDownloadQuality(val);
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

  Widget _buildDownloadWifiOnlyTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.wifi_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Download over Wi-Fi only',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Prevent video downloads on cellular data connections',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.downloads.value.wifiOnly,
        onChanged: (val) =>
            ctrl.updateDownloads(ctrl.downloads.value.copyWith(wifiOnly: val)),
      ),
    );
  }

  Widget _buildStorageLimitTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.sd_storage_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Download Storage Limit',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Cap: ${ctrl.downloads.value.maxStorageLimit}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showStorageLimitDialog(context),
      ),
    );
  }

  void _showStorageLimitDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Max Storage Limit',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['500MB', '1GB', '2GB', '5GB', '10GB', '20GB', 'Unlimited']
              .map(
                (cap) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      cap,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: cap,
                    groupValue: ctrl.downloads.value.maxStorageLimit,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setMaxStorageLimit(val);
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

  Widget _buildDownloadLocationTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.folder_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Download Storage Location',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Location: ${ctrl.downloads.value.downloadLocation}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showDownloadLocationDialog(context),
      ),
    );
  }

  void _showDownloadLocationDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Download Storage Location',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Automatic', 'Internal Storage', 'SD Card']
              .map(
                (loc) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      loc,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: loc,
                    groupValue: ctrl.downloads.value.downloadLocation,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setDownloadLocation(val);
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

  Widget _buildClearCacheTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.cleaning_services_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Clear Cached Media Data',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Current cache: ${ctrl.cacheSizeMB.value.toStringAsFixed(1)} MB',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: TextButton(
          onPressed: () => _confirmClearCache(context, ctrl),
          child: const Text('Clear', style: TextStyle(color: AppColors.error)),
        ),
        onTap: () => _confirmClearCache(context, ctrl),
      ),
    );
  }

  void _confirmClearCache(BuildContext context, UserSettingsController ctrl) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Clear Cached Media Data?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will clear ${ctrl.cacheSizeMB.value.toStringAsFixed(1)} MB of temporary media cache. Offline downloads will not be removed.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await ctrl.clearCache();
              AppSnackbar.success('Cache cleared successfully.');
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ================= 5. NOTIFICATIONS TILES =================


}
