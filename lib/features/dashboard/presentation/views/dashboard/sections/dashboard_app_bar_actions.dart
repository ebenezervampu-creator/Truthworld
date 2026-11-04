import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
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

  FocusNode? _resolveSafeFocusNode() {
    if (focusNode == null) return null;
    try {
      final _ = focusNode!.hasListeners;
      return focusNode;
    } catch (_) {
      return null;
    }
  }

  TextEditingController _resolveSafeController() {
    try {
      final _ = searchController.hasListeners;
      return searchController;
    } catch (_) {
      return TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveController = _resolveSafeController();
    final effectiveFocusNode = _resolveSafeFocusNode();

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
        controller: effectiveController,
        focusNode: effectiveFocusNode,
        maxLength: 100,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: TruthworldTextInputFormatters.withLimit(100),
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
            valueListenable: effectiveController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: () {
                  effectiveController.clear();
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
  final bool isLoading;
  final String? tooltip;
  final int badgeCount;

  const DashboardActionButton({
    required this.icon,
    required this.onPressed,
    required this.isDarkMode,
    this.label = '',
    this.isPrimary = false,
    this.isLoading = false,
    this.tooltip,
    this.badgeCount = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Zero White-on-White Policy: On white/brand surface, text and icon MUST be black!
    final bgColor = isPrimary ? AppColors.brand : AppColors.bgSurface;
    final fgColor = isPrimary ? Colors.black : AppColors.textPrimary;
    final iconColor = isPrimary ? Colors.black : Colors.white;

    if (label.isEmpty) {
      final buttonContent = Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isLoading
              ? null
              : () {
                  onPressed();
                  HapticFeedback.lightImpact();
                },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(icon, color: iconColor, size: 20),
          ),
        ),
      );

      Widget result = buttonContent;
      if (badgeCount > 0) {
        final countText = badgeCount > 99 ? '99+' : '$badgeCount';
        result = Stack(
          clipBehavior: Clip.none,
          children: [
            buttonContent,
            Positioned(
              top: -4,
              right: -4,
              child: IgnorePointer(
                child: Container(
                  padding: badgeCount > 9
                      ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5)
                      : const EdgeInsets.all(2),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0000), // Red notification badge
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.bgPage,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    countText,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return Semantics(
        button: true,
        label: tooltip ?? 'Action button',
        child: Tooltip(
          message: tooltip ?? '',
          child: result,
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
            onTap: isLoading
                ? null
                : () {
                    onPressed();
                    HapticFeedback.lightImpact();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  else
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
    return Obx(() {
      final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
      final isAuthed = auth?.isAuthenticated.value ?? false;

      if (!isAuthed) {
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

      final user = auth?.user ?? FirebaseAuth.instance.currentUser;
      final accountLabel = (auth?.activeDisplayName.isNotEmpty ?? false)
          ? auth!.activeDisplayName
          : (user?.email ?? 'Account');

      return Semantics(
        button: true,
        label: 'Account: $accountLabel',
        child: Tooltip(
          message: accountLabel,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.bgDivider,
                width: 1.5,
              ),
            ),
            child: UserAvatar(
              radius: 16,
              photoUrl: auth?.activePhotoUrl ?? '',
              displayName: (auth?.activeDisplayName.isNotEmpty ?? false)
                  ? auth!.activeDisplayName
                  : (user?.email ?? 'U'),
              showBorder: false,
            ),
          ),
        ),
      );
    });
  }
}
