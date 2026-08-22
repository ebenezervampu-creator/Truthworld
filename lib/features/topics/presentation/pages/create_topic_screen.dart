import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';

/// Full-page screen for creating a new Topic
class CreateTopicScreen extends StatelessWidget {
  const CreateTopicScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchVideos(String channelId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (channelId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('channelId', isEqualTo: channelId)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        }
      }
      if (uid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('creatorId', isEqualTo: uid)
            .get();
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (e) {
      debugPrint('Error fetching channel videos for topic creation: $e');
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

        await topicManagementCtrl.createTopic(
          channelId: channelId.isNotEmpty
              ? channelId
              : (AuthService.to.userChannel?.id ?? ''),
          title: createCtrl.titleController.text,
          handle: createCtrl.handleController.text,
          description: createCtrl.descriptionController.text,
          category: createCtrl.categoryController.text.isEmpty
              ? 'General'
              : createCtrl.categoryController.text,
          selectedVideoIds: createCtrl.selectedVideoIds,
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
