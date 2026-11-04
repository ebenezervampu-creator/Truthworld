import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';

/// Full-page screen for creating a new Topic
class CreateTopicScreen extends StatelessWidget {
  const CreateTopicScreen({
    super.key,
    this.isFromUpload = false,
  });

  final bool isFromUpload;

  bool get fromUpload =>
      isFromUpload || (Get.arguments is Map && Get.arguments['fromUpload'] == true);

  Future<List<Map<String, dynamic>>> _fetchVideos(String channelId) async {
    try {
      final uid = AuthService.to.uid;
      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      void addDocs(List<QueryDocumentSnapshot> docs) {
        for (final d in docs) {
          if (!seenIds.contains(d.id)) {
            seenIds.add(d.id);
            final data = d.data() as Map<String, dynamic>?;
            if (data != null) {
              results.add({'id': d.id, ...data});
            }
          }
        }
      }

      if (channelId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('channelId', isEqualTo: channelId)
            .get();
        addDocs(snap.docs);
      }
      if (uid.isNotEmpty) {
        final snapOwner = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('ownerId', isEqualTo: uid)
            .get();
        addDocs(snapOwner.docs);

        final snapUser = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('userId', isEqualTo: uid)
            .get();
        addDocs(snapUser.docs);

        final snapCreator = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('creatorId', isEqualTo: uid)
            .get();
        addDocs(snapCreator.docs);
      }
      return results;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'CreateTopicScreen._fetchVideos',
      );
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final topicManagementCtrl = Get.isRegistered<TopicManagementController>()
        ? Get.find<TopicManagementController>()
        : Get.put(TopicManagementController());

    final channelId = AuthService.to.userChannel?.id ?? '';

    return CreateTopicDialog(
      isDarkMode: isDarkMode,
      isFromUpload: fromUpload,
      channelVideosFuture: _fetchVideos(channelId),
      onCreateTopicSubmitted: (createCtrl) async {
        String? finalThumbnailUrl;
        if (createCtrl.thumbnailSource.value == 'custom' &&
            createCtrl.pickedCustomImageBytes.value != null) {
          finalThumbnailUrl = await topicManagementCtrl.uploadTopicThumbnail(
            createCtrl.pickedCustomImageBytes.value!,
            createCtrl.pickedCustomImageName.value ?? 'custom_topic_thumb.jpg',
          );
        } else if (createCtrl.thumbnailSource.value == 'video') {
          finalThumbnailUrl = createCtrl.chosenVideoThumbnailUrl.value;
        }

        final effectiveChannelId = channelId.isNotEmpty
            ? channelId
            : (AuthService.to.userChannel?.id ?? '');

        await topicManagementCtrl.createTopic(
          channelId: effectiveChannelId,
          name: createCtrl.nameController.text.trim(),
          handle: createCtrl.handleController.text.trim(),
          description: createCtrl.descriptionController.text.trim(),
          category: createCtrl.categoryController.text.trim().isEmpty
              ? 'General'
              : createCtrl.categoryController.text.trim(),
          selectedVideoIds: createCtrl.selectedVideoIds.toList(),
          visibilityType: createCtrl.selectedVisibility.value,
          accessCode:
              createCtrl.selectedVisibility.value == TopicVisibilityType.private
                  ? createCtrl.accessCodeController.text.trim()
                  : null,
          thumbnailUrl: finalThumbnailUrl,
        );
      },
    );
  }
}
