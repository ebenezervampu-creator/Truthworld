import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// GetX controller managing edit topic form state, image cropping, and validation.
class EditTopicController extends GetxController {
  final Topic topic;
  final String channelId;
  final TopicManagementController managementController;

  EditTopicController({
    required this.topic,
    required this.channelId,
    required this.managementController,
  });

  late final TextEditingController nameController;
  TextEditingController get titleController => nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController categoryController;
  late final TextEditingController accessCodeController;

  late final Rx<TopicVisibilityType> selectedVisibility;
  final RxBool obscureAccessCode = true.obs;
  final RxList<String> selectedVideoIds = <String>[].obs;
  final RxBool isLoading = true.obs;
  final RxList<Map<String, dynamic>> channelVideos = <Map<String, dynamic>>[].obs;

  // Thumbnail State
  final RxString thumbnailSource = 'video'.obs; // 'video' or 'custom'
  final Rx<String?> chosenVideoThumbnailUrl = Rx<String?>(null);
  final Rx<Uint8List?> pickedCustomImageBytes = Rx<Uint8List?>(null);
  final Rx<String?> pickedCustomImageName = Rx<String?>(null);
  final RxBool isSaving = false.obs;
  final Rx<String?> currentThumbnailUrl = Rx<String?>(null);

  static const List<String> categories = AppCategories.allCategories;

  @override
  void onInit() {
    super.onInit();
    nameController = TextEditingController(text: topic.name);
    descriptionController = TextEditingController(text: topic.description);
    categoryController = TextEditingController(
      text: categories.contains(topic.category) ? topic.category : 'Technology',
    );
    accessCodeController = TextEditingController(text: topic.accessCode ?? '');
    selectedVisibility = topic.visibilityType.obs;
    currentThumbnailUrl.value = topic.thumbnailUrl;
    chosenVideoThumbnailUrl.value = topic.thumbnailUrl;
    loadData();
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    accessCodeController.dispose();
    super.onClose();
  }

  Future<void> loadData() async {
    try {
      final videos = await managementController.fetchChannelVideos(channelId);
      final linkedIds = await managementController.fetchTopicVideos(topic.slug);

      channelVideos.assignAll(videos);
      selectedVideoIds.assignAll(linkedIds);

      // Intelligently identify if current thumbnail is from video or custom upload
      if (currentThumbnailUrl.value != null && currentThumbnailUrl.value!.isNotEmpty) {
        final matchesVideo = videos.any(
          (v) => v['thumbnailUrl'] == currentThumbnailUrl.value,
        );
        if (matchesVideo) {
          thumbnailSource.value = 'video';
          chosenVideoThumbnailUrl.value = currentThumbnailUrl.value;
        } else {
          thumbnailSource.value = 'custom';
        }
      } else {
        thumbnailSource.value = 'video';
        if (selectedVideoIds.isNotEmpty) {
          final firstVideo = videos.firstWhereOrNull(
            (v) => selectedVideoIds.contains(v['id']),
          );
          if (firstVideo != null) {
            chosenVideoThumbnailUrl.value = firstVideo['thumbnailUrl'] as String?;
          }
        }
      }

      isLoading.value = false;
    } catch (_) {
      isLoading.value = false;
    }
  }

  Future<void> pickCustomImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && context.mounted) {
        final croppedFile = await ImageCropperService.cropTopicThumbnail(
          imagePath: pickedFile.path,
          context: context,
        );
        if (croppedFile != null) {
          final croppedBytes = await croppedFile.readAsBytes();
          pickedCustomImageBytes.value = croppedBytes;
          pickedCustomImageName.value = 'topic_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to select image. Please try again.');
    }
  }

  void removeCustomImage() {
    pickedCustomImageBytes.value = null;
    pickedCustomImageName.value = null;
  }

  void selectVideoThumbnail(String url) {
    chosenVideoThumbnailUrl.value = url;
  }

  void toggleVideoSelection(String videoId, bool isSelected) {
    if (isSelected) {
      selectedVideoIds.add(videoId);
    } else {
      selectedVideoIds.remove(videoId);
    }

    // Sync chosen video thumbnail
    if (selectedVideoIds.isNotEmpty) {
      final selectedMap = channelVideos
          .where((v) => selectedVideoIds.contains(v['id']))
          .toList();
      if (chosenVideoThumbnailUrl.value == null ||
          !selectedMap.any((v) => v['thumbnailUrl'] == chosenVideoThumbnailUrl.value)) {
        chosenVideoThumbnailUrl.value = selectedMap.first['thumbnailUrl'] as String?;
      }
    } else {
      chosenVideoThumbnailUrl.value = null;
    }
  }

  Future<void> submitUpdate({BuildContext? context}) async {
    final nameVal = ContentValidator.validate(
      nameController.text.trim(),
      fieldName: 'Topic Name',
      minLength: 3,
      maxLength: 100,
    );
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return;
    }

    final desc = descriptionController.text.trim();
    if (desc.length < 10) {
      AppSnackbar.warning(
        'Topic description must be at least 10 characters and explain your topic clearly.',
      );
      return;
    }
    final descVal = ContentValidator.validate(
      desc,
      fieldName: 'Topic Description',
      maxLength: 1000,
    );
    if (!descVal.isValid) {
      AppSnackbar.warning(descVal.message);
      return;
    }

    if (selectedVisibility.value == TopicVisibilityType.private &&
        accessCodeController.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter an access code for private topics.');
      return;
    }
    if (selectedVideoIds.isEmpty) {
      AppSnackbar.warning(
        'Please select at least one video to link to your topic.',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    isSaving.value = true;

    try {
      var finalThumbnailUrl = currentThumbnailUrl.value;
      if (thumbnailSource.value == 'custom' && pickedCustomImageBytes.value != null) {
        finalThumbnailUrl = await managementController.uploadTopicThumbnail(
          pickedCustomImageBytes.value!,
          pickedCustomImageName.value!,
        );
      } else if (thumbnailSource.value == 'video') {
        finalThumbnailUrl = chosenVideoThumbnailUrl.value;
      }

      final success = await managementController.updateTopic(
        topic: topic,
        name: nameController.text,
        title: nameController.text,
        description: descriptionController.text,
        category: categoryController.text.isEmpty ? 'General' : categoryController.text,
        selectedVideoIds: selectedVideoIds,
        visibilityType: selectedVisibility.value,
        accessCode: selectedVisibility.value == TopicVisibilityType.private
            ? accessCodeController.text.trim()
            : null,
        thumbnailUrl: finalThumbnailUrl,
      );

      if (success) {
        isSaving.value = false;
        // Pop dialog first before showing snackbar to prevent GetX route collision
        if (context != null && context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else if (Get.isDialogOpen ?? false) {
          Get.back<void>();
        }

        AppSnackbar.success('Topic updated successfully.');
        return;
      }
    } on Exception catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to update topic. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }
}
