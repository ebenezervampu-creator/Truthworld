import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';

import 'package:truthworld/components/ui/user_avatar.dart';

// Constants for consistent styling
const double kBorderRadius = 16.0;
const double kSmallPadding = 8.0;
const double kMediumPadding = 16.0;
const double kLargePadding = 24.0;

class SettingsScreen extends StatelessWidget {
  final bool isDashboard;
  const SettingsScreen({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: !isDashboard ? _buildAppBar(context, colorScheme) : null,
          body: _buildBody(context, colorScheme),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: Text(
        'Settings',
        style: AppTextStyles.headlineSmall.copyWith(
          fontSize:
              (AppTextStyles.headlineSmall.fontSize ?? 24) * context.fontScale,
          color: colorScheme.onSurface,
        ),
      ),
      backgroundColor: colorScheme.surface,
      elevation: 0,
      centerTitle: context.isMobile,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: colorScheme.onSurface,
          size: context.isMobileSmall ? 20 : 24,
        ),
        onPressed: () => Get.back(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    return ResponsiveContainer(
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.spacing),
        children: [
          // Account Section
          _buildSection(
            context,
            title: 'Account',
            colorScheme: colorScheme,
            settings: [_buildUserInfoTile(context, colorScheme)],
          ),
          SizedBox(height: context.spacing),
          // Appearance Section
          _buildSection(
            context,
            title: 'Appearance',
            colorScheme: colorScheme,
            settings: [
              _buildThemeTile(context, colorScheme),
              _buildLanguageTile(context, colorScheme),
            ],
          ),
          SizedBox(height: context.spacing),
          // Privacy Section
          _buildSection(
            context,
            title: 'Privacy',
            colorScheme: colorScheme,
            settings: [
              _buildPrivacyTile(context, colorScheme),
              _buildDataTile(context, colorScheme),
              _buildDeleteAccountTile(context, colorScheme),
            ],
          ),
          SizedBox(height: context.spacing),
          // About Section
          _buildSection(
            context,
            title: 'About',
            colorScheme: colorScheme,
            settings: [
              _buildVersionTile(context, colorScheme),
              _buildHelpTile(context, colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required ColorScheme colorScheme,
    required List<Widget> settings,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.spacing),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(context.isMobileSmall ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(context.spacing),
            child: Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontSize:
                    (AppTextStyles.titleMedium.fontSize ?? 18) *
                    context.fontScale,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ...settings,
        ],
      ),
    );
  }

  Widget _buildUserInfoTile(BuildContext context, ColorScheme colorScheme) {
    final user = FirebaseAuth.instance.currentUser;
    return ListTile(
      leading: UserAvatar(
        radius: 20,
        photoUrl: user?.photoURL,
        displayName: user?.displayName,
      ),
      title: Text(
        user?.displayName ?? 'User',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      subtitle: Text(
        user?.email ?? '',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize:
              (AppTextStyles.bodySmall.fontSize ?? 12) * context.fontScale,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
      onTap: () {
        // Navigate to profile
      },
    );
  }

  Widget _buildThemeTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.palette, color: colorScheme.primary),
      title: Text(
        'Theme',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      subtitle: Text(
        'Dark Mode',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize:
              (AppTextStyles.bodySmall.fontSize ?? 12) * context.fontScale,
        ),
      ),
      trailing: Switch(
        value: Theme.of(context).brightness == Brightness.dark,
        onChanged: (value) {
          // Toggle theme
        },
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.language, color: colorScheme.primary),
      title: Text(
        'Language',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      subtitle: Text(
        'English',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize:
              (AppTextStyles.bodySmall.fontSize ?? 12) * context.fontScale,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
      onTap: () {
        // Change language
      },
    );
  }

  Widget _buildPrivacyTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.lock, color: colorScheme.primary),
      title: Text(
        'Privacy',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
      onTap: () {
        // Open privacy settings
      },
    );
  }

  Widget _buildDataTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.data_usage, color: colorScheme.primary),
      title: Text(
        'Data Usage',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
      onTap: () {
        // Open data usage settings
      },
    );
  }

  Widget _buildVersionTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.info, color: colorScheme.primary),
      title: Text(
        'Version',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      subtitle: Text(
        '1.0.0',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize:
              (AppTextStyles.bodySmall.fontSize ?? 12) * context.fontScale,
        ),
      ),
    );
  }

  Widget _buildHelpTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.help, color: colorScheme.primary),
      title: Text(
        'Help & Support',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize:
              (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
      onTap: () {
        // Open help
      },
    );
  }

  Widget _buildDeleteAccountTile(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
      title: Text(
        'Delete Account',
        style: AppTextStyles.bodyLarge.copyWith(
          fontSize: (AppTextStyles.bodyLarge.fontSize ?? 16) * context.fontScale,
          color: Colors.redAccent,
        ),
      ),
      subtitle: Text(
        'Permanently remove your account',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: (AppTextStyles.bodySmall.fontSize ?? 12) * context.fontScale,
        ),
      ),
      onTap: () => _showDeleteAccountConfirmation(context),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthService.to.deleteAccount();
                Get.offAllNamed('/home');
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

class ModernSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> settings;

  const ModernSettingsSection({
    super.key,
    required this.title,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: kMediumPadding,
      ), // Spacing between sections
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kLargePadding,
              vertical: kSmallPadding,
            ),
            child: Text(
              title,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: colorScheme.primary, // Section title color
              ),
            ),
          ),
          // Use Column to ensure proper layout and prevent overflow for settings list
          Column(
            children: settings
                .map(
                  (setting) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kMediumPadding,
                      vertical: 2,
                    ), // Padding for each tile
                    child: setting,
                  ),
                )
                .toList(),
          ),
          Divider(
            indent: kMediumPadding,
            endIndent: kMediumPadding,
            color: colorScheme.outline.withValues(alpha: 0.2),
            thickness: 1,
            height: kMediumPadding * 1.5, // Spacing around divider
          ),
        ],
      ),
    );
  }
}

class ModernSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const ModernSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero, // Remove default card margin
      color: AppTheme.secondaryBackground.withValues(
        alpha: 0.2,
      ), // Subtle background for tile
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          kBorderRadius / 2,
        ), // Slightly rounded corners
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kBorderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: kSmallPadding,
            horizontal: kMediumPadding,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: colorScheme.primary,
                size: 24,
              ), // Primary color for icons
              const SizedBox(width: kMediumPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: kMediumPadding),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ), // Rounded arrow
            ],
          ),
        ),
      ),
    );
  }
}

class ModernSwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ModernSwitchSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.secondaryBackground.withValues(alpha: 0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kBorderRadius / 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: kSmallPadding,
          horizontal: kMediumPadding,
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(width: kMediumPadding),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: colorScheme.primary,
              inactiveThumbColor: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.6,
              ),
              inactiveTrackColor: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.2,
              ),
              activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}





