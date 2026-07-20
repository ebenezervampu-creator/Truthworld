import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';


// Constants for consistent styling
const double kBorderRadius = 16.0;
const double kSmallPadding = 8.0;
const double kMediumPadding = 16.0;
const double kLargePadding = 24.0;

ThemeData _getSettingsTheme(BuildContext context) {
  final parentTheme = Theme.of(context);
  final parentColors = parentTheme.extension<TWColors>()!;
  final parentTypography = parentTheme.extension<TWTypography>()!;

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
    logo: GoogleFonts.roboto(textStyle: parentTypography.logo),
    hero: GoogleFonts.roboto(textStyle: parentTypography.hero),
    display: GoogleFonts.roboto(textStyle: parentTypography.display),
    headline: GoogleFonts.roboto(textStyle: parentTypography.headline),
    title: GoogleFonts.roboto(textStyle: parentTypography.title),
    body: GoogleFonts.roboto(textStyle: parentTypography.body),
    bodySmall: GoogleFonts.roboto(textStyle: parentTypography.bodySmall),
    label: GoogleFonts.roboto(textStyle: parentTypography.label),
    caption: GoogleFonts.roboto(textStyle: parentTypography.caption),
    button: GoogleFonts.roboto(textStyle: parentTypography.button),
    overline: GoogleFonts.roboto(textStyle: parentTypography.overline),
  );

  return modernDarkProfessionalTheme.copyWith(
    extensions: [
      homeColors,
      homeTypography,
      parentTheme.extension<TWSpacing>()!,
      parentTheme.extension<TWRadius>()!,
      parentTheme.extension<TWMotion>()!,
      parentTheme.extension<TWShadows>()!,
      parentTheme.extension<TWGradients>()!,
      parentTheme.extension<TWLayoutTokens>()!,
    ],
  );
}

class WatchHistorySettingsView extends StatelessWidget {
  const WatchHistorySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<WatchHistoryController>()
        ? Get.find<WatchHistoryController>()
        : Get.put(WatchHistoryController());

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
                onPressed: () => Get.back(),
              ),
            ),
            body: SafeArea(
              child: ListView(
                children: [
                  _buildHeader(context),
                  const Divider(color: Colors.white10),
                  _buildControlSection(context, controller),
                  const Divider(color: Colors.white10),
                  _buildDeleteSection(context, controller),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage your viewing history',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'History helps you find videos you\'ve watched and improves your recommendations.',
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: context.colors.textSecondary,
            ),
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
              color: Colors.white,
            ),
            title: Text(
              controller.isHistoryPaused.value
                  ? 'Resume watch history'
                  : 'Pause watch history',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            onTap: controller.toggleHistoryPaused,
          ),
        ),
        ListTile(
          leading: Icon(Icons.list_alt_rounded, color: Colors.white),
          title: Text(
            'View full history',
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          onTap: () {
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().onSideNavItemSelect(HomeController.indexHistory);
              Get.back(); // Go back to settings
              Get.back(); // Go back to library/home
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
          onTap: () => _confirmDelete(
            context,
            'yesterday',
            controller.deleteYesterday,
          ),
        ),
        _buildDeleteTile(
          context,
          'Delete this week',
          Icons.calendar_view_week_outlined,
          onTap: () => _confirmDelete(
            context,
            'this week',
            controller.deleteThisWeek,
          ),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'To delete a particular video, use the "View full history" option above.',
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.white54,
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
        style: GoogleFonts.roboto(
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
        color: isError ? context.colors.error : Colors.white,
      ),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isError ? context.colors.error : Colors.white,
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDelete(BuildContext context, String label, VoidCallback onConfirm) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Delete History?',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete your watch history from $label?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              onConfirm();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final bool isDashboard;
  const SettingsScreen({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
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
        }
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
            Get.find<HomeController>().sideNavSelectedIndex.value = HomeController.indexLibrary;
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
          // Account Section
          _buildSection(
            context,
            title: 'Account',
            settings: [
              _buildUserInfoTile(context),
              _buildWatchHistoryTile(context),
              _buildLogoutTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),
          // Privacy Section
          _buildSection(
            context,
            title: 'Privacy',
            settings: [
              _buildPrivacyTile(context),
              _buildDataTile(context),
              _buildDeleteAccountTile(context),
            ],
          ),
          SizedBox(height: context.layoutSpacing),
          // Legal Section
          _buildSection(
            context,
            title: 'Legal',
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
            ],
          ),
          SizedBox(height: context.layoutSpacing),
          // About Section
          _buildSection(
            context,
            title: 'About',
            settings: [
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
        border: Border.all(color: context.colors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(context.layoutSpacing),
            child: Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ...settings,
        ],
      ),
    );
  }

  Widget _buildUserInfoTile(BuildContext context) {
    final authService = AuthService.to;
    return Obx(() {
      final displayName = authService.activeDisplayName;
      final handleOrEmail = authService.hasChannel.value && authService.userChannel != null
          ? authService.activeHandle
          : (authService.user?.email ?? '');

      return ListTile(
        leading: UserAvatar(
          radius: 20,
          photoUrl: authService.activePhotoUrl,
          displayName: displayName,
        ),
        title: Text(
          displayName,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          handleOrEmail,
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: context.colors.textSecondary,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.white),
        onTap: () {
          // Navigate to profile
        },
      );
    });
  }

  Widget _buildWatchHistoryTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.history, color: context.colors.brand),
      title: Text(
        'Watch history',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {
        Get.to(() => const WatchHistorySettingsView());
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.logout, color: context.colors.error),
      title: Text(
        'Log Out',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: context.colors.error,
        ),
      ),
      onTap: () => _showLogoutConfirmation(context),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Log Out', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await AuthService.to.logout();
              Get.offAllNamed('/');
            },
            child: Text('Log Out', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.lock, color: context.colors.brand),
      title: Text(
        'Privacy',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {
        // Open privacy settings
      },
    );
  }

  Widget _buildDataTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.data_usage, color: context.colors.brand),
      title: Text(
        'Data Usage',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {
        // Open data usage settings
      },
    );
  }

  Widget _buildVersionTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.info, color: context.colors.brand),
      title: Text(
        'Version',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        '1.0.0',
        style: GoogleFonts.roboto(
          fontSize: 14,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildHelpTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.help, color: context.colors.brand),
      title: Text(
        'Help & Support',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(HomeController.indexHelp);
        } else {
          Get.toNamed('/help');
        }
      },
    );
  }

  Widget _buildFeedbackTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.chat_bubble_outline, color: context.colors.brand),
      title: Text(
        'Feedback',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(HomeController.indexFeedback);
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
      leading: Icon(icon, color: context.colors.brand),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(index);
        } else {
          Get.toNamed(route);
        }
      },
    );
  }

  Widget _buildDeleteAccountTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
      title: Text(
        'Delete Account',
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.redAccent,
        ),
      ),
      subtitle: Text(
        'Permanently remove your account',
        style: GoogleFonts.roboto(
          fontSize: 14,
          color: context.colors.textSecondary,
        ),
      ),
      onTap: () => _showDeleteAccountConfirmation(context),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Delete Account', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthService.to.deleteAccount();
                Get.offAllNamed('/');
                Get.snackbar(
                  'Account Deleted',
                  'Your account has been successfully deleted.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Could not delete account. You may need to re-authenticate.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}






