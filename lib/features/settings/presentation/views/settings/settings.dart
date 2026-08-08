import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/google_onboarding_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// Constants for consistent styling
const double kBorderRadius = 16;

ThemeData _getSettingsTheme(BuildContext context) {
  final parentTheme = Theme.of(context);
  final parentColors = parentTheme.extension<TWColors>();
  final parentTypography = parentTheme.extension<TWTypography>();

  if (parentColors == null || parentTypography == null) {
    return buildAppTheme();
  }

  final homeColors = TWColors(
    brand: const Color(0xFF1976D2), // Professional blue
    brandContainer: const Color(0xFF1976D2).withValues(alpha: 0.12),
    brandVariant: const Color(0xFF42A5F5), // Lighter blue
    textPrimary: const Color(0xFFE8E8E8),
    textSecondary: const Color(0xFFB8B8B8),
    textTertiary: const Color(0xFFB8B8B8).withValues(alpha: 0.7),
    textDisabled: const Color(0xFFB8B8B8).withValues(alpha: 0.38),
    background: const Color(0xFF0F0F0F),
    surface: const Color(0xFF121212),
    surfaceContainer: const Color(0xFF1E1E1E),
    surfaceContainerHigh: const Color(0xFF1E1E1E),
    surfaceContainerHighest: const Color(0xFF1E1E1E),
    surfaceInput: const Color(0xFF121212),
    appBarSurface: const Color(0xFF121212),
    divider: const Color(0xFF1E1E1E),
    success: parentColors.success,
    warning: parentColors.warning,
    error: const Color(0xFFFF6B6B),
    info: const Color(0xFF42A5F5),
    successContainer: parentColors.successContainer,
    warningContainer: parentColors.warningContainer,
    errorContainer: parentColors.errorContainer,
    infoContainer: parentColors.infoContainer,
    selectedOverlay: parentColors.selectedOverlay,
    hoverOverlay: parentColors.hoverOverlay,
    pressedOverlay: parentColors.pressedOverlay,
    focusRing: parentColors.focusRing,
  );

  final homeTypography = TWTypography(
    logo: parentTypography.logo,
    hero: parentTypography.hero,
    display: parentTypography.display,
    headline: parentTypography.headline,
    title: parentTypography.title,
    body: parentTypography.body,
    bodySmall: parentTypography.bodySmall,
    label: parentTypography.label,
    caption: parentTypography.caption,
    button: parentTypography.button,
    overline: parentTypography.overline,
  );

  return buildAppTheme().copyWith(
    extensions: [
      homeColors,
      homeTypography,
      if (parentTheme.extension<TWSpacing>() != null)
        parentTheme.extension<TWSpacing>()!,
      if (parentTheme.extension<TWRadius>() != null)
        parentTheme.extension<TWRadius>()!,
      if (parentTheme.extension<TWMotion>() != null)
        parentTheme.extension<TWMotion>()!,
      if (parentTheme.extension<TWShadows>() != null)
        parentTheme.extension<TWShadows>()!,
      if (parentTheme.extension<TWGradients>() != null)
        parentTheme.extension<TWGradients>()!,
      if (parentTheme.extension<TWLayoutTokens>() != null)
        parentTheme.extension<TWLayoutTokens>()!,
    ],
  );
}

class WatchHistorySettingsView extends StatelessWidget {
  const WatchHistorySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WatchHistoryController>();

    return Theme(
      data: _getSettingsTheme(context),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(
              backgroundColor: context.colors.background,
              elevation: 0,
              title: Text(
                'Watch history',
                style: context.typography.headline.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
                onPressed: Get.back,
              ),
            ),
            body: SafeArea(
              child: ListView(
                children: [
                  _buildHeader(context),
                  const Divider(color: AppColors.bgDivider),
                  _buildControlSection(context, controller),
                  const Divider(color: AppColors.bgDivider),
                  _buildDeleteSection(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage your viewing history',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "History helps you find videos you've watched and improves your recommendations.",
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(
    BuildContext context,
    WatchHistoryController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'CONTROLS'),
        Obx(
          () => ListTile(
            leading: Icon(
              controller.isHistoryPaused.value
                  ? Icons.play_arrow_outlined
                  : Icons.pause_circle_outline,
              color: AppColors.textPrimary,
            ),
            title: Text(
              controller.isHistoryPaused.value
                  ? 'Resume watch history'
                  : 'Pause watch history',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: controller.toggleHistoryPaused,
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.list_alt_rounded,
            color: AppColors.textPrimary,
          ),
          title: const Text(
            'View full history',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          onTap: () {
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().onSideNavItemSelect(
                HomeController.indexHistory,
              );
              Get.back();
              Get.back();
            } else {
              Get.toNamed('/watchhistory');
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeleteSection(
    BuildContext context,
    WatchHistoryController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'DELETE OPTIONS'),
        _buildDeleteTile(
          context,
          'Delete today',
          Icons.today_outlined,
          onTap: () => _confirmDelete(context, 'today', controller.deleteToday),
        ),
        _buildDeleteTile(
          context,
          'Delete yesterday',
          Icons.event_note_outlined,
          onTap: () =>
              _confirmDelete(context, 'yesterday', controller.deleteYesterday),
        ),
        _buildDeleteTile(
          context,
          'Delete this week',
          Icons.calendar_view_week_outlined,
          onTap: () =>
              _confirmDelete(context, 'this week', controller.deleteThisWeek),
        ),
        _buildDeleteTile(
          context,
          'Delete previous week',
          Icons.calendar_month_outlined,
          onTap: () => _confirmDelete(
            context,
            'previous week',
            controller.deletePreviousWeek,
          ),
        ),
        _buildDeleteTile(
          context,
          'Delete all time',
          Icons.delete_forever_outlined,
          isError: true,
          onTap: controller.clearAllHistory,
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'To delete a particular video, use the "View full history" option above.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.colors.brand,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDeleteTile(
    BuildContext context,
    String title,
    IconData icon, {
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isError ? context.colors.error : AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isError ? context.colors.error : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDelete(
    BuildContext context,
    String label,
    VoidCallback onConfirm,
  ) {
    final colors = context.colors;
    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Delete History?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete your watch history from $label?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              onConfirm();
            },
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    UserSettingsController.to;

    return Theme(
      data: _getSettingsTheme(context),
      child: Builder(
        builder: (context) {
          return ResponsiveBuilder(
            builder: (context, deviceType) {
              return Scaffold(
                backgroundColor: context.colors.background,
                appBar: _buildAppBar(context),
                body: SafeArea(child: _buildBody(context)),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Settings',
        style: context.typography.headline.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
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
          if (isDashboard) {
            Get.find<HomeController>().sideNavSelectedIndex.value =
                HomeController.indexLibrary;
          } else {
            Get.back();
          }
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ResponsiveContainer(
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.layoutSpacing),
        children: [
          // 1. General & Account Section
          _buildSection(
            context,
            title: 'General & Account',
            settings: [
              _buildUserInfoTile(context),
              _buildAgeAndGenderTile(context),
              _buildSubscriptionTile(context),
              _buildAccountStatusTile(context),
              _buildLogoutTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 2. Digital Wellbeing & Screen Time
          _buildSection(
            context,
            title: 'Digital Wellbeing & Screen Time',
            settings: [
              _buildBreakReminderTile(context),
              _buildBedtimeReminderTile(context),
              _buildParentalControlsTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 3. Playback & Media Preferences
          _buildSection(
            context,
            title: 'Playback & Media Preferences',
            settings: [
              _buildVideoQualityTile(context),
              _buildVolumeNormalizationTile(context),
              _buildBackgroundPlaybackTile(context),
              _buildAutoplayNextTile(context),
              _buildSeekDurationTile(context),
              _buildStatsForNerdsTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 4. Downloads & Smart Storage
          _buildSection(
            context,
            title: 'Downloads & Smart Storage',
            settings: [
              _buildSmartDownloadsTile(context),
              _buildDownloadWifiOnlyTile(context),
              _buildStorageLimitTile(context),
              _buildDownloadLocationTile(context),
              _buildClearCacheTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 5. Notifications
          _buildSection(
            context,
            title: 'Notifications',
            settings: [
              _buildPushNotificationTile(context),
              _buildChannelAlertsTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 6. Privacy & History
          _buildSection(
            context,
            title: 'Privacy & History',
            settings: [
              _buildWatchHistoryTile(context),
              _buildSearchHistoryTile(context),
              _buildBlockedMutedTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 7. Accessibility & Comfort
          _buildSection(
            context,
            title: 'Accessibility & Comfort',
            settings: [
              _buildReduceMotionTile(context),
              _buildSubtitlesCaptionsTile(context),
              _buildHapticFeedbackTile(context),
              _buildColorBlindTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 8. Advanced & Reset Options
          _buildSection(
            context,
            title: 'Advanced & Diagnostics',
            settings: [
              _buildResetSettingsTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),

          // 9. Legal & About Section
          _buildSection(
            context,
            title: 'Legal & About',
            settings: [
              _buildLegalTile(
                context,
                title: 'Privacy Policy',
                icon: Icons.privacy_tip_outlined,
                index: HomeController.indexPrivacy,
                route: '/privacy',
              ),
              _buildLegalTile(
                context,
                title: 'Terms & Conditions',
                icon: Icons.article_outlined,
                index: HomeController.indexTerms,
                route: '/terms',
              ),
              _buildLegalTile(
                context,
                title: 'Community Guidelines',
                icon: Icons.gavel_outlined,
                index: HomeController.indexCommunityGuidelines,
                route: '/community-guidelines',
              ),
              _buildVersionTile(context),
              _buildHelpTile(context),
              _buildFeedbackTile(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> settings,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(context.layoutSpacing),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...settings,
        ],
      ),
    );
  }

  // ================= 1. ACCOUNT TILES =================

  Widget _buildUserInfoTile(BuildContext context) {
    final authService = AuthService.to;
    return Obx(() {
      final displayName = authService.activeDisplayName;
      final handleOrEmail =
          authService.hasChannel.value && authService.userChannel != null
          ? authService.activeHandle
          : (authService.user?.email ?? '');

      final genderText = authService.userGender.value ?? 'Not specified';
      final ageText = authService.userAge.value != null
          ? '${authService.userAge.value} yrs'
          : 'Not specified';
      final locationText = authService.userLocation.value ?? 'Not specified';

      return ListTile(
        leading: UserAvatar(
          radius: 22,
          photoUrl: authService.activePhotoUrl,
          displayName: displayName,
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$handleOrEmail • $genderText • $ageText • Location: $locationText',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
        onTap: () => _showEditProfileDialog(context),
      );
    });
  }

  Widget _buildAgeAndGenderTile(BuildContext context) {
    final authService = AuthService.to;
    return Obx(() {
      final ageGroup = authService.userAgeGroup.value;
      final gender = authService.userGender.value;

      final infoParts = <String>[];
      if (ageGroup != null && ageGroup.isNotEmpty) {
        infoParts.add('Age: $ageGroup');
      }
      if (gender != null && gender.isNotEmpty) {
        infoParts.add('Gender: $gender');
      }

      final subtitleText = infoParts.isNotEmpty
          ? infoParts.join(' • ')
          : 'Not set — Tap to add age group and gender for recommendations';

      return ListTile(
        leading: const Icon(
          Icons.face_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Age Group & Gender',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textPrimary,
        ),
        onTap: () => GoogleOnboardingSheet.show(context),
      );
    });
  }

  void _showEditProfileDialog(BuildContext context) {
    final auth = AuthService.to;
    final nameCtrl = TextEditingController(text: auth.activeDisplayName);
    final handleCtrl = TextEditingController(
      text: auth.activeHandle.replaceAll('@', ''),
    );
    final bioCtrl = TextEditingController(
      text: auth.userChannel?.description ?? '',
    );
    final ageCtrl = TextEditingController(
      text: auth.userAge.value?.toString() ?? '',
    );
    final locationCtrl = TextEditingController(
      text: auth.userLocation.value ?? '',
    );
    final selectedGender =
        (auth.userGender.value ?? 'Prefer not to say').obs;
    final genderOptions = <String>[
      'Male',
      'Female',
      'Non-binary',
      'Other',
      'Prefer not to say',
    ];
    if (!genderOptions.contains(selectedGender.value)) {
      genderOptions.add(selectedGender.value);
    }

    Get.dialog(
      Obx(() {
        final currentGender = selectedGender.value;
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: const Text(
            'Edit Profile Details',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: handleCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Handle',
                    prefixText: '@',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: context.colors.surface,
                  value: currentGender,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: genderOptions
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) selectedGender.value = val;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Age (Years)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Location (City, Country)',
                    helperText: 'Leave blank or tap clear to remove location',
                    helperStyle:
                        const TextStyle(color: AppColors.textTertiary),
                    suffixIcon: locationCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: locationCtrl.clear,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
              TextButton(
                onPressed: Get.back,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final brandColor = context.colors.brand;
                  Get.back();
                  final uid = auth.uid;
                  if (uid.isNotEmpty) {
                    try {
                      final newName = nameCtrl.text.trim();
                      final newHandle =
                          '@${handleCtrl.text.trim().replaceAll('@', '')}';
                      final newBio = bioCtrl.text.trim();
                      final parsedAge = int.tryParse(ageCtrl.text.trim());
                      final newLocation = locationCtrl.text.trim();

                      final userUpdates = <String, dynamic>{
                        'displayName': newName,
                        'handle': newHandle,
                        'bio': newBio,
                        'gender': selectedGender.value,
                        'age': parsedAge,
                      };

                      if (newLocation.isNotEmpty) {
                        userUpdates['location'] = newLocation;
                      } else {
                        userUpdates['location'] = FieldValue.delete();
                        userUpdates['city'] = FieldValue.delete();
                        userUpdates['state'] = FieldValue.delete();
                        userUpdates['country'] = FieldValue.delete();
                        auth.userLocation.value = null;
                        auth.userCity.value = null;
                        auth.userState.value = null;
                        auth.userCountry.value = null;
                      }

                      await FirebaseFirestore.instance
                          .collection(FirestoreCollections.users)
                          .doc(uid)
                          .set(userUpdates, SetOptions(merge: true));

                      if (auth.hasChannel.value && auth.userChannel != null) {
                        await FirebaseFirestore.instance
                            .collection(FirestoreCollections.channels)
                            .doc(auth.userChannel!.id)
                            .update({
                              'name': newName,
                              'handle': newHandle,
                              'description': newBio,
                            });
                      }

                      Get.snackbar(
                        'Profile Updated',
                        'Profile details saved.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: brandColor,
                        colorText: Colors.white,
                      );
                    } catch (e) {
                      debugPrint('Error updating profile: $e');
                      Get.snackbar(
                        'Update Failed',
                        'Failed to save profile details.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.error,
                      );
                    }
                  }
                },
                child: Text(
                  'Save',
                  style: TextStyle(color: context.colors.brand),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionTile(BuildContext context) {
    final auth = AuthService.to;
    return Obx(() {
      final isPremium = auth.isPremiumUser.value;
      return ListTile(
        leading: Icon(
          isPremium ? Icons.workspace_premium : Icons.card_membership,
          color: isPremium ? Colors.amber : AppColors.textPrimary,
        ),
        title: Text(
          isPremium ? 'Premium Membership Active' : 'Free Account Tier',
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          isPremium
              ? 'Ad-free 4K & background playback'
              : 'Upgrade to Premium for 4K & ad-free streaming',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => Get.toNamed('/premium'),
      );
    });
  }

  Widget _buildAccountStatusTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.no_accounts_outlined, color: AppColors.warning),
      title: const Text(
        'Account Deactivation & Status',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        'Temporarily pause account or delete permanently',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () => _showAccountStatusOptions(context),
    );
  }

  void _showAccountStatusOptions(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Account Status Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.pause_circle_outline,
                color: AppColors.warning,
              ),
              title: const Text(
                'Deactivate Account',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Temporarily hide channel & activity.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () async {
                Get.back();
                final uid = AuthService.to.uid;
                if (uid.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.users)
                        .doc(uid)
                        .update({
                          'status': 'deactivated',
                          'deactivatedAt': FieldValue.serverTimestamp(),
                        });
                    Get.snackbar(
                      'Account Paused',
                      'Your channel and account activity are hidden.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to deactivate account.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.error,
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete Account Permanently',
                style: TextStyle(color: AppColors.error),
              ),
              subtitle: const Text(
                'Irreversible removal of account data.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Get.back();
                _showDeleteAccountConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.logout, color: context.colors.error),
      title: Text(
        'Log Out',
        style: TextStyle(fontSize: 16, color: context.colors.error),
      ),
      onTap: () => _showLogoutConfirmation(context),
    );
  }

  // ================= 2. DIGITAL WELLBEING TILES =================

  Widget _buildBreakReminderTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(() {
      final mins = ctrl.wellbeing.value.breakReminderMinutes;
      final label = mins == 0 ? 'Off' : 'Every $mins minutes';
      return ListTile(
        leading: const Icon(Icons.timer_outlined, color: AppColors.textPrimary),
        title: const Text(
          'Remind me to take a break',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          label,
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showBreakReminderDialog(context),
      );
    });
  }

  void _showBreakReminderDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Take a Break Reminder',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0, 15, 30, 60, 90, 120]
              .map(
                (m) => Obx(
                  () => RadioListTile<int>(
                    title: Text(
                      m == 0 ? 'Off' : 'Every $m minutes',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: m,
                    groupValue: ctrl.wellbeing.value.breakReminderMinutes,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setBreakReminder(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBedtimeReminderTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(() {
      final wb = ctrl.wellbeing.value;
      return SwitchListTile(
        secondary: const Icon(
          Icons.bedtime_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Bedtime Reminder',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          wb.bedtimeEnabled
              ? '${wb.bedtimeStartTime} – ${wb.bedtimeEndTime} (${wb.bedtimeDaysSchedule})'
              : 'Off',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: wb.bedtimeEnabled,
        onChanged: (val) {
          ctrl.toggleBedtimeReminder(val);
          if (val) _showBedtimeScheduleDialog(context);
        },
      );
    });
  }

  void _showBedtimeScheduleDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          final wb = ctrl.wellbeing.value;
          return AlertDialog(
            backgroundColor: context.colors.surface,
            title: const Text(
              'Bedtime Schedule',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIME WINDOW',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(
                        Icons.access_time,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      label: Text(
                        'Start: ${wb.bedtimeStartTime}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () async {
                        final dlgContext = context;
                        final picked = await showTimePicker(
                          context: dlgContext,
                          initialTime: const TimeOfDay(hour: 23, minute: 0),
                        );
                        if (picked != null && dlgContext.mounted) {
                          ctrl.setBedtimeSchedule(
                            picked.format(dlgContext),
                            wb.bedtimeEndTime,
                            wb.bedtimeDaysSchedule,
                          );
                          ctrl.update();
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.access_time,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      label: Text(
                        'End: ${wb.bedtimeEndTime}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () async {
                        final dlgContext = context;
                        final picked = await showTimePicker(
                          context: dlgContext,
                          initialTime: const TimeOfDay(hour: 6, minute: 0),
                        );
                        if (picked != null && dlgContext.mounted) {
                          ctrl.setBedtimeSchedule(
                            wb.bedtimeStartTime,
                            picked.format(dlgContext),
                            wb.bedtimeDaysSchedule,
                          );
                          ctrl.update();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'REPEAT DAYS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...['Everyday', 'Weekdays', 'Weekends'].map(
                  (sched) => Obx(
                    () => RadioListTile<String>(
                      title: Text(
                        sched,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      value: sched,
                      groupValue: ctrl.wellbeing.value.bedtimeDaysSchedule,
                      onChanged: (val) {
                        if (val != null) {
                          ctrl.setBedtimeSchedule(
                            ctrl.wellbeing.value.bedtimeStartTime,
                            ctrl.wellbeing.value.bedtimeEndTime,
                            val,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
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
          );
        },
      ),
    );
  }

  Widget _buildParentalControlsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(() {
      final isEnabled = ctrl.wellbeing.value.parentalPinEnabled;
      return ListTile(
        leading: Icon(
          Icons.security,
          color: isEnabled ? Colors.green : AppColors.textPrimary,
        ),
        title: const Text(
          'Parental Controls & PIN Lock',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          isEnabled
              ? 'Restricted Mode Active (SHA-256 Protected)'
              : 'Off • Tap to set 4-digit PIN lock',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showParentalPinDialog(context),
      );
    });
  }

  void _showParentalPinDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    final pinCtrl = TextEditingController();

    Get.dialog(
      Obx(() {
        final isEnabled = ctrl.wellbeing.value.parentalPinEnabled;
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text(
            isEnabled ? 'Parental Controls Active' : 'Setup Parental PIN Lock',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEnabled
                    ? 'Enter your 4-digit PIN to disable restricted mode:'
                    : 'Create a 4-digit PIN to restrict mature content & lock settings:',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  letterSpacing: 8,
                  fontSize: 20,
                ),
                decoration: const InputDecoration(hintText: '••••'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (isEnabled)
              TextButton(
                onPressed: () {
                  if (ctrl.verifyParentalPin(pinCtrl.text.trim())) {
                    ctrl.disableParentalPin();
                    Get.back();
                    Get.snackbar(
                      'Parental Controls Disabled',
                      'Restricted mode turned off.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } else {
                    Get.snackbar(
                      'Incorrect PIN',
                      'The PIN entered is invalid.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.error,
                    );
                  }
                },
                child: const Text(
                  'Disable Lock',
                  style: TextStyle(color: AppColors.error),
                ),
              )
            else
              TextButton(
                onPressed: () {
                  if (pinCtrl.text.trim().length == 4) {
                    ctrl.setParentalPin(pinCtrl.text.trim());
                    Get.back();
                    Get.snackbar(
                      'PIN Set',
                      'Parental control PIN enabled using SHA-256.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
                child: Text(
                  'Save PIN',
                  style: TextStyle(color: context.colors.brand),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ================= 3. PLAYBACK & MEDIA TILES =================

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
          onPressed: () async {
            await ctrl.clearCache();
            Get.snackbar(
              'Cache Cleared',
              'Cache wiped successfully.',
              snackPosition: SnackPosition.BOTTOM,
            );
          },
          child: const Text('Clear', style: TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  // ================= 5. NOTIFICATIONS TILES =================

  Widget _buildPushNotificationTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Push Notifications',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Master switch for all push alerts',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.pushNotificationsEnabled.value,
        onChanged: ctrl.togglePushNotifications,
      ),
    );
  }

  Widget _buildChannelAlertsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.subscriptions_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Subscription & Channel Alerts',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Level: ${ctrl.channelAlerts.value}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showChannelAlertsDialog(context),
      ),
    );
  }

  void _showChannelAlertsDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Channel Notification Alerts',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All', 'Personalized', 'None']
              .map(
                (opt) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      opt,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: opt,
                    groupValue: ctrl.channelAlerts.value,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setChannelAlerts(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ================= 6. PRIVACY & HISTORY TILES =================

  Widget _buildWatchHistoryTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history, color: AppColors.textPrimary),
      title: const Text(
        'Watch History Controls',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        'Pause watch history or clear viewing log',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () => Get.to(() => const WatchHistorySettingsView()),
    );
  }

  Widget _buildSearchHistoryTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.search_off_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Search History Controls',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          ctrl.isSearchHistoryPaused.value
              ? 'Search history is PAUSED'
              : 'Manage or clear search queries',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showSearchHistoryDialog(context),
      ),
    );
  }

  void _showSearchHistoryDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Search History Controls',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => ListTile(
                leading: Icon(
                  ctrl.isSearchHistoryPaused.value
                      ? Icons.play_arrow_outlined
                      : Icons.pause_circle_outline,
                  color: AppColors.textPrimary,
                ),
                title: Text(
                  ctrl.isSearchHistoryPaused.value
                      ? 'Resume Search History'
                      : 'Pause Search History',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  ctrl.toggleSearchHistoryPaused();
                  Get.back();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Clear All Search History',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Get.back();
                ctrl.clearSearchHistory();
                Get.snackbar(
                  'Search History Cleared',
                  'Search history wiped.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedMutedTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(Icons.block_outlined, color: AppColors.textPrimary),
        title: const Text(
          'Blocked & Muted List',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          '${ctrl.blockedUsers.length} blocked users • ${ctrl.mutedKeywords.length} muted keywords',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showBlockedMutedDialog(context),
      ),
    );
  }

  void _showBlockedMutedDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    final keywordCtrl = TextEditingController();
    final blockUserCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Blocked & Muted List',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MUTED KEYWORDS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: keywordCtrl,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Mute keyword...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.textPrimary),
                    onPressed: () {
                      if (keywordCtrl.text.isNotEmpty) {
                        ctrl.addMutedKeyword(keywordCtrl.text);
                        keywordCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: ctrl.mutedKeywords
                      .map(
                        (kw) => Chip(
                          backgroundColor: context.colors.surfaceContainerHigh,
                          label: Text(
                            kw,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          onDeleted: () => ctrl.removeMutedKeyword(kw),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider),
              const SizedBox(height: 8),
              const Text(
                'BLOCKED USERS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: blockUserCtrl,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Block user handle...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      if (blockUserCtrl.text.isNotEmpty) {
                        ctrl.blockUser(blockUserCtrl.text);
                        blockUserCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: ctrl.blockedUsers
                      .map(
                        (user) => Chip(
                          backgroundColor: context.colors.surfaceContainerHigh,
                          label: Text(
                            user,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          onDeleted: () => ctrl.unblockUser(user),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 7. ACCESSIBILITY TILES =================

  Widget _buildReduceMotionTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.animation_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Reduce UI Motion & Animations',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Minimize background transitions & motion effects',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.accessibility.value.reduceMotion,
        onChanged: ctrl.toggleReduceMotion,
      ),
    );
  }

  Widget _buildSubtitlesCaptionsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.closed_caption_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Subtitles & Captions Customization',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Size: ${ctrl.accessibility.value.captionSize} • High Contrast: ${ctrl.accessibility.value.highContrastSubtitles ? "On" : "Off"}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showCaptionsDialog(context),
      ),
    );
  }

  void _showCaptionsDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Captions Customization',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => SwitchListTile(
                title: const Text(
                  'High Contrast Background',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: ctrl.accessibility.value.highContrastSubtitles,
                onChanged: ctrl.toggleHighContrastSubtitles,
              ),
            ),
            ...['Small', 'Medium', 'Large', 'Extra Large'].map(
              (sz) => Obx(
                () => RadioListTile<String>(
                  title: Text(
                    sz,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  value: sz,
                  groupValue: ctrl.accessibility.value.captionSize,
                  onChanged: (val) {
                    if (val != null) ctrl.setCaptionSize(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHapticFeedbackTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.vibration_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Haptic Vibration Feedback',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Tactile vibration on player scrubbing & button taps',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.accessibility.value.hapticFeedback,
        onChanged: ctrl.toggleHapticFeedback,
      ),
    );
  }

  Widget _buildColorBlindTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.color_lens_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Color Blindness Filter Mode',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Filter: ${ctrl.accessibility.value.colorBlindSupport}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showColorBlindDialog(context),
      ),
    );
  }

  void _showColorBlindDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Color Blind Support Mode',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Off', 'Protanopia', 'Deuteranopia', 'Tritanopia']
              .map(
                (mode) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      mode,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: mode,
                    groupValue: ctrl.accessibility.value.colorBlindSupport,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setColorBlindSupport(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ================= 8. ADVANCED & RESET TILES =================

  Widget _buildResetSettingsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return ListTile(
      leading: const Icon(Icons.restart_alt_outlined, color: AppColors.error),
      title: const Text(
        'Reset Settings to Defaults',
        style: TextStyle(fontSize: 16, color: AppColors.error),
      ),
      subtitle: Text(
        'Reset playback, downloads, digital wellbeing or factory reset',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.error),
      onTap: () => _showResetOptionsDialog(context, ctrl),
    );
  }

  void _showResetOptionsDialog(
    BuildContext context,
    UserSettingsController ctrl,
  ) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Reset Settings Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Reset Digital Wellbeing',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetWellbeing();
                Get.back();
                Get.snackbar(
                  'Wellbeing Reset',
                  'Digital wellbeing settings restored.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            ListTile(
              title: const Text(
                'Reset Playback Settings',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetPlayback();
                Get.back();
                Get.snackbar(
                  'Playback Reset',
                  'Playback preferences restored.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            ListTile(
              title: const Text(
                'Reset Download Preferences',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetDownloads();
                Get.back();
                Get.snackbar(
                  'Downloads Reset',
                  'Download settings restored.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            ListTile(
              title: const Text(
                'Reset Accessibility Options',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetAccessibility();
                Get.back();
                Get.snackbar(
                  'Accessibility Reset',
                  'Accessibility settings restored.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            const Divider(color: AppColors.bgDivider),
            ListTile(
              title: const Text(
                'Factory Reset ALL Settings',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                ctrl.resetAllSettings();
                Get.back();
                Get.snackbar(
                  'Factory Reset Complete',
                  'All settings restored to default values.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.error,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= 9. LEGAL & ABOUT TILES =================

  Widget _buildVersionTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info, color: AppColors.textPrimary),
      title: const Text(
        'Version',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        '1.0.0 (Truthworld YouTube-Scale Release)',
        style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
      ),
    );
  }

  Widget _buildHelpTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.help, color: AppColors.textPrimary),
      title: const Text(
        'Help & Support',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(
            HomeController.indexHelp,
          );
        } else {
          Get.toNamed('/help');
        }
      },
    );
  }

  Widget _buildFeedbackTile(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.chat_bubble_outline,
        color: AppColors.textPrimary,
      ),
      title: const Text(
        'Feedback',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(
            HomeController.indexFeedback,
          );
        } else {
          Get.toNamed('/feedback');
        }
      },
    );
  }

  Widget _buildLegalTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int index,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(index);
        } else {
          Get.toNamed(route);
        }
      },
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    final colors = context.colors;
    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Delete Account',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action is permanent.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthService.to.deleteAccount();
                Get.offAllNamed('/');
                Get.snackbar(
                  'Account Deleted',
                  'Your account has been deleted.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.success,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Failed to delete account: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.error,
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final colors = context.colors;
    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Log Out', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await AuthService.to.logout();
              Get.offAllNamed('/');
            },
            child: Text('Log Out', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }
}
