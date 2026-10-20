import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Dedicated GetxController for editing video metadata, visibility, and interaction settings.
class EditVideoController extends BaseController with ContentValidationMixin {
  EditVideoController({required this.video});

  final Video video;

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController tagsController;

  late final RxString selectedVisibility;
  late final RxBool isKidFriendly;
  late final RxBool showLikeCount;
  late final RxBool showDislikeCount;
  late final RxBool autoChaptersEnabled;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  VideoManagementController get videoManagementController =>
      Get.isRegistered<VideoManagementController>()
          ? Get.find<VideoManagementController>()
          : Get.put(VideoManagementController());

  @override
  void onInit() {
    super.onInit();
    titleController = trackTextController(TextEditingController(text: video.title));
    descriptionController = trackTextController(
      TextEditingController(text: video.description),
    );
    tagsController = trackTextController(
      TextEditingController(text: video.tags.join(', ')),
    );

    selectedVisibility = video.visibility.obs;
    isKidFriendly = video.isKidFriendly.obs;
    showLikeCount = video.showLikeCount.obs;
    showDislikeCount = video.showDislikeCount.obs;
    autoChaptersEnabled = video.autoChaptersEnabled.obs;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;

    final title = titleController.text.trim();
    final titleResult = ContentValidator.validate(
      title,
      maxLength: 100,
      fieldName: 'Title',
    );
    if (!titleResult.isValid) {
      AppSnackbar.warning(titleResult.message);
      return;
    }

    final description = descriptionController.text.trim();
    if (description.isNotEmpty) {
      final descResult = ContentValidator.validate(
        description,
        maxLength: 5000,
        fieldName: 'Description',
      );
      if (!descResult.isValid) {
        AppSnackbar.warning(descResult.message);
        return;
      }
    }

    final tags = tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();

    if (tags.isNotEmpty) {
      final tagsResult = ContentValidator.validateTags(tags);
      if (!tagsResult.isValid) {
        AppSnackbar.warning(tagsResult.message);
        return;
      }
    }

    final updatedData = <String, dynamic>{
      'title': title,
      'description': description,
      'tags': tags,
      'visibility': selectedVisibility.value,
      'isKidFriendly': isKidFriendly.value,
      'showLikeCount': showLikeCount.value,
      'showDislikeCount': showDislikeCount.value,
      'autoChaptersEnabled': autoChaptersEnabled.value,
      'aiFeatures': {'autoChapters': autoChaptersEnabled.value},
    };

    videoManagementController.updateVideo(video.id, updatedData);
    Get.back();
  }
}
