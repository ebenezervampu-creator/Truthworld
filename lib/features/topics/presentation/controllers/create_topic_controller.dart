import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/cloud_vision_service.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// Industry-standard controller for topic creation, form validation, profanity checking,
/// and Google Cloud Vision AI thumbnail verification.
class CreateTopicController extends BaseController with ContentValidationMixin {
  final GoogleCloudVisionService _visionService = GoogleCloudVisionService();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController handleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController accessCodeController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();
  final TextEditingController categoryController = TextEditingController(
    text: 'Science & Technology',
  );

  // Form State
  final RxList<String> tagsList = <String>['Space', 'Astronomy', 'Science', 'Exploration'].obs;
  final Rx<TopicVisibilityType> selectedVisibility =
      TopicVisibilityType.public.obs;
  final RxBool obscureAccessCode = true.obs;
  final RxString thumbnailSource = 'video'.obs; // 'video' | 'custom'

  // Custom Image State
  final Rx<Uint8List?> pickedCustomImageBytes = Rx<Uint8List?>(null);
  final Rx<String?> pickedCustomImageName = Rx<String?>(null);

  // Video Linking State
  final RxList<String> selectedVideoIds = <String>[].obs;
  final RxString chosenVideoThumbnailUrl = ''.obs;

  // Verification & Status Observables
  final RxBool isVisionScanning = false.obs;
  final RxBool isVisionApproved = false.obs;
  final RxString visionError = ''.obs;
  final RxString profanityError = ''.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool autoHandleTouched = false.obs;
  final RxBool isFromUpload = false.obs;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    nameController.addListener(_onNameChanged);
    titleController.addListener(_onTitleChanged);
  }

  @override
  void onClose() {
    nameController.removeListener(_onNameChanged);
    titleController.removeListener(_onTitleChanged);
    nameController.dispose();
    titleController.dispose();
    handleController.dispose();
    descriptionController.dispose();
    accessCodeController.dispose();
    tagsController.dispose();
    tagInputController.dispose();
    categoryController.dispose();
    super.onClose();
  }

  void _onNameChanged() {
    if (titleController.text.isEmpty || titleController.text == nameController.text) {
      titleController.text = nameController.text;
    }
    _onTitleChanged();
  }

  /// Automatically updates handle slug as the user types title unless manually modified.
  void _onTitleChanged() {
    final activeText = nameController.text.isNotEmpty ? nameController.text : titleController.text;
    if (!autoHandleTouched.value && activeText.isNotEmpty) {
      final slug = activeText
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s_-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      handleController.text = slug;
    }
    validateProfanityRealtime();
  }

  Future<void> addTag(String rawTag) async {
    final clean = rawTag.replaceAll(',', '').replaceAll('#', '').trim();
    if (clean.isNotEmpty && !tagsList.contains(clean) && tagsList.length < 5) {
      final tagVal = await validateContent(clean, fieldName: 'Tag');
      if (!tagVal.isValid) {
        profanityError.value = tagVal.message;
        return;
      }
      tagsList.add(clean);
      tagsController.text = tagsList.join(', ');
      tagInputController.clear();
      profanityError.value = '';
    }
  }

  void removeTag(String tag) {
    tagsList.remove(tag);
    tagsController.text = tagsList.join(', ');
    profanityError.value = '';
  }

  /// Mark handle as manually edited by user.
  void onHandleManualEdit() {
    autoHandleTouched.value = true;
    validateProfanityRealtime();
  }

  /// Toggle passcode visibility for private topics.
  void togglePasscodeVisibility() {
    obscureAccessCode.toggle();
  }

  /// Pick custom thumbnail image, crop to 16:9 widescreen format, and run Google Cloud Vision verification.
  Future<void> pickCustomThumbnail() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final croppedFile = await ImageCropperService.cropTopicThumbnail(
          imagePath: pickedFile.path,
          context: Get.context,
        );

        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          final fileName = pickedFile.name.isNotEmpty
              ? pickedFile.name
              : 'topic_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

          pickedCustomImageBytes.value = bytes;
          pickedCustomImageName.value = fileName;

          // Run Google Cloud Vision AI Verification on cropped image
          await verifyCustomThumbnail(bytes, fileName);
        }
      }
    } catch (e, stack) {
      logger.error(
        'Failed to pick thumbnail image: $e',
        error: e,
        stackTrace: stack,
        tag: 'CREATE_TOPIC',
      );
      visionError.value = 'Failed to pick image file. Please try again.';
      isVisionApproved.value = false;
    }
  }

  /// Clears picked custom thumbnail.
  void clearCustomThumbnail() {
    pickedCustomImageBytes.value = null;
    pickedCustomImageName.value = null;
    isVisionApproved.value = false;
    visionError.value = '';
  }

  /// Verifies thumbnail bytes via Google Cloud Vision AI.
  Future<bool> verifyCustomThumbnail(Uint8List bytes, String fileName) async {
    isVisionScanning.value = true;
    visionError.value = '';
    isVisionApproved.value = false;

    final result = await _visionService.verifyImageBytes(bytes, fileName);
    isVisionScanning.value = false;

    if (result.isApproved) {
      isVisionApproved.value = true;
      visionError.value = '';
      return true;
    } else {
      isVisionApproved.value = false;
      visionError.value = result.reason;
      return false;
    }
  }

  /// Real-time profanity validation across form fields.
  Future<bool> validateProfanityRealtime() async {
    profanityError.value = '';

    // Title validation
    if (titleController.text.trim().isNotEmpty) {
      final titleResult = await validateContent(
        titleController.text,
        fieldName: 'Topic Title',
      );
      if (!titleResult.isValid) {
        profanityError.value = titleResult.message;
        return false;
      }
    }

    // Handle validation
    if (handleController.text.trim().isNotEmpty) {
      final handleResult = await validateContent(
        handleController.text,
        fieldName: 'Topic Handle',
      );
      if (!handleResult.isValid) {
        profanityError.value = handleResult.message;
        return false;
      }
    }

    // Description validation
    if (descriptionController.text.trim().isNotEmpty) {
      final descResult = await validateContent(
        descriptionController.text,
        fieldName: 'Description',
      );
      if (!descResult.isValid) {
        profanityError.value = descResult.message;
        return false;
      }
    }

    // Passcode validation
    if (selectedVisibility.value == TopicVisibilityType.private &&
        accessCodeController.text.trim().isNotEmpty) {
      final codeResult = await validateContent(
        accessCodeController.text,
        fieldName: 'Access Passcode',
      );
      if (!codeResult.isValid) {
        profanityError.value = codeResult.message;
        return false;
      }
    }

    return true;
  }

  /// Full pre-submit validation checking fields, profanity, and Vision AI status.
  Future<bool> validateFormBeforeSubmit() async {
    if (formKey.currentState != null && !formKey.currentState!.validate()) {
      return false;
    }

    // Profanity Filter Check
    final isProfanityClean = await validateProfanityRealtime();
    if (!isProfanityClean) {
      return false;
    }

    final tags = tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (tags.length > 5) {
      profanityError.value = 'Maximum 5 tags allowed per topic.';
      return false;
    }
    if (tags.isNotEmpty) {
      final tagsVal = await validateTags(tags);
      if (!tagsVal.isValid) {
        profanityError.value = tagsVal.message;
        return false;
      }
    }

    // Mandatory: Topic must contain at least 1 video, unless creating from upload workflow where current video is being published
    if (!isFromUpload.value && selectedVideoIds.isEmpty) {
      profanityError.value = 'At least 1 video is required to create a topic. Please select a video.';
      AppSnackbar.show(
        'Video Required',
        'At least 1 video is required to create a topic. Please select a video.',
      );
      return false;
    }

    // Thumbnail validation
    if (thumbnailSource.value == 'custom') {
      if (pickedCustomImageBytes.value == null) {
        visionError.value = 'Please select a custom thumbnail image.';
        return false;
      }
      if (!isVisionApproved.value) {
        if (isVisionScanning.value) {
          visionError.value =
              'Please wait for Google Cloud Vision AI scan to finish.';
        } else if (visionError.value.isEmpty) {
          visionError.value =
              'Custom thumbnail failed Vision AI safety verification.';
        }
        return false;
      }
    }

    return true;
  }

  /// Toggle video selection for thumbnail source.
  void toggleVideoSelection(String videoId, String videoThumbnailUrl) {
    if (selectedVideoIds.contains(videoId)) {
      selectedVideoIds.remove(videoId);
      if (chosenVideoThumbnailUrl.value == videoThumbnailUrl) {
        chosenVideoThumbnailUrl.value = '';
      }
    } else {
      selectedVideoIds.add(videoId);
      if (chosenVideoThumbnailUrl.value.isEmpty &&
          videoThumbnailUrl.isNotEmpty) {
        chosenVideoThumbnailUrl.value = videoThumbnailUrl;
      }
    }
  }

  /// Reset form state for fresh modal opening.
  void resetForm() {
    titleController.clear();
    handleController.clear();
    descriptionController.clear();
    accessCodeController.clear();
    tagsController.clear();
    categoryController.text = 'Technology';
    selectedVisibility.value = TopicVisibilityType.public;
    obscureAccessCode.value = true;
    thumbnailSource.value = 'video';
    pickedCustomImageBytes.value = null;
    pickedCustomImageName.value = null;
    selectedVideoIds.clear();
    chosenVideoThumbnailUrl.value = '';
    isVisionScanning.value = false;
    isVisionApproved.value = false;
    visionError.value = '';
    profanityError.value = '';
    isSubmitting.value = false;
    autoHandleTouched.value = false;
    isFromUpload.value = false;
  }
}
