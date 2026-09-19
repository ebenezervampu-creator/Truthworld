import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

class CreatePlaylistController extends BaseController {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  final RxInt nameLength = 0.obs;
  final RxInt descLength = 0.obs;
  final RxBool isPublic = true.obs;
  final RxList<Video> selectedVideos = <Video>[].obs;
  final RxInt selectedThumbnailIndex = 0.obs;

  final Rx<Uint8List?> customImageBytes = Rx<Uint8List?>(null);
  final Rx<String?> customImageName = Rx<String?>(null);
  final RxBool useCustomThumbnail = false.obs;
  final RxBool isCreating = false.obs;

  @override
  void onInit() {
    super.onInit();
    nameController.addListener(() {
      nameLength.value = nameController.text.length;
    });
    descController.addListener(() {
      descLength.value = descController.text.length;
    });
  }

  @override
  void onClose() {
    nameController.dispose();
    descController.dispose();
    super.onClose();
  }

  Future<void> loadInitialVideo(String? initialVideoId) async {
    if (initialVideoId != null && initialVideoId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(initialVideoId)
            .get();
        if (doc.exists) {
          selectedVideos.add(Video.fromDocumentSnapshot(doc));
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'CreatePlaylistController.loadInitialVideo',
        );
      }
    }
  }

  Future<void> pickCustomImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        customImageBytes.value = file.bytes ?? await file.xFile.readAsBytes();
        customImageName.value = file.name;
        useCustomThumbnail.value = true;
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'CreatePlaylistController');
      AppSnackbar.error('Unable to select image. Please try again.');
    }
  }

  void setPublic(bool value) {
    isPublic.value = value;
  }

  void setUseCustomThumbnail(bool value) {
    useCustomThumbnail.value = value;
  }

  void setSelectedThumbnailIndex(int index) {
    selectedThumbnailIndex.value = index;
    useCustomThumbnail.value = false;
  }

  void updateSelectedVideos(List<Video> selected) {
    selectedVideos.assignAll(selected);
    if (selectedThumbnailIndex.value >= selectedVideos.length) {
      selectedThumbnailIndex.value = 0;
    }
  }

  void removeVideoAt(int index) {
    selectedVideos.removeAt(index);
    if (selectedThumbnailIndex.value >= selectedVideos.length &&
        selectedVideos.isNotEmpty) {
      selectedThumbnailIndex.value = selectedVideos.length - 1;
    }
  }

  void clearSelectedVideos() {
    selectedVideos.clear();
    selectedThumbnailIndex.value = 0;
  }

  void reorderVideos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = selectedVideos.removeAt(oldIndex);
    selectedVideos.insert(newIndex, item);
  }

  Future<bool> submitCreatePlaylist() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show('Required', 'Please enter a playlist name');
      return false;
    }

    final nameVal = ContentValidator.validate(name, fieldName: 'Playlist Name');
    if (!nameVal.isValid) {
      AppSnackbar.show(
        'Inappropriate Content',
        nameVal.message,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }

    final description = descController.text.trim();
    if (description.isNotEmpty) {
      final descVal = ContentValidator.validate(
        description,
        fieldName: 'Playlist Description',
      );
      if (!descVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          descVal.message,
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }
    }

    isCreating.value = true;

    try {
      final String customThumbnailUrl;
      if (!useCustomThumbnail.value && selectedVideos.isNotEmpty) {
        if (selectedThumbnailIndex.value < selectedVideos.length) {
          customThumbnailUrl =
              selectedVideos[selectedThumbnailIndex.value].thumbnailUrl;
        } else {
          customThumbnailUrl = '';
        }
      } else {
        customThumbnailUrl = '';
      }

      final videoIds = selectedVideos.map((v) => v.id).toList();

      final playlistController = Get.isRegistered<PlaylistController>()
          ? Get.find<PlaylistController>()
          : Get.put(PlaylistController());
      final created = await playlistController.createPlayList(
        name,
        isPublic: isPublic.value,
        videoIds: videoIds,
        description: description,
        customThumbnailUrl: customThumbnailUrl,
      );

      if (created != null) {
        return true;
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'CreatePlaylistController');
      AppSnackbar.error('Unable to create playlist. Please try again.');
    } finally {
      isCreating.value = false;
    }
    return false;
  }
}
