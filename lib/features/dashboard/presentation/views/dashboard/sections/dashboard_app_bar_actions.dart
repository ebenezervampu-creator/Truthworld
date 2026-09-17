import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardSearchField extends StatelessWidget {
  final TextEditingController searchController;
  final bool isDarkMode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const DashboardSearchField({
    required this.searchController,
    required this.isDarkMode,
    this.onChanged,
    this.onClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius.lg),
        border: Border.all(
          color: AppColors.bgSurfaceContainerHighest,
        ),
      ),
      child: TextField(
        controller: searchController,
        style: TextStyle(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
          fontSize: 14,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search your content...',
          hintStyle: TextStyle(
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black,
                  size: 18,
                ),
                onPressed: () {
                  searchController.clear();
                  onClear?.call();
                },
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

class DashboardActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDarkMode;
  final String label;
  final bool isPrimary;
  final String? tooltip;

  const DashboardActionButton({
    required this.icon,
    required this.onPressed,
    required this.isDarkMode,
    this.label = '',
    this.isPrimary = false,
    this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? const Color(0xFF6366F1)
        : (isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9));
    final textColor = isPrimary
        ? AppColors.textPrimary
        : (isDarkMode ? AppColors.textPrimary : Colors.black);

    if (label.isEmpty) {
      return Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          elevation: isPrimary ? 2 : 0,
          shadowColor: isPrimary
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              onPressed();
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        elevation: isPrimary ? 2 : 0,
        shadowColor: isPrimary
            ? const Color(0xFF6366F1).withValues(alpha: 0.3)
            : Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            onPressed();
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

class DashboardGoogleAccountSelector extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onSignIn;

  const DashboardGoogleAccountSelector({
    required this.isDarkMode,
    required this.onSignIn,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Tooltip(
        message: 'Sign in with Google',
        child: Material(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          shadowColor: AppColors.bgPage.withValues(alpha: 0.1),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              onSignIn();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/google_logo.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.account_circle,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sign in',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: AuthService.to.activeDisplayName.isNotEmpty
          ? ' ()'
          : (user.email ?? 'Account'),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
            width: 2,
          ),
        ),
        child: UserAvatar(
          radius: 16,
          photoUrl: AuthService.to.activePhotoUrl,
          displayName: AuthService.to.activeDisplayName.isNotEmpty
              ? AuthService.to.activeDisplayName
              : (user.email ?? 'U'),
          showBorder: false,
        ),
      ),
    );
  }
}
