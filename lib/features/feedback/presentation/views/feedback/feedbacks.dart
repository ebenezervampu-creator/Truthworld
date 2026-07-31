import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/theme/app_theme.dart';

class SendFeedbackController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final feedbackController = TextEditingController();
  final feedbackType = 'General'.obs;
  final rating = 0.obs;
  final isSubmitting = false.obs;
  final appVersion = 'Unknown'.obs;
  final deviceInfo = <String, dynamic>{}.obs;
  final RxList<XFile> attachments = <XFile>[].obs;

  final List<String> feedbackTypes = [
    'Bug',
    'Feature Request',
    'General',
    'Other',
  ];

  @override
  void onInit() {
    super.onInit();
    _getDeviceInfo();
  }

  @override
  void onClose() {
    feedbackController.dispose();
    super.onClose();
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
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    deviceInfo.assignAll(info);
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      attachments.addAll(picked);
    }
  }

  void removeAttachment(int index) {
    attachments.removeAt(index);
  }

  Future<void> submitFeedback() async {
    if (!formKey.currentState!.validate() || isSubmitting.value) return;

    isSubmitting.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Upload attachments if any
      final imageUrls = <String>[];
      for (final file in attachments) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('feedback_attachments')
            .child(
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
            );

        if (kIsWeb) {
          await ref.putData(await file.readAsBytes());
        } else {
          await ref.putFile(File(file.path));
        }
        imageUrls.add(await ref.getDownloadURL());
      }

      // 2. Submit to Firestore
      final feedbackData = {
        'userId': user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? 'anonymous',
        'feedbackType': feedbackType.value,
        'feedbackText': feedbackController.text,
        'rating': rating.value,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
        'appVersion': appVersion.value,
        'deviceInfo': Map<String, dynamic>.from(deviceInfo),
        'attachments': imageUrls,
      };

      await FirebaseFirestore.instance.collection('feedback').add(feedbackData);

      // Reset UI
      feedbackController.clear();
      rating.value = 0;
      attachments.clear();

      Get.snackbar(
        'Success',
        'Thank you for your feedback!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgPage,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      Future.delayed(const Duration(seconds: 1), Get.back);
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      Get.snackbar(
        'Error',
        'Failed to submit feedback. $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
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

  return modernDarkProfessionalTheme.copyWith(
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
                        HomeController.indexSettings;
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
                    _buildMessageInput(context),
                    const SizedBox(height: 24),
                    _buildImageUploadSection(context),
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
      ],
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
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your message';
            }
            if (value.trim().length < 5) {
              return 'Message is too short';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildImageUploadSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ATTACHMENTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            Obx(
              () => Text(
                '${controller.attachments.length}/5',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(
          () => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...controller.attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: kIsWeb
                              ? NetworkImage(file.path)
                              : FileImage(File(file.path)) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: context.colors.divider.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: InkWell(
                        onTap: () => controller.removeAttachment(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.bgPage,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (controller.attachments.length < 5)
                InkWell(
                  onTap: controller.pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.colors.divider.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: context.colors.brand,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
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
              : const Text(
                  'Submit Feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
