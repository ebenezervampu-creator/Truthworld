import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Fallback login prompt displayed when an unauthenticated user navigates to Creator Studio.
class DashboardFallbackLogin extends StatelessWidget {
  const DashboardFallbackLogin({
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Creator Studio',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please sign in to access your Creator Studio dashboard.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: const Text(
                  'Sign In with Google',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
