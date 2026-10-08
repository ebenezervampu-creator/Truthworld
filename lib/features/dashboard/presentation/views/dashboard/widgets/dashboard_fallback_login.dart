import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Fallback login prompt displayed when an unauthenticated user navigates to Creator Studio.
/// Matches 100% of the Consumer App Library unauthenticated styling.
class DashboardFallbackLogin extends StatelessWidget {
  const DashboardFallbackLogin({
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceHover,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.dashboard_rounded,
                      color: AppColors.textPrimary,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Access Creator Studio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in to manage your channel, publish content, view analytics, and monetize your creations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onSignIn();
                  },
                  icon: const Icon(
                    Icons.login_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                  label: const Text(
                    'Sign In to Continue',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
