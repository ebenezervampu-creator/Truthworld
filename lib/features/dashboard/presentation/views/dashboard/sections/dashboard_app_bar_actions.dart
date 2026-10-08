import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardSearchField extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode? focusNode;
  final bool isDarkMode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const DashboardSearchField({
    required this.searchController,
    required this.isDarkMode,
    this.focusNode,
    this.onChanged,
    this.onClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Search studio content',
      child: Container(
        width: 320,
        height: 40,
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: TextField(
        controller: searchController,
        focusNode: focusNode,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search studio content... (/)',
          hintStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textTertiary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: AppColors.textSecondary,
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
            horizontal: 14,
            vertical: 10,
          ),
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
    // Zero White-on-White Policy: On white/brand surface, text and icon MUST be black!
    final bgColor = isPrimary ? AppColors.brand : const Color(0xFF1E1E1E);
    final fgColor = isPrimary ? Colors.black : AppColors.textPrimary;
    final iconColor = isPrimary ? Colors.black : Colors.white;

    if (label.isEmpty) {
      return Semantics(
        button: true,
        label: tooltip ?? 'Action button',
        child: Tooltip(
          message: tooltip ?? '',
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                onPressed();
                HapticFeedback.lightImpact();
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: tooltip ?? label,
      child: Tooltip(
        message: tooltip ?? label,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
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
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: fgColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
      return Semantics(
        button: true,
        label: 'Sign in with Google',
        child: Tooltip(
          message: 'Sign in with Google',
          child: Material(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                onSignIn();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_circle,
                      color: Colors.black,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Sign in',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final accountLabel = AuthService.to.activeDisplayName.isNotEmpty
        ? AuthService.to.activeDisplayName
        : (user.email ?? 'Account');

    return Semantics(
      button: true,
      label: 'Account: $accountLabel',
      child: Tooltip(
        message: accountLabel,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.bgDivider,
              width: 1.5,
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
      ),
    );
  }
}
