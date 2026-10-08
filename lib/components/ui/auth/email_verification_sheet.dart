import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Controller managing email verification and Google account linking.
class EmailVerificationController extends BaseController {
  final RxBool isBusy = false.obs;
  final RxBool isEmailSent = false.obs;
  final RxString sentEmail = ''.obs;

  late final TextEditingController emailController =
      trackTextController(TextEditingController());

  @override
  void onInit() {
    super.onInit();
    final currentEmail = AuthService.to.user?.email ??
        AuthService.to.userEmail.value ??
        '';
    if (currentEmail.isNotEmpty) {
      emailController.text = currentEmail;
    }
  }

  /// 1-Tap Google linking & email verification
  Future<void> verifyWithGoogle() async {
    try {
      isBusy.value = true;
      await AuthService.to.linkGoogleEmail();
      isBusy.value = false;
      if (Get.isBottomSheetOpen == true) {
        Get.back();
      }
      AppSnackbar.success('Email verified successfully!');
    } on GoogleSignInException catch (e) {
      isBusy.value = false;
      if (e.code != 'user-cancelled') {
        AppSnackbar.error(e.displayMessage);
      }
    } catch (e, st) {
      isBusy.value = false;
      ErrorHandler.log(e, stackTrace: st, tag: 'EmailVerification.google');
      AppSnackbar.error(
        'Unable to link Google account. Please try again or use email verification.',
      );
    }
  }

  /// Send verification email link
  Future<void> sendVerificationEmail() async {
    final rawEmail = emailController.text.trim();
    if (rawEmail.isEmpty || !GetUtils.isEmail(rawEmail)) {
      AppSnackbar.info('Please enter a valid email address.');
      return;
    }

    try {
      isBusy.value = true;
      await AuthService.to.sendEmailVerification(email: rawEmail);
      sentEmail.value = rawEmail;
      isEmailSent.value = true;
      isBusy.value = false;
      AppSnackbar.success('Verification link sent to $rawEmail');
    } catch (e, st) {
      isBusy.value = false;
      ErrorHandler.log(e, stackTrace: st, tag: 'EmailVerification.send');
      AppSnackbar.error(
        'Unable to send verification email. Please check the address and try again.',
      );
    }
  }

  /// Check if the user has confirmed their email address
  Future<void> checkEmailVerified() async {
    try {
      isBusy.value = true;
      final verified = await AuthService.to.reloadAndCheckEmailVerified();
      isBusy.value = false;

      if (verified) {
        if (Get.isBottomSheetOpen == true) {
          Get.back();
        }
        AppSnackbar.success('Email verified successfully!');
      } else {
        AppSnackbar.info(
          'Email not yet verified. Please tap the link in your email and try again.',
        );
      }
    } catch (e, st) {
      isBusy.value = false;
      ErrorHandler.log(e, stackTrace: st, tag: 'EmailVerification.check');
      AppSnackbar.error('Unable to refresh verification status. Please try again.');
    }
  }
}

/// Bottom sheet dialog for verifying and linking an email address.
class EmailVerificationSheet extends StatelessWidget {
  const EmailVerificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmailVerificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EmailVerificationController());
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset > 0 ? bottomInset + 20 : 36,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verify Email',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: Get.back,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Add and verify your email to secure account recovery and access verified notifications.',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Google 1-Tap Option
            _buildGoogleOption(controller),

            const SizedBox(height: 20),

            // Divider
            Row(
              children: [
                const Expanded(
                  child: Divider(color: AppColors.bgDivider, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR VERIFY VIA EMAIL',
                    style: GoogleFonts.roboto(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: AppColors.bgDivider, thickness: 1),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Manual Email Form / Status
            Obx(() {
              if (controller.isEmailSent.value) {
                return _buildEmailSentView(controller);
              } else {
                return _buildEmailInputView(controller);
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleOption(EmailVerificationController controller) {
    return Obx(() {
      final isBusy = controller.isBusy.value;
      return ElevatedButton(
        onPressed: isBusy ? null : controller.verifyWithGoogle,
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
            Container(
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
            ),
            const SizedBox(width: 12),
            Text(
              'Verify with Google (1-Tap)',
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

  Widget _buildEmailInputView(EmailVerificationController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your email address',
            hintStyle: GoogleFonts.roboto(
              color: AppColors.textDisabled,
              fontSize: 15,
            ),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
            filled: true,
            fillColor: AppColors.bgInput,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
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
        const SizedBox(height: 20),

        // Send Link Button (White background, Black foreground)
        Obx(() {
          final isBusy = controller.isBusy.value;
          return ElevatedButton(
            onPressed: isBusy ? null : controller.sendVerificationEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    'Send Verification Link',
                    style: GoogleFonts.roboto(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildEmailSentView(EmailVerificationController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.greenAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Link Sent!',
                      style: GoogleFonts.roboto(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We sent a link to ${controller.sentEmail.value}. Tap the link in your inbox to confirm.',
                      style: GoogleFonts.roboto(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // "I've Verified My Email" Check Button
        Obx(() {
          final isBusy = controller.isBusy.value;
          return ElevatedButton(
            onPressed: isBusy ? null : controller.checkEmailVerified,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    "I've Verified My Email",
                    style: GoogleFonts.roboto(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        }),
        const SizedBox(height: 10),

        // Resend TextButton
        Center(
          child: TextButton(
            onPressed: controller.isBusy.value
                ? null
                : controller.sendVerificationEmail,
            child: Text(
              'Resend Verification Link',
              style: GoogleFonts.roboto(
                color: AppColors.textLink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
