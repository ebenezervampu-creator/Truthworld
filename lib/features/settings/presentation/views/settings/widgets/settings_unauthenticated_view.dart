import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Screen displayed when an unauthenticated user attempts to view Settings.
///
/// Ensures the Settings page, account details, and logout controls are never
/// exposed to unsigned users on any device (mobile, tablet, desktop, or web).
class SettingsUnauthenticatedView extends StatelessWidget {
  const SettingsUnauthenticatedView({
    super.key,
    this.isDashboard = false,
  });

  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSecurityIcon(context),
                  const SizedBox(height: 28),
                  Text(
                    'Sign In to Access Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your account preferences, privacy controls, playback customization, and security options require a signed-in account.',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  _buildSignInButton(context),
                  const SizedBox(height: 16),
                  _buildBackOrHomeButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (isDashboard) return null;

    final colors = context.colors;
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: colors.textPrimary,
        ),
        tooltip: 'Back',
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Get.offAllNamed('/');
          }
        },
      ),
      title: Text(
        'Settings',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSecurityIcon(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.4),
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
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          AuthBottomSheet.show(context);
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
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildBackOrHomeButton(BuildContext context) {
    final colors = context.colors;
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        if (isDashboard && Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().sideNavSelectedIndex.value =
              HomeController.indexHome;
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Get.offAllNamed('/');
        }
      },
      icon: Icon(
        isDashboard ? Icons.home_rounded : Icons.arrow_back_rounded,
        size: 18,
        color: colors.textSecondary,
      ),
      label: Text(
        isDashboard ? 'Return to Home' : 'Go Back',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}
