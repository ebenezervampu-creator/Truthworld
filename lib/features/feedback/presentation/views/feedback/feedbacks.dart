import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SendFeedbackController extends BaseController with ContentValidationMixin {
  final formKey = GlobalKey<FormState>();
  final feedbackController = TextEditingController();
  final emailController = TextEditingController();
  final RxString feedbackType = 'General'.obs;
  final RxInt rating = 0.obs;
  final RxBool isSubmitting = false.obs;
  final RxString appVersion = 'Unknown'.obs;
  final RxMap<String, dynamic> deviceInfo = <String, dynamic>{}.obs;

  final List<String> feedbackTypes = [
    'Bug',
    'Feature Request',
    'General',
    'Other',
  ];

  @override
  void onInit() {
    super.onInit();
    trackTextController(feedbackController);
    trackTextController(emailController);
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null && user!.email!.isNotEmpty) {
      emailController.text = user.email!;
    }
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    appVersion.value = '${packageInfo.version}+${packageInfo.buildNumber}';

    var info = <String, dynamic>{};
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        info = {
          'os': 'Web',
          'browser': webInfo.browserName.toString(),
          'platform': webInfo.platform,
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        info = {
          'os': 'Android',
          'version': androidInfo.version.release,
          'model': androidInfo.model,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        info = {
          'os': 'iOS',
          'version': iosInfo.systemVersion,
          'model': iosInfo.model,
        };
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SendFeedbackController.initDeviceInfo');
    }
    deviceInfo.assignAll(info);
  }

  Future<void> submitFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.warning(
        'You must be signed in to submit feedback.',
        title: 'Sign In Required',
      );
      return;
    }

    if (!formKey.currentState!.validate() || isSubmitting.value) return;

    final text = feedbackController.text.trim();
    final validation = await validateContent(
      text,
      fieldName: 'Feedback',
      minLength: 5,
      maxLength: ContentValidator.defaultMaxFeedbackLength,
    );
    if (!validation.isValid) {
      AppSnackbar.warning(
        validation.message,
      );
      return;
    }

    isSubmitting.value = true;

    try {
      final userEmail = (user.email != null && user.email!.isNotEmpty)
          ? user.email!
          : 'unspecified';

      // Submit to Firestore (strictly authenticated)
      final feedbackData = {
        'userId': user.uid,
        'userEmail': userEmail,
        'feedbackType': feedbackType.value,
        'feedbackText': feedbackController.text.trim(),
        'rating': rating.value,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
        'appVersion': appVersion.value,
        'deviceInfo': Map<String, dynamic>.from(deviceInfo),
      };

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.feedback)
          .add(feedbackData);

      // Reset UI
      feedbackController.clear();
      rating.value = 0;

      AppSnackbar.success('Thank you for your feedback!');
      Get.back();
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to submit feedback. Please try again.');
    } finally {
      isSubmitting.value = false;
    }
  }
}

ThemeData _getTheme(BuildContext context) {
  final parentTheme = Theme.of(context);
  final parentColors = parentTheme.extension<TWColors>()!;
  final parentTypography = parentTheme.extension<TWTypography>()!;

  final homeColors = TWColors(
    brand: const Color(0xFF1976D2), // Professional blue
    brandContainer: const Color(0xFF1976D2).withValues(alpha: 0.12),
    brandVariant: const Color(0xFF42A5F5), // Lighter blue
    textPrimary: const Color(0xFFE8E8E8),
    textSecondary: const Color(0xFFB8B8B8),
    textTertiary: const Color(0xFFB8B8B8).withValues(alpha: 0.7),
    textDisabled: const Color(0xFFB8B8B8).withValues(alpha: 0.38),
    background: const Color(0xFF0F0F0F),
    surface: const Color(0xFF121212),
    surfaceContainer: const Color(0xFF1E1E1E),
    surfaceContainerHigh: const Color(0xFF1E1E1E),
    surfaceContainerHighest: const Color(0xFF1E1E1E),
    surfaceInput: const Color(0xFF121212),
    appBarSurface: const Color(0xFF121212),
    divider: const Color(0xFF1E1E1E),
    success: parentColors.success,
    warning: parentColors.warning,
    error: const Color(0xFFFF6B6B),
    info: const Color(0xFF42A5F5),
    successContainer: parentColors.successContainer,
    warningContainer: parentColors.warningContainer,
    errorContainer: parentColors.errorContainer,
    infoContainer: parentColors.infoContainer,
    selectedOverlay: parentColors.selectedOverlay,
    hoverOverlay: parentColors.hoverOverlay,
    pressedOverlay: parentColors.pressedOverlay,
    focusRing: parentColors.focusRing,
  );

  final homeTypography = TWTypography(
    logo: parentTypography.logo,
    hero: parentTypography.hero,
    display: parentTypography.display,
    headline: parentTypography.headline,
    title: parentTypography.title,
    body: parentTypography.body,
    bodySmall: parentTypography.bodySmall,
    label: parentTypography.label,
    caption: parentTypography.caption,
    button: parentTypography.button,
    overline: parentTypography.overline,
  );

  return darkProfessionalTheme.copyWith(
    extensions: [
      homeColors,
      homeTypography,
      parentTheme.extension<TWSpacing>()!,
      parentTheme.extension<TWRadius>()!,
      parentTheme.extension<TWMotion>()!,
      parentTheme.extension<TWShadows>()!,
      parentTheme.extension<TWGradients>()!,
      parentTheme.extension<TWLayoutTokens>()!,
    ],
  );
}

class SendFeedbackPage extends GetView<SendFeedbackController> {
  const SendFeedbackPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already registered
    if (!Get.isRegistered<SendFeedbackController>()) {
      Get.lazyPut(SendFeedbackController.new);
    }
    final controller = Get.find<SendFeedbackController>();

    return Theme(
      data: _getTheme(context),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Feedback',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
                onPressed: () {
                  if (isDashboard) {
                    Get.find<HomeController>().sideNavSelectedIndex.value =
                        HomeController.indexHome;
                  } else {
                    Get.back();
                  }
                },
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    _buildTypeSelector(context),
                    const SizedBox(height: 24),
                    _buildRatingSection(context),
                    const SizedBox(height: 24),
                    _buildEmailInput(context),
                    const SizedBox(height: 24),
                    _buildMessageInput(context),
                    const SizedBox(height: 48),
                    _buildSubmitButton(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We value your voice',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us how we can make TruthWorld better for you.',
          style: TextStyle(
            fontSize: 15,
            color: context.colors.textSecondary,
          ),
        ),
        _buildAuthNotice(context),
      ],
    );
  }

  Widget _buildAuthNotice(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sign in required: You must be logged in with a TruthWorld account to submit feedback.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: controller.feedbackTypes.map((type) {
              final isSelected = controller.feedbackType.value == type;
              return InkWell(
                onTap: () => controller.feedbackType.value = type,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary
                        : context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary
                          : context.colors.divider.withValues(alpha: 0.1),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.bgPage
                          : context.colors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RATING',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.divider.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (index) {
              return Obx(() {
                final isSelected = index < controller.rating.value;
                return InkWell(
                  onTap: () => controller.rating.value = index + 1,
                  child: AnimatedScale(
                    scale: isSelected ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isSelected
                          ? AppColors.textPrimary
                          : context.colors.textSecondary.withValues(alpha: 0.3),
                      size: 36,
                    ),
                  ),
                );
              });
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailInput(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCOUNT EMAIL',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.emailController,
          enabled: false,
          maxLength: 254,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          style: TextStyle(color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: user?.email ?? 'Sign in required to submit feedback',
            hintStyle: TextStyle(
              color: context.colors.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colors.divider.withValues(alpha: 0.1),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colors.divider.withValues(alpha: 0.05),
              ),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MESSAGE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.feedbackController,
          maxLines: 6,
          maxLength: ContentValidator.defaultMaxFeedbackLength,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: TruthworldTextInputFormatters.withLimit(
            ContentValidator.defaultMaxFeedbackLength,
          ),
          style: TextStyle(color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Share your thoughts, suggestions or bug details...',
            hintStyle: TextStyle(
              color: context.colors.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colors.divider.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colors.divider.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.textPrimary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
          validator: ContentValidator.formValidator(
            'Feedback',
            minLength: 5,
            maxLength: ContentValidator.defaultMaxFeedbackLength,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    return Obx(
      () => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: controller.isSubmitting.value
              ? null
              : controller.submitFeedback,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.bgPage,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
            ),
            elevation: 8,
            shadowColor: AppColors.bgPage.withValues(alpha: 0.5),
          ),
          child: controller.isSubmitting.value
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.textPrimary,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  isGuest ? 'Sign In to Submit Feedback' : 'Submit Feedback',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
