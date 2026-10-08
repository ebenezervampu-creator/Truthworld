import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio Settings Page matching 100% of the Consumer App Settings UI, theme, and fonts.
class StudioSettingsPage extends StatelessWidget {
  const StudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<StudioSettingsController>()
        ? Get.find<StudioSettingsController>()
        : Get.put(StudioSettingsController());

    final spacing = context.layoutSpacing;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        centerTitle: context.isMobile,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: context.colors.textPrimary,
            size: context.isMobileSmall ? 20 : 24,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Settings',
          style: context.typography.headline.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: Obx(
        () {
          if (controller.isLoadingData.value) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFF1E1E1E),
              highlightColor: AppColors.bgSurfaceHover,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing),
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Container(
                      height: 180,
                      margin: EdgeInsets.only(bottom: spacing),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          if (controller.userData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No user data available',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please sign in to access settings',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 14,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ResponsiveContainer(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: spacing),
              children: [
                _buildChannelSection(context, controller),
                SizedBox(height: spacing),
                _buildNotificationSection(context, controller),
                SizedBox(height: spacing),
                _buildMonetizationSection(context, controller),
                SizedBox(height: spacing),
                _buildPrivacySection(context, controller),
                SizedBox(height: spacing),
                _buildAdvancedSection(context, controller),
                SizedBox(height: spacing),
                _buildDangerZoneSection(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===== CHANNEL & PROFILE SECTION =====
  Widget _buildChannelSection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    final padding = EdgeInsets.symmetric(
      horizontal: context.layoutSpacing,
      vertical: 12,
    );

    return SettingsSectionCard(
      title: 'Channel & Profile',
      children: [
        Padding(
          padding: padding,
          child: Column(
            children: [
              _buildStyledTextField(
                context,
                label: 'Channel name',
                value: controller.userData['displayName'] ?? '',
                icon: Icons.badge_outlined,
                onChanged: (value) => controller.updateField('displayName', value),
              ),
              const SizedBox(height: 16),
              _buildStyledTextField(
                context,
                label: 'Handle',
                value: controller.userData['channelHandle'] ?? '',
                prefix: '@',
                icon: Icons.alternate_email,
                onChanged: (value) => controller.updateField('channelHandle', value),
              ),
              const SizedBox(height: 16),
              _buildStyledTextField(
                context,
                label: 'Email',
                value: controller.userData['email'] ?? '',
                readOnly: true,
                icon: Icons.email_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== NOTIFICATIONS SECTION =====
  Widget _buildNotificationSection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    final notif = controller.userData['notificationSettings'] as Map? ?? {};

    return SettingsSectionCard(
      title: 'Notifications',
      children: [
        _buildToggleTile(
          context,
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Email me about new comments',
          value: notif['emailComments'] ?? true,
          onChanged: (value) => controller.updateNestedField(
            'notificationSettings',
            'emailComments',
            value,
          ),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.notifications_active_outlined,
          title: 'Push notification for new subscribers',
          value: notif['pushNewSubscriber'] ?? true,
          onChanged: (value) => controller.updateNestedField(
            'notificationSettings',
            'pushNewSubscriber',
            value,
          ),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.copyright_outlined,
          title: 'Email for copyright claims',
          value: notif['emailCopyright'] ?? true,
          onChanged: (value) => controller.updateNestedField(
            'notificationSettings',
            'emailCopyright',
            value,
          ),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.analytics_outlined,
          title: 'Weekly performance digest email',
          value: notif['digestWeekly'] ?? false,
          onChanged: (value) => controller.updateNestedField(
            'notificationSettings',
            'digestWeekly',
            value,
          ),
        ),
      ],
    );
  }

  // ===== MONETIZATION SECTION =====
  Widget _buildMonetizationSection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    final isMonetizationEnabled =
        controller.userData['monetizationEnabled'] ?? false;
    final noAdsForMembers =
        (controller.userData['noAdsForMembers'] as bool?) ?? false;

    return SettingsSectionCard(
      title: 'Monetization',
      children: [
        _buildToggleTile(
          context,
          icon: Icons.monetization_on_outlined,
          title: 'Enable monetization',
          value: isMonetizationEnabled,
          onChanged: (value) => controller.updateField('monetizationEnabled', value),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.card_membership_outlined,
          title: 'Channel Premium for members (30% platform cut)',
          subtitle: noAdsForMembers
              ? 'Active: Members watch your videos ad-free in 4K Ultra HD. Platform fee: 30% on memberships.'
              : 'Inactive: Standard ads and resolution ceilings apply. 0% platform commission on memberships.',
          value: noAdsForMembers,
          onChanged: (value) => controller.toggleNoAdsForMembers(value),
        ),
        if (isMonetizationEnabled) ...[
          _buildDivider(context),
          ListTile(
            leading: Icon(
              Icons.link_rounded,
              color: context.colors.textPrimary,
              size: 22,
            ),
            title: Text(
              'AdSense ID',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              controller.userData['adSenseId'] ?? 'Not linked',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.md,
                ),
              ),
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
  Widget _buildPrivacySection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    return SettingsSectionCard(
      title: 'Privacy & Content',
      children: [
        _buildToggleTile(
          context,
          icon: Icons.comment_outlined,
          title: 'Allow comments on new videos',
          value: controller.userData['allowComments'] ?? true,
          onChanged: (value) => controller.updateField('allowComments', value),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.security_outlined,
          title: 'Hold potentially inappropriate comments for review',
          value: controller.userData['moderateComments'] ?? true,
          onChanged: (value) => controller.updateField('moderateComments', value),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.history_rounded,
          title: 'Save watch history',
          value: controller.userData['saveWatchHistory'] ?? true,
          onChanged: (value) => controller.updateField('saveWatchHistory', value),
        ),
      ],
    );
  }

  // ===== ADVANCED SECTION =====
  Widget _buildAdvancedSection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    final defaultVisibility =
        controller.userData['defaultVideoVisibility'] ?? 'public';

    return SettingsSectionCard(
      title: 'Advanced Settings',
      children: [
        ListTile(
          leading: Icon(
            Icons.visibility_outlined,
            color: context.colors.textPrimary,
            size: 22,
          ),
          title: Text(
            'Default video visibility',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            controller.getVisibilityLabel(defaultVisibility),
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: context.colors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: context.colors.surface,
            ),
            child: DropdownButton<String>(
              value: defaultVisibility,
              dropdownColor: context.colors.surface,
              underline: const SizedBox.shrink(),
              icon: Icon(
                Icons.arrow_drop_down,
                color: context.colors.textSecondary,
              ),
              items: [
                DropdownMenuItem(
                  value: 'public',
                  child: Text(
                    'Public',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unlisted',
                  child: Text(
                    'Unlisted',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'private',
                  child: Text(
                    'Private',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.updateField('defaultVideoVisibility', value);
                }
              },
            ),
          ),
        ),
        _buildDivider(context),
        _buildToggleTile(
          context,
          icon: Icons.verified_user_outlined,
          title: '2-Step Verification',
          value: controller.userData['twoFactorEnabled'] ?? false,
          onChanged: (value) => controller.updateField('twoFactorEnabled', value),
        ),
      ],
    );
  }

  // ===== DANGER ZONE SECTION =====
  Widget _buildDangerZoneSection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Channel',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Deleting your channel is permanent. All channel settings, content, and data associated with this channel will be removed permanently.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  color: context.colors.textSecondary,
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: context.radius.md,
                      ),
                      elevation: 0,
                    ),
                    icon: controller.isDeletingChannel.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                    label: Text(
                      controller.isDeletingChannel.value
                          ? 'Deleting Channel...'
                          : 'Delete Channel',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteChannelDialog(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    final channelName = controller.userData['displayName'] ?? 'your channel';
    final textController = TextEditingController();
    final confirmEnabled = false.obs;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: context.radius.lg,
          side: BorderSide(color: context.colors.divider),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Channel?',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$channelName"? This action cannot be undone.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Type DELETE to confirm:',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              autofocus: true,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: context.colors.textTertiary,
                ),
                filled: true,
                fillColor: context.colors.surfaceInput,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: context.radius.md,
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: context.radius.md,
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: context.radius.md,
                  borderSide: const BorderSide(color: AppColors.error),
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
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textSecondary,
              ),
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
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.md,
                ),
              ),
              child: const Text('Delete Channel'),
            ),
          ),
        ],
      ),
    );
  }

  // ===== WIDGET HELPERS =====
  Widget _buildStyledTextField(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Function(String)? onChanged,
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
      style: TextStyle(
        fontFamily: TWTypography.uiFamily,
        color: context.colors.textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: context.colors.textSecondary,
        ),
        prefixIcon: Icon(
          icon,
          color: context.colors.textSecondary,
          size: 20,
        ),
        filled: true,
        fillColor: context.colors.surfaceInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: context.colors.divider),
          borderRadius: context.radius.md,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
          borderRadius: context.radius.md,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String? subtitle,
  }) {
    return SwitchListTile.adaptive(
      secondary: Icon(
        icon,
        color: context.colors.textPrimary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: context.colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: AppColors.brand.withValues(alpha: 0.4),
      inactiveTrackColor: context.colors.divider,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: context.colors.divider,
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}
