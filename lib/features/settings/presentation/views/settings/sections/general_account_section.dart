import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/email_verification_sheet.dart';
import 'package:truthworld/components/ui/auth/phone_verification_sheet.dart';
import 'package:truthworld/components/ui/avatar_options_sheet.dart';
import 'package:truthworld/components/ui/google_onboarding_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class GeneralAccountSection extends StatelessWidget {
  const GeneralAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAuth = Get.isRegistered<AuthService>() &&
          AuthService.to.isAuthenticated.value;
      if (!isAuth) {
        return const SizedBox.shrink();
      }

      return SettingsSectionCard(
        title: 'General & Account',
        children: [
          _buildUserInfoTile(context),
          _buildPhoneVerificationTile(context),
          _buildEmailVerificationTile(context),
          _buildAgeAndGenderTile(context),
          _buildSubscriptionTile(context),
          _buildWalletTile(context),
          _buildAccountStatusTile(context),
          _buildLogoutTile(context),
        ],
      );
    });
  }

  Widget _buildUserInfoTile(BuildContext context) {
    final authService = AuthService.to;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(() {
          // Explicit reactive reads ensure instant live UI re-rendering
          final liveName = authService.userDisplayName.value;
          final liveHandle = authService.userHandle.value;
          final rawDisplayName = (liveName != null && liveName.trim().isNotEmpty)
              ? liveName.trim()
              : authService.activeDisplayName;
          final displayName = ContentValidator.cleanProfanity(rawDisplayName);
          final rawHandleOrEmail = (liveHandle != null && liveHandle.trim().isNotEmpty)
              ? (liveHandle.startsWith('@') ? liveHandle : '@$liveHandle')
              : (authService.activeHandle.isNotEmpty && authService.activeHandle != '@user'
                  ? authService.activeHandle
                  : (authService.user?.email ?? ''));
          final handleOrEmail = ContentValidator.cleanProfanity(rawHandleOrEmail);

          final genderText = authService.userGender.value ?? 'Not specified';
          final ageText = authService.userAge.value != null
              ? '${authService.userAge.value} yrs'
              : (authService.userAgeGroup.value != null &&
                      authService.userAgeGroup.value!.isNotEmpty)
                  ? authService.userAgeGroup.value!
                  : 'Not specified';
          final locationText = authService.userLocation.value ?? 'Not specified';

          return ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  radius: 22,
                  photoUrl: authService.activePhotoUrl,
                  displayName: displayName,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: () => _showAvatarOptionsSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 0.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.greenAccent, size: 6),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '$handleOrEmail • $genderText • $ageText • Location: $locationText',
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
            trailing: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            onTap: () => _showEditProfileDialog(context),
          );
        }),
        Obx(() => _buildAvatarStatusNotice(context)),
      ],
    );
  }

  Widget _buildAvatarStatusNotice(BuildContext context) {
    final auth = AuthService.to;
    final status = auth.userAvatarStatus.value ?? '';
    final reason = auth.userAvatarStatusReason.value ?? '';

    if (status.isEmpty || status == 'APPROVED') {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color borderColor;
    IconData icon;
    String title;
    String description;
    var isPending = false;

    if (status == 'PENDING') {
      bgColor = AppColors.info.withValues(alpha: 0.12);
      borderColor = AppColors.info.withValues(alpha: 0.3);
      icon = Icons.sync;
      title = 'Avatar Verification In Progress';
      description =
          'Google Cloud Vision AI is validating your avatar for safety standards...';
      isPending = true;
    } else if (status == 'REJECTED') {
      bgColor = AppColors.error.withValues(alpha: 0.12);
      borderColor = AppColors.error.withValues(alpha: 0.3);
      icon = Icons.error_outline;
      title = 'Avatar Rejected by Vision AI';
      description = reason.isNotEmpty
          ? reason
          : 'This avatar does not comply with safety guidelines. Tap Replace to choose another photo.';
    } else if (status == 'FLAGGED' || status == 'MANUAL_REVIEW') {
      bgColor = AppColors.warning.withValues(alpha: 0.12);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      icon = Icons.warning_amber_rounded;
      title = 'Avatar Under Moderation Review';
      description =
          'Your avatar has been flagged for human admin moderation in the Admin Portal.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (isPending)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'REJECTED') ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showAvatarOptionsSheet(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Replace',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAvatarOptionsSheet(BuildContext context) {
    AvatarOptionsSheet.show(context);
  }

  Widget _buildPhoneVerificationTile(BuildContext context) {
    final authService = AuthService.to;
    return Obx(() {
      final isVerified = authService.isPhoneVerified.value;
      final phone = authService.userPhoneNumber.value;
      final displayPhone = (phone != null && phone.trim().isNotEmpty)
          ? phone.trim()
          : (authService.user?.phoneNumber ?? '');

      if (isVerified && displayPhone.isNotEmpty) {
        return ListTile(
          leading: const Icon(
            Icons.phone_android_rounded,
            color: Colors.white,
          ),
          title: const Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            displayPhone,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'Phone number verified',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          onTap: () => PhoneVerificationSheet.show(context),
        );
      }

      final hasPhone = displayPhone.isNotEmpty;
      return ListTile(
        leading: const Icon(
          Icons.phone_iphone_rounded,
          color: AppColors.textPrimary,
        ),
        title: Text(
          hasPhone ? 'Verify Phone Number' : 'Add Phone Number',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          hasPhone
              ? '$displayPhone • Tap to verify'
              : 'Add and verify mobile number for enhanced security',
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => PhoneVerificationSheet.show(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            hasPhone ? 'Verify' : 'Add',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => PhoneVerificationSheet.show(context),
      );
    });
  }

  Widget _buildEmailVerificationTile(BuildContext context) {
    final authService = AuthService.to;
    return Obx(() {
      final isVerified = authService.isEmailVerified.value;
      final email = authService.userEmail.value;
      final displayEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : (authService.user?.email ?? '');

      if (isVerified && displayEmail.isNotEmpty) {
        return ListTile(
          leading: const Icon(
            Icons.mark_email_read_outlined,
            color: Colors.white,
          ),
          title: const Text(
            'Email Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            displayEmail,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'Email verified',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          onTap: () => EmailVerificationSheet.show(context),
        );
      }

      return ListTile(
        leading: const Icon(
          Icons.mail_outline_rounded,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          displayEmail.isNotEmpty
              ? '$displayEmail • Tap to verify'
              : 'Add and verify email address to secure your account',
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => EmailVerificationSheet.show(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Verify',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => EmailVerificationSheet.show(context),
      );
    });
  }

  Widget _buildAgeAndGenderTile(BuildContext context) {
    final authService = AuthService.to;
    return Obx(() {
      final ageGroup = authService.userAgeGroup.value;
      final gender = authService.userGender.value;

      final infoParts = <String>[];
      if (ageGroup != null && ageGroup.isNotEmpty) {
        infoParts.add('Age: $ageGroup');
      }
      if (gender != null && gender.isNotEmpty) {
        infoParts.add('Gender: $gender');
      }

      final subtitleText = infoParts.isNotEmpty
          ? infoParts.join(' • ')
          : 'Not set — Tap to add age group and gender for recommendations';

      return ListTile(
        leading: const Icon(
          Icons.face_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Age Group & Gender',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textPrimary,
        ),
        onTap: () => GoogleOnboardingSheet.show(context),
      );
    });
  }

  void _showEditProfileDialog(BuildContext context) {
    Get.toNamed('/settings/edit-profile');
  }

  Widget _buildSubscriptionTile(BuildContext context) {
    final auth = AuthService.to;
    return Obx(() {
      final isPremium = auth.isPremiumUser.value;
      return ListTile(
        leading: Icon(
          isPremium ? Icons.workspace_premium : Icons.card_membership,
          color: isPremium ? Colors.amber : AppColors.textPrimary,
        ),
        title: Text(
          isPremium ? 'Premium Membership Active' : 'Free Account Tier',
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          isPremium
              ? 'Ad-free 4K & background playback'
              : 'Upgrade to Premium for 4K & ad-free streaming',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => Get.toNamed('/premium'),
      );
    });
  }

  Widget _buildWalletTile(BuildContext context) {
    final auth = AuthService.to;
    return Obx(() {
      final hasChannel = auth.hasChannel.value;
      if (!hasChannel) {
        return const SizedBox.shrink();
      }
      return ListTile(
        leading: const Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Channel Wallet',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Creator earnings, infrastructure & AI tools wallet in Studio',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => Get.toNamed('/dashboard'),
      );
    });
  }

  Widget _buildAccountStatusTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.no_accounts_outlined, color: Colors.white),
      title: const Text(
        'Account Deactivation & Status',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        'Temporarily pause account or delete permanently',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () => _showAccountStatusOptions(context),
    );
  }

  void _showAccountStatusOptions(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Account Status Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.pause_circle_outline,
                color: AppColors.warning,
              ),
              title: const Text(
                'Deactivate Account',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Temporarily hide channel & activity.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Get.back();
                _showDeactivateAccountConfirmation(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete Account Permanently',
                style: TextStyle(color: AppColors.error),
              ),
              subtitle: const Text(
                'Irreversible removal of account data.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Get.back();
                _showDeleteAccountConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateAccountConfirmation(BuildContext context) {
    final colors = context.colors;
    final isProcessing = false.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Deactivate Account',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to deactivate your account? Your channel, public profile, and activity will be hidden until you sign back in. You can reactivate anytime simply by logging back in.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          Obx(
            () => TextButton(
              onPressed: isProcessing.value
                  ? null
                  : () async {
                      try {
                        isProcessing.value = true;
                        await AuthService.to.deactivateAccount();
                        Get.offAllNamed('/');
                        AppSnackbar.info(
                          'Your account has been deactivated. You can sign back in anytime to reactivate it.',
                        );
                      } catch (e) {
                        isProcessing.value = false;
                        Get.back();
                        ErrorHandler.log(e);
                        AppSnackbar.error(
                          'Unable to deactivate account. Please try again.',
                        );
                      }
                    },
              child: isProcessing.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.warning,
                      ),
                    )
                  : const Text(
                      'Deactivate',
                      style: TextStyle(color: AppColors.warning),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    final isAuth = Get.isRegistered<AuthService>() &&
        AuthService.to.isAuthenticated.value;
    if (!isAuth) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Icon(Icons.logout, color: context.colors.error),
      title: Text(
        'Log Out',
        style: TextStyle(fontSize: 16, color: context.colors.error),
      ),
      onTap: () => _showLogoutConfirmation(context),
    );
  }

  // ================= 2. DIGITAL WELLBEING TILES =================

  void _showDeleteAccountConfirmation(BuildContext context) {
    final colors = context.colors;
    final isPasswordProvider = AuthService.to.primaryAuthProvider == 'password';
    final passwordController = TextEditingController();
    final isProcessing = false.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Delete Account Permanently',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account? This action is irreversible and will permanently delete your channel, content, and profile data.',
              style: TextStyle(color: colors.textSecondary),
            ),
            if (isPasswordProvider) ...[
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  hintText: 'Enter your password to verify',
                  hintStyle: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colors.error),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'For your security, you may be prompted to verify your Google identity before deletion proceeds.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: colors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          Obx(
            () => TextButton(
              onPressed: isProcessing.value
                  ? null
                  : () async {
                      if (isPasswordProvider &&
                          passwordController.text.trim().isEmpty) {
                        AppSnackbar.warning(
                          'Please enter your password to confirm deletion.',
                        );
                        return;
                      }

                      try {
                        isProcessing.value = true;
                        await AuthService.to.deleteAccount(
                          password: passwordController.text.trim(),
                        );
                        Get.offAllNamed('/');
                        AppSnackbar.success(
                          'Your account has been permanently deleted.',
                        );
                      } catch (e) {
                        isProcessing.value = false;
                        Get.back();
                        final errStr = e.toString().toLowerCase();
                        if (errStr.contains('cancelled') ||
                            errStr.contains('canceled') ||
                            errStr.contains('user-cancelled')) {
                          AppSnackbar.info(
                            'Account deletion was cancelled.',
                          );
                        } else {
                          ErrorHandler.log(e);
                          AppSnackbar.error(
                            'Unable to delete account. Please try again.',
                          );
                        }
                      }
                    },
              child: isProcessing.value
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.error,
                      ),
                    )
                  : Text(
                      'Delete',
                      style: TextStyle(color: colors.error),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final colors = context.colors;
    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Log Out', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await AuthService.to.logout();
              Get.offAllNamed('/');
            },
            child: Text('Log Out', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }
}
