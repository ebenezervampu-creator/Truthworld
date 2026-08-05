import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
                      ],
                    )),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
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
    return Column(
      children: [
        _buildToggleListTile(
          'Enable monetization',
          isMonetizationEnabled,
          (value) => controller.updateField('monetizationEnabled', value),
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

  // ===== WIDGET HELPERS =====
  Widget _buildTextField(
    String label,
    String value,
    Function(String)? onChanged, {
    String? prefix,
    bool readOnly = false,
  }) {
    return TextFormField(
      readOnly: readOnly,
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
    Function(bool) onChanged,
  ) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.colors.primary,
    );
  }
}
