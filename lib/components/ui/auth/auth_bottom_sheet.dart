import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/auth/auth_sheet_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet presenting platform-tailored authentication options for new & returning users:
/// - Android: Google Sign-In only (phone removed for new users; can be added & verified later in Settings).
/// - iPhone (iOS / macOS): Apple Sign-In only (phone removed for new users; can be added & verified later in Settings).
/// - Web: Google Sign-In only (phone removed for new users; can be added & verified later in Settings).
class AuthBottomSheet extends StatelessWidget {
  final String? customTitle;
  final String? customSubtitle;
  final TargetPlatform? platformOverride;
  final bool? isWebOverride;

  const AuthBottomSheet({
    super.key,
    this.customTitle,
    this.customSubtitle,
    this.platformOverride,
    this.isWebOverride,
  });

  static bool _isOpen = false;
  static bool get isOpen => _isOpen;

  /// Displays the authentication bottom sheet modally.
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    TargetPlatform? platformOverride,
    bool? isWebOverride,
  }) async {
    if (_isOpen) return;
    _isOpen = true;
    if (!Get.isRegistered<AuthSheetController>()) {
      Get.put(AuthSheetController());
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AuthBottomSheet(
          customTitle: title,
          customSubtitle: subtitle,
          platformOverride: platformOverride,
          isWebOverride: isWebOverride,
        ),
      );
    } finally {
      _isOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isOpen && Get.isRegistered<AuthSheetController>()) {
          Get.delete<AuthSheetController>();
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.isRegistered<AuthService>()) {
          final auth = AuthService.to;
          if (auth.isAuthenticated.value && auth.needsOnboarding.value) {
            auth.checkAndPromptOnboarding();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AuthSheetController>()
        ? Get.find<AuthSheetController>()
        : Get.put(AuthSheetController());

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Dynamic content based on currentStep
              Obx(() {
                switch (controller.currentStep.value) {
                  case AuthStep.options:
                    return _buildOptionsView(context, controller);
                  case AuthStep.phoneInput:
                    return _buildPhoneInputView(context, controller);
                  case AuthStep.otpVerification:
                    return _buildOtpVerificationView(context, controller);
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Main Options View: Platform-tailored sign-in options
  // ─────────────────────────────────────────────────────────────
  Widget _buildOptionsView(BuildContext context, AuthSheetController controller) {
    final runningOnWeb = isWebOverride ?? kIsWeb;
    final bool isApple;
    if (platformOverride != null) {
      isApple = AuthSheetController.isApplePlatform(platformOverride, runningOnWeb);
    } else if (runningOnWeb) {
      isApple = false;
    } else {
      isApple = AuthSheetController.isApplePlatform(Theme.of(context).platform, false);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          customTitle ?? 'Welcome to TruthWorld',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          customSubtitle ??
              'Sign in to explore verified content, save playlists, and connect with creators.',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // iPhone / Apple: Apple Sign-In ONLY.
        // Android and Web: Google Sign-In ONLY.
        // Phone sign-in is removed for new users; phone number can be added & verified later in Settings.
        if (isApple) ...[
          _buildAppleButton(controller),
        ] else ...[
          _buildGoogleButton(controller),
        ],

        const SizedBox(height: 24),
        Text(
          'By continuing, you agree to our Terms of Service & Privacy Policy.',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGoogleButton(AuthSheetController controller) {
    return Obx(() {
      final isThisAuthBusy =
          controller.isAuthBusy.value && controller.activeProvider.value == 'google';
      final isAnyLoading = controller.isAuthBusy.value;

      return ElevatedButton(
        key: const Key('auth_google_button'),
        onPressed: isAnyLoading ? null : controller.signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        child: isThisAuthBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGoogleIcon(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.roboto(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildAppleButton(AuthSheetController controller) {
    return Obx(() {
      final isThisAuthBusy =
          controller.isAuthBusy.value && controller.activeProvider.value == 'apple';
      final isAnyLoading = controller.isAuthBusy.value;

      return ElevatedButton(
        key: const Key('auth_apple_button'),
        onPressed: isAnyLoading ? null : controller.signInWithApple,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        child: isThisAuthBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apple, size: 22, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Apple',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildPhoneOptionButton(AuthSheetController controller) {
    return Obx(() {
      final isBusy = controller.isAuthBusy.value;
      return ElevatedButton(
        key: const Key('auth_phone_button'),
        onPressed: isBusy ? null : controller.goToPhoneInput,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bgElevated,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_iphone_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Continue with Phone',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Phone Input View
  // ─────────────────────────────────────────────────────────────
  Widget _buildPhoneInputView(
    BuildContext context,
    AuthSheetController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: controller.isAuthBusy.value ? null : controller.goToOptions,
              tooltip: 'Back to options',
            ),
            const SizedBox(width: 4),
            Text(
              'Enter phone number',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'We will send a 6-digit verification code to your mobile device via SMS.',
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Phone input row with Country code dropdown
        Row(
          children: [
            // Country picker button
            Obx(() {
              final country = controller.selectedCountry.value;
              return InkWell(
                onTap: controller.isAuthBusy.value
                    ? null
                    : () => _showCountryPicker(context, controller),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        country.dialCode,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(width: 10),

            // Number field
            Expanded(
              child: TextField(
                controller: controller.phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: GoogleFonts.roboto(
                    color: AppColors.textDisabled,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Send Code Button
        Obx(() {
          final isAuthBusy = controller.isAuthBusy.value;
          return ElevatedButton(
            onPressed: isAuthBusy ? null : controller.sendVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isAuthBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    'Send Verification Code',
                    style: GoogleFonts.roboto(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. OTP Verification View
  // ─────────────────────────────────────────────────────────────
  Widget _buildOtpVerificationView(
    BuildContext context,
    AuthSheetController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed:
                  controller.isAuthBusy.value ? null : controller.changePhoneNumber,
              tooltip: 'Change phone number',
            ),
            const SizedBox(width: 4),
            Text(
              'Enter 6-digit code',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          final dial = controller.selectedCountry.value.dialCode;
          final num = controller.phoneController.text.trim();
          return Text(
            'We sent a verification code to $dial $num',
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          );
        }),
        const SizedBox(height: 24),

        // OTP text input
        TextField(
          controller: controller.otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: GoogleFonts.robotoMono(
              color: AppColors.textDisabled,
              fontSize: 24,
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: AppColors.bgInput,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend countdown
        Obx(() {
          if (controller.canResend.value) {
            return Center(
              child: TextButton(
                onPressed:
                    controller.isAuthBusy.value ? null : controller.resendOtp,
                child: Text(
                  'Resend SMS Code',
                  style: GoogleFonts.roboto(
                    color: AppColors.textLink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          } else {
            return Center(
              child: Text(
                'Resend code in ${controller.resendCountdown.value}s',
                style: GoogleFonts.roboto(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            );
          }
        }),
        const SizedBox(height: 20),

        // Verify & Sign In Button
        Obx(() {
          final isAuthBusy = controller.isAuthBusy.value;
          return ElevatedButton(
            onPressed: isAuthBusy ? null : controller.verifyOtpAndSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isAuthBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    'Verify & Sign In',
                    style: GoogleFonts.roboto(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Country Code Picker Modal
  // ─────────────────────────────────────────────────────────────
  void _showCountryPicker(
    BuildContext context,
    AuthSheetController controller,
  ) {
    controller.clearCountrySearch();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Material(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Select Country / Region',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller.countrySearchController,
                  onChanged: controller.updateCountrySearch,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search country or code...',
                    hintStyle: GoogleFonts.roboto(
                      color: AppColors.textDisabled,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: Obx(() {
                      if (controller.countrySearchQuery.value.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: controller.clearCountrySearch,
                      );
                    }),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.bgDivider, height: 1),
              Expanded(
                child: Obx(() {
                  final list = controller.filteredCountries;
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No country matches "${controller.countrySearchQuery.value}"',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppColors.bgDivider, height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final isSelected =
                          controller.selectedCountry.value == item;
                      return ListTile(
                        leading: Text(
                          item.flagEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.dialCode,
                              style: GoogleFonts.roboto(
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          controller.selectCountry(item);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      );
    },
  );
  }
}
