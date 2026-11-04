import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_theme.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio Settings Page matching 100% of the Consumer App Settings UI, theme, and fonts.
class StudioSettingsPage extends StatelessWidget {
  const StudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<StudioSettingsController>()
        ? Get.find<StudioSettingsController>()
        : Get.put(StudioSettingsController());

    return Theme(
      data: getSettingsTheme(context),
      child: Builder(
        builder: (context) {
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
                  } else if (Get.isRegistered<DashboardController>()) {
                    Get.find<DashboardController>().setSelectedIndex(1);
                  } else {
                    Get.offAllNamed('/');
                  }
                },
              ),
              title: Text(
                'Settings',
                style: context.typography.headline.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              actions: [
                Obx(
                  () => controller.userData.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.logout_rounded,
                            color: context.colors.error,
                          ),
                          tooltip: 'Sign Out',
                          onPressed: () => _showSignOutDialog(context, controller),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            body: Obx(
              () {
                if (controller.isLoadingData.value) {
                  return const StudioLoadingIndicator(
                    message: 'Loading studio settings...',
                  );
                }

                if (controller.userData.isEmpty) {
                  return _buildUnauthenticatedView(context);
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
                      _buildAccountSection(context, controller),
                      SizedBox(height: spacing),
                      _buildDangerZoneSection(context, controller),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.colors.divider.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 46,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Sign In to Access Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your channel settings, notifications, monetization controls, and session preferences require a signed-in account.',
                style: TextStyle(
                  fontSize: 15,
                  color: context.colors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AuthService.to.triggerPlatformSignIn();
                  },
                  icon: const Icon(
                    Icons.login_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                  label: const Text(
                    'Sign In to Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.textPrimary,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (Get.isRegistered<DashboardController>()) {
                    Get.find<DashboardController>().setSelectedIndex(1);
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Get.offAllNamed('/');
                  }
                },
                icon: Icon(
                  Icons.dashboard_outlined,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
                label: Text(
                  'Back to Dashboard',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
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
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              controller.userData['adSenseId'] ?? 'Not linked',
              style: TextStyle(
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
                AppSnackbar.info(
                  'AdSense linking will be available soon. Stay tuned!',
                );
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
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            controller.getVisibilityLabel(defaultVisibility),
            style: TextStyle(
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
                      color: context.colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unlisted',
                  child: Text(
                    'Unlisted',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'private',
                  child: Text(
                    'Private',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
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

  // ===== ACCOUNT & SESSION SECTION =====
  Widget _buildAccountSection(
    BuildContext context,
    StudioSettingsController controller,
  ) {
    final email = controller.userData['email'] as String? ?? '';
    final name = controller.userData['displayName'] as String? ?? 'Creator';

    return SettingsSectionCard(
      title: 'Account & Session',
      children: [
        ListTile(
          leading: Icon(
            Icons.account_circle_outlined,
            color: context.colors.textPrimary,
            size: 24,
          ),
          title: Text(
            name,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: email.isNotEmpty
              ? Text(
                  email,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                )
              : null,
        ),
        _buildDivider(context),
        ListTile(
          leading: Icon(
            Icons.logout_rounded,
            color: context.colors.error,
            size: 22,
          ),
          title: Text(
            'Sign Out',
            style: TextStyle(
              color: context.colors.error,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Sign out of Truthworld Studio on this device',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: context.colors.error,
            size: 20,
          ),
          onTap: () => _showSignOutDialog(context, controller),
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
          color: context.colors.error.withValues(alpha: 0.4),
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
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.colors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Channel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Scheduling deletion hides your channel immediately with a 30-day grace period. You can restore your channel anytime within 30 days. After 30 days, all channel settings, content, and data are removed permanently.',
                style: TextStyle(
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
                      backgroundColor: context.colors.error,
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
            Icon(
              Icons.warning_amber_rounded,
              color: context.colors.error,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Channel?',
              style: TextStyle(
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
              'Are you sure you want to delete "$channelName"? Your channel will be hidden immediately and scheduled for deletion with a 30-day grace period. You can cancel the deletion anytime in Studio. After 30 days, your channel and all content will be deleted completely.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Type DELETE to confirm:',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              autofocus: true,
              maxLength: 10,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              ],
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(
                  color: context.colors.textTertiary,
                  fontSize: 14,
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
                  borderSide: BorderSide(color: context.colors.error),
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
                color: context.colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
                backgroundColor: context.colors.error,
                disabledBackgroundColor: context.colors.error.withValues(alpha: 0.3),
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

  void _showSignOutDialog(
    BuildContext context,
    StudioSettingsController controller,
  ) {
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
            Icon(
              Icons.logout_rounded,
              color: context.colors.error,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of Truthworld Studio? You will need to sign in again to access and manage your channel.',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: controller.isLoggingOut.value
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await controller.handleSignOut();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.error,
                disabledBackgroundColor: context.colors.error.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.md,
                ),
                elevation: 0,
              ),
              child: controller.isLoggingOut.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
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
    int? maxLength,
  }) {
    final effectiveLimit = maxLength ?? (label.toLowerCase().contains('email') ? 254 : 100);
    final effectiveFormatters = inputFormatters ??
        (label.toLowerCase().contains('email')
            ? [
                LengthLimitingTextInputFormatter(254),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ]
            : TruthworldTextInputFormatters.internationalWithLimit(effectiveLimit));

    final rawInitialValue = (prefix != null && value.startsWith(prefix))
        ? value.substring(prefix.length)
        : value;

    return TextFormField(
      readOnly: readOnly,
      maxLength: effectiveLimit,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: effectiveFormatters,
      initialValue: rawInitialValue,
      onFieldSubmitted: onChanged,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 14,
        ),
        prefixText: prefix,
        prefixStyle: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
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
          borderSide: BorderSide(color: context.colors.brand, width: 1.5),
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
          color: context.colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: context.colors.brand,
      activeTrackColor: context.colors.brand.withValues(alpha: 0.38),
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
