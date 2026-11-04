import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Screen displayed when user is not authenticated in Library.
class LibraryUnauthenticatedView extends StatelessWidget {
  const LibraryUnauthenticatedView({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: EdgeInsets.all(isDesktop ? 40 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(),
                const SizedBox(height: 32),
                _buildTitle(),
                const SizedBox(height: 16),
                _buildSubtitle(),
                const SizedBox(height: 40),
                _buildSignInButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.lock_outline_rounded,
                color: primaryText,
                size: 60,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Access Your Personal Video Library',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryText,
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Sign in to view your saved videos, watch history, and custom playlists. Your content is waiting!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16, color: secondaryText),
    );
  }

  Widget _buildSignInButton() {
    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        AuthService.to.triggerPlatformSignIn();
      },
      icon: const Icon(Icons.login_rounded, color: Colors.black),
      label: const Text(
        'Sign In to Continue',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
    );
  }
}
