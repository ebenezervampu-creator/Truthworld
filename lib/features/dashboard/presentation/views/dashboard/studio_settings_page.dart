import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class StudioSettingsPage extends StatelessWidget {
  const StudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<StudioSettingsController>()
        ? Get.find<StudioSettingsController>()
        : Get.put(StudioSettingsController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Obx(
        () => controller.isLoadingData.value
            ? const Center(child: CircularProgressIndicator())
            : (controller.userData.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No user data available',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please sign in to access settings',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionHeader('Channel'),
                        _buildChannelInfo(controller),
                        const Divider(color: Color(0xFF333333), height: 32),
                        _buildSectionHeader('Notifications'),
                        _buildNotificationSettings(controller),
                        const Divider(color: Color(0xFF333333), height: 32),
                        _buildSectionHeader('Monetization'),
                        _buildMonetizationSettings(controller),
                        const Divider(color: Color(0xFF333333), height: 32),
                        _buildSectionHeader('Privacy'),
                        _buildPrivacySettings(controller),
                        const Divider(color: Color(0xFF333333), height: 32),
                        _buildSectionHeader('Advanced'),
                        _buildAdvancedSettings(controller),
                        const Divider(color: Color(0xFF333333), height: 32),
                        _buildSectionHeader('Danger Zone', color: AppColors.error),
                        _buildDangerZoneSettings(context, controller),
                      ],
                    )),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color color = AppColors.textPrimary}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ===== CHANNEL SECTION =====
  Widget _buildChannelInfo(StudioSettingsController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          'Channel name',
          controller.userData['displayName'] ?? '',
          (value) => controller.updateField('displayName', value),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Handle',
          controller.userData['channelHandle'] ?? '',
          (value) => controller.updateField('channelHandle', value),
          prefix: '@',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Email',
          controller.userData['email'] ?? '',
          null, // read-only
          readOnly: true,
        ),
      ],
    );
  }

  // ===== NOTIFICATIONS SECTION =====
  Widget _buildNotificationSettings(StudioSettingsController controller) {
    final notif = controller.userData['notificationSettings'] as Map? ?? {};
    return Column(
      children: [
        _buildToggleListTile(
          'Email me about new comments',
          notif['emailComments'] ?? true,
          (value) => controller.updateNestedField(
            'notificationSettings',
            'emailComments',
            value,
          ),
        ),
        _buildToggleListTile(
          'Push notification for new subscribers',
          notif['pushNewSubscriber'] ?? true,
          (value) => controller.updateNestedField(
            'notificationSettings',
            'pushNewSubscriber',
            value,
          ),
        ),
        _buildToggleListTile(
          'Email for copyright claims',
          notif['emailCopyright'] ?? true,
          (value) => controller.updateNestedField(
            'notificationSettings',
            'emailCopyright',
            value,
          ),
        ),
        _buildToggleListTile(
          'Weekly performance digest email',
          notif['digestWeekly'] ?? false,
          (value) => controller.updateNestedField(
            'notificationSettings',
            'digestWeekly',
            value,
          ),
        ),
      ],
    );
  }

  // ===== MONETIZATION SECTION =====
  Widget _buildMonetizationSettings(StudioSettingsController controller) {
    final isMonetizationEnabled =
        controller.userData['monetizationEnabled'] ?? false;
    final noAdsForMembers =
        (controller.userData['noAdsForMembers'] as bool?) ?? false;

    return Column(
      children: [
        _buildToggleListTile(
          'Enable monetization',
          isMonetizationEnabled,
          (value) => controller.updateField('monetizationEnabled', value),
        ),
        _buildToggleListTile(
          'Channel Premium for members (30% platform cut)',
          noAdsForMembers,
          (value) => controller.toggleNoAdsForMembers(value),
          subtitle: noAdsForMembers
              ? 'Active: Members watch your videos ad-free in 4K Ultra HD. Platform fee: 30% on memberships.'
              : 'Inactive: Standard ads and resolution ceilings apply. 0% platform commission on memberships.',
        ),
        if (isMonetizationEnabled) ...[
          const SizedBox(height: 8),
          ListTile(
            title: const Text(
              'AdSense ID',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            subtitle: Text(
              controller.userData['adSenseId'] ?? 'Not linked',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            trailing: OutlinedButton(
              onPressed: () {
                // Open AdSense linking flow
              },
              child: const Text('Link'),
            ),
          ),
        ],
      ],
    );
  }

  // ===== PRIVACY SECTION =====
  Widget _buildPrivacySettings(StudioSettingsController controller) {
    return Column(
      children: [
        _buildToggleListTile(
          'Allow comments on new videos',
          controller.userData['allowComments'] ?? true,
          (value) => controller.updateField('allowComments', value),
        ),
        _buildToggleListTile(
          'Hold potentially inappropriate comments for review',
          controller.userData['moderateComments'] ?? true,
          (value) => controller.updateField('moderateComments', value),
        ),
        _buildToggleListTile(
          'Save watch history',
          controller.userData['saveWatchHistory'] ?? true,
          (value) => controller.updateField('saveWatchHistory', value),
        ),
      ],
    );
  }

  // ===== ADVANCED SECTION =====
  Widget _buildAdvancedSettings(StudioSettingsController controller) {
    final defaultVisibility =
        controller.userData['defaultVideoVisibility'] ?? 'public';
    return Column(
      children: [
        ListTile(
          title: const Text(
            'Default video visibility',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            controller.getVisibilityLabel(
              defaultVisibility,
            ),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: DropdownButton<String>(
            value: defaultVisibility,
            dropdownColor: const Color(0xFF1E1E1E),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(value: 'unlisted', child: Text('Unlisted')),
              DropdownMenuItem(value: 'private', child: Text('Private')),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.updateField('defaultVideoVisibility', value);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildToggleListTile(
          '2-Step Verification',
          controller.userData['twoFactorEnabled'] ?? false,
          (value) => controller.updateField('twoFactorEnabled', value),
        ),
      ],
    );
  }

  // ===== DANGER ZONE SECTION =====
  Widget _buildDangerZoneSettings(
      BuildContext context, StudioSettingsController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.delete_forever_outlined,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Delete Channel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Deleting your channel is permanent. All channel settings, content, and data associated with this channel will be removed.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isDeletingChannel.value
                    ? null
                    : () => _showDeleteChannelDialog(context, controller),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: controller.isDeletingChannel.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  controller.isDeletingChannel.value
                      ? 'Deleting...'
                      : 'Delete Channel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChannelDialog(
      BuildContext context, StudioSettingsController controller) {
    final channelName = controller.userData['displayName'] ?? 'your channel';
    final textController = TextEditingController();
    final confirmEnabled = false.obs;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text(
              'Delete Channel?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$channelName"? This action cannot be undone.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Type DELETE to confirm:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                confirmEnabled.value = val.trim().toUpperCase() == 'DELETE';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: confirmEnabled.value
                  ? () async {
                      Navigator.of(dialogContext).pop();
                      final success = await controller.deleteChannel();
                      if (success && context.mounted) {
                        if (AppFlavor.isStudio) {
                          Get.offAllNamed('/studio');
                        } else {
                          Get.offAllNamed('/');
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                disabledBackgroundColor: AppColors.error.withOpacity(0.3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Channel'),
            ),
          ),
        ],
      ),
    );
  }

  // ===== WIDGET HELPERS =====
  Widget _buildTextField(
    String label,
    String value,
    Function(String)? onChanged, {
    String? prefix,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final effectiveFormatters = inputFormatters ??
        (label.toLowerCase().contains('email')
            ? null
            : [...TruthworldTextInputFormatters.standard]);
    return TextFormField(
      readOnly: readOnly,
      inputFormatters: effectiveFormatters,
      initialValue: '${prefix ?? ""}$value',
      onFieldSubmitted: onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF333333)),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.colors.primary),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildToggleListTile(
    String title,
    bool value,
    Function(bool) onChanged, {
    String? subtitle,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.colors.primary,
    );
  }
}
