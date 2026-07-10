import 'dart:io';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
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

    Map<String, dynamic> info = {};
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
    final ImagePicker picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage();
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
      List<String> imageUrls = [];
      for (var file in attachments) {
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
        backgroundColor: Colors.black,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      Future.delayed(const Duration(seconds: 1), () => Get.back());
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      Get.snackbar(
        'Error',
        'Failed to submit feedback. ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }
}

class SendFeedbackPage extends GetView<SendFeedbackController> {
  final bool isDashboard;
  const SendFeedbackPage({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already registered
    if (!Get.isRegistered<SendFeedbackController>()) {
      Get.lazyPut(() => SendFeedbackController());
    }
    final controller = Get.find<SendFeedbackController>();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Feedback',
          style: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const BackSymbol(color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              AppColors.brand.withValues(alpha: 0.1),
              AppColors.bgPage,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildTypeSelector(),
                const SizedBox(height: 24),
                _buildRatingSection(),
                const SizedBox(height: 24),
                _buildMessageInput(),
                const SizedBox(height: 24),
                _buildImageUploadSection(),
                const SizedBox(height: 48),
                _buildSubmitButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We value your voice',
          style: GoogleFonts.roboto(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us how we can make TruthWorld better for you.',
          style: GoogleFonts.roboto(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
                        ? Colors.white
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : AppColors.bgDivider.withValues(alpha: 0.1),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.roboto(
                      color: isSelected
                          ? Colors.black
                          : AppColors.textSecondary,
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

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RATING',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.bgDivider.withValues(alpha: 0.1),
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
                          ? Colors.white
                          : AppColors.textSecondary.withValues(alpha: 0.3),
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

  Widget _buildMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MESSAGE',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.feedbackController,
          maxLines: 6,
          style: GoogleFonts.roboto(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Share your thoughts, suggestions or bug details...',
            hintStyle: GoogleFonts.roboto(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.bgDivider.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.bgDivider.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.white,
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

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ATTACHMENTS',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            Obx(
              () => Text(
                '${controller.attachments.length}/5',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.textSecondary,
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
                          color: AppColors.bgDivider.withValues(alpha: 0.2),
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
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
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
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.bgDivider.withValues(alpha: 0.1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.brand,
                          size: 28,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: AppColors.textSecondary,
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

  Widget _buildSubmitButton() {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: controller.isSubmitting.value
              ? null
              : controller.submitFeedback,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white, width: 1.5),
            ),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.5),
          ),
          child: controller.isSubmitting.value
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Submit Feedback',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}





