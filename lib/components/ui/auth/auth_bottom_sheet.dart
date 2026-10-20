import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_sheet_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
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
  final AuthStep? initialStep;

  const AuthBottomSheet({
    super.key,
    this.customTitle,
    this.customSubtitle,
    this.platformOverride,
    this.isWebOverride,
    this.initialStep,
  });

  static bool _isOpen = false;
  static bool get isOpen => _isOpen;

  /// Displays the authentication bottom sheet modally without requiring [context].
  static Future<void> prompt({
    BuildContext? context,
    String? title,
    String? subtitle,
    TargetPlatform? platformOverride,
    bool? isWebOverride,
    AuthStep? initialStep,
  }) =>
      show(
        context ?? Get.context,
        title: title,
        subtitle: subtitle,
        platformOverride: platformOverride,
        isWebOverride: isWebOverride,
        initialStep: initialStep,
      );

  /// Displays the authentication bottom sheet modally.
  /// If [context] is null, falls back to [Get.context].
  static Future<void> show(
    BuildContext? context, {
    String? title,
    String? subtitle,
    TargetPlatform? platformOverride,
    bool? isWebOverride,
    AuthStep? initialStep,
  }) async {
    final effectiveContext = context ?? Get.context;
    if (effectiveContext == null) {
      await AuthService.to.signInWithGoogle();
      return;
    }
    if (_isOpen) return;
    _isOpen = true;
    final controller = Get.isRegistered<AuthSheetController>()
        ? Get.find<AuthSheetController>()
        : Get.put(AuthSheetController());
    if (initialStep != null) {
      controller.currentStep.value = initialStep;
    }

    try {
      await showModalBottomSheet<void>(
        context: effectiveContext,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AuthBottomSheet(
              customTitle: title,
              customSubtitle: subtitle,
              platformOverride: platformOverride,
              isWebOverride: isWebOverride,
              initialStep: initialStep,
            ),
          ),
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

    if (initialStep != null) {
      controller.currentStep.value = initialStep!;
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: AppColors.bgSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle indicator matching Notifications design
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.bgDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Dynamic content based on currentStep
                Obx(() {
                  switch (controller.currentStep.value) {
                    case AuthStep.languageSelection:
                      return _buildLanguageSelectionView(context, controller);
                    case AuthStep.languageNotice:
                      return _buildLanguageNoticeView(context, controller);
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 0. Language Selection View: Select primary language before sign-in
  // ─────────────────────────────────────────────────────────────
  Widget _buildLanguageSelectionView(
    BuildContext context,
    AuthSheetController controller,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          customTitle ?? 'Welcome to TruthWorld',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          customSubtitle ?? 'Please select your primary language to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Explanatory notice card with notifications surface theme
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF272727),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.language_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'TruthWorld currently consists exclusively of English channels and content. We are currently accepting English users while actively preparing support for more languages.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search languages field styled exactly as NotificationSearchBar
        TextField(
          controller: controller.languageSearchController,
          maxLength: defaultMaxSearchLength,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
          onChanged: controller.updateLanguageSearch,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search 130+ languages...',
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: Obx(() {
              if (controller.languageSearchQuery.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: controller.clearLanguageSearch,
              );
            }),
            filled: true,
            fillColor: const Color(0xFF272727),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Scrollable list of languages
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: Obx(() {
            final list = controller.filteredLanguages;
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No language matches "${controller.languageSearchQuery.value}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.bgDivider, height: 1),
              itemBuilder: (context, index) {
                final lang = list[index];
                final isEnglish = lang.code == 'en' ||
                    lang.name.toLowerCase() == 'english';

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isEnglish
                          ? AppColors.textPrimary.withValues(alpha: 0.1)
                          : const Color(0xFF272727),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '🌐',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        lang.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight:
                              isEnglish ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (lang.nativeName.isNotEmpty &&
                          lang.nativeName.toLowerCase() !=
                              lang.name.toLowerCase()) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${lang.nativeName})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: isEnglish
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Available',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF272727),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: const Text(
                            'Request',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                  onTap: () => controller.selectPrimaryLanguage(lang.name),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 0b. Language Notice View: Polite info & request for non-English users
  // ─────────────────────────────────────────────────────────────
  Widget _buildLanguageNoticeView(
    BuildContext context,
    AuthSheetController controller,
  ) {
    return Obx(() {
      final lang = controller.selectedLanguage.value ?? 'Your Language';
      final isSubmitted = controller.isLanguageRequestSubmitted.value;
      final isSubmitting = controller.isSubmittingLanguageRequest.value;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigation header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: controller.goToLanguageSelection,
                tooltip: 'Back to language selection',
              ),
              const SizedBox(width: 4),
              Text(
                '$lang Support',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Polite notice box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF272727),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TruthWorld is Currently in English',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Thank you so much for your interest in TruthWorld!\n\nAt this time, TruthWorld consists exclusively of English channels and verified content. Because of this, we are currently only accepting English users.\n\nWe would love to bring TruthWorld to $lang in the future. You can submit a request below and our team will prioritize adding channels in your language.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Request card or confirmation
          if (!isSubmitted) ...[
            TextField(
              controller: controller.requestEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Email address (optional, for notifications)',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFF272727),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => controller.submitLanguageRequest(lang),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          size: 18,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Request $lang Channels',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF272727),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Request recorded for $lang! We will notify you when channels become available.',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Option: Continue in English
          OutlinedButton(
            onPressed: controller.continueWithEnglish,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.bgDivider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue in English with Google',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          TextButton(
            onPressed: controller.goToLanguageSelection,
            child: const Text(
              'Choose another language',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    });
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          customSubtitle ??
              'Sign in to explore verified content, save playlists, and connect with creators.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),

        // Primary Language confirmation card with change option
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF272727),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primary Language: English',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'TruthWorld English Channels Active',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.goToLanguageSelection,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // iPhone / Apple: Apple Sign-In ONLY.
        // Android and Web: Google Sign-In ONLY.
        // Phone sign-in is removed for new users; phone number can be added & verified later in Settings.
        if (isApple) ...[
          _buildAppleButton(controller),
        ] else ...[
          _buildGoogleButton(controller),
        ],

        const SizedBox(height: 20),
        const Text(
          'By continuing, you agree to our Terms of Service & Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
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
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
          backgroundColor: AppColors.bgSurface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          side: const BorderSide(color: AppColors.bgDivider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        child: isThisAuthBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, size: 22, color: AppColors.textPrimary),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Apple',
                    style: TextStyle(
                      color: AppColors.textPrimary,
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
          backgroundColor: const Color(0xFF272727),
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          side: const BorderSide(color: AppColors.bgDivider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_iphone_rounded, size: 20, color: AppColors.textPrimary),
            SizedBox(width: 12),
            Text(
              'Continue with Phone',
              style: TextStyle(
                color: AppColors.textPrimary,
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
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Colors.white,
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
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: controller.isAuthBusy.value ? null : controller.goToOptions,
              tooltip: 'Back to options',
            ),
            const SizedBox(width: 4),
            const Text(
              'Enter phone number',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'We will send a 6-digit verification code to your mobile device via SMS.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(8),
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
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                maxLength: 15,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF272727),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Send Code Button
        Obx(() {
          final isAuthBusy = controller.isAuthBusy.value;
          return ElevatedButton(
            onPressed: isAuthBusy ? null : controller.sendVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                : const Text(
                    'Send Verification Code',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
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
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed:
                  controller.isAuthBusy.value ? null : controller.changePhoneNumber,
              tooltip: 'Change phone number',
            ),
            const SizedBox(width: 4),
            const Text(
              'Enter 6-digit code',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          );
        }),
        const SizedBox(height: 20),

        // OTP text input
        TextField(
          controller: controller.otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 22,
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: const Color(0xFF272727),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textPrimary),
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
                child: const Text(
                  'Resend SMS Code',
                  style: TextStyle(
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
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            );
          }
        }),
        const SizedBox(height: 16),

        // Verify & Sign In Button
        Obx(() {
          final isAuthBusy = controller.isAuthBusy.value;
          return ElevatedButton(
            onPressed: isAuthBusy ? null : controller.verifyOtpAndSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                : const Text(
                    'Verify & Sign In',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    color: AppColors.bgDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Select Country / Region',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Search input matching notifications search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller.countrySearchController,
                    maxLength: defaultMaxSearchLength,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
                    onChanged: controller.updateCountrySearch,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search country or code...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
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
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: controller.clearCountrySearch,
                        );
                      }),
                      filled: true,
                      fillColor: const Color(0xFF272727),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.textPrimary),
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
                            style: const TextStyle(
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
                            style: TextStyle(
                              color: isSelected ? AppColors.brand : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.dialCode,
                                style: TextStyle(
                                  color: isSelected ? AppColors.brand : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.textPrimary,
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
