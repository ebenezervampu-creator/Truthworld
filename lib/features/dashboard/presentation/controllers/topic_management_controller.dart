import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class TopicManagementController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Reactive State
  final RxString searchQuery = ''.obs;
  final RxList<Topic> topicsList = <Topic>[].obs;
  final RxBool isLoading = false.obs;

  /// Computed Filtered Topics based on search query
  List<Topic> get filteredTopics {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return topicsList;
    return topicsList.where((topic) {
      return topic.title.toLowerCase().contains(query) ||
          topic.handle.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query) ||
          topic.category.toLowerCase().contains(query);
    }).toList();
  }

  // Summary Metrics Getters
  int get totalTopicsCount => topicsList.length;
  int get totalVideosCount =>
      topicsList.fold(0, (acc, t) => acc + t.videoCount);
  int get publicTopicsCount => topicsList
      .where((t) => t.visibilityType == TopicVisibilityType.public)
      .length;
  int get privateTopicsCount => topicsList
      .where((t) => t.visibilityType == TopicVisibilityType.private)
      .length;

  Future<void> _ensureStorageAuthReady() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      await user.getIdToken(true);
      if (kIsWeb) {
        debugPrint(
          '⏳ [TopicManagementController] Waiting for Storage auth context sync...',
        );
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint(
          '✅ [TopicManagementController] Storage auth context synchronized',
        );
      }
      debugPrint(
        '✅ [TopicManagementController] Storage auth ready for user: ${user.uid}',
      );
    } catch (e) {
      debugPrint(
        '❌ [TopicManagementController] Failed to prepare Storage auth: $e',
      );
      throw Exception('Storage auth preparation failed: $e');
    }
  }

  Future<String?> uploadTopicThumbnail(Uint8List bytes, String fileName) async {
    try {
      debugPrint(
        '🚀 [TopicManagementController] Starting uploadTopicThumbnail...',
      );
      await _ensureStorageAuthReady();
      final ref = _storage.ref().child('thumbnails/topics/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded': DateTime.now().toString()},
      );
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.timeout(const Duration(seconds: 20));
      final downloadUrl = await ref.getDownloadURL();
      debugPrint(
        '🔗 [TopicManagementController] Uploaded thumbnail URL: $downloadUrl',
      );
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ [TopicManagementController] Thumbnail Upload error: $e');
      return null;
    }
  }

  Stream<List<Topic>> fetchChannelTopics(String channelId) {
    return _firestore
        .collection('topics')
        .where('channelId', isEqualTo: channelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Topic.fromDocumentSnapshot).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> fetchChannelVideos(
    String channelId,
  ) async {
    try {
      final rootQuery = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .get();

      final subQuery = await _firestore
          .collection('channels')
          .doc(channelId)
          .collection('videos')
          .get();

      final videos = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      void addDocs(List<QueryDocumentSnapshot> docs) {
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final id = doc.id;
            if (!seenIds.contains(id)) {
              seenIds.add(id);
              videos.add({
                'id': id,
                'title': data['title'] ?? 'Untitled Video',
                'thumbnailUrl': data['thumbnailUrl'] ?? '',
                'category': data['category'] ?? 'General',
              });
            }
          }
        }
      }

      addDocs(rootQuery.docs);
      addDocs(subQuery.docs);

      return videos;
    } catch (e) {
      debugPrint('Error fetching channel videos: $e');
      return [];
    }
  }

  Future<void> createTopic({
    required String channelId,
    required String title,
    required String handle,
    required String description,
    required String category,
    required List<String> selectedVideoIds,
    TopicVisibilityType visibilityType = TopicVisibilityType.public,
    String? accessCode,
    String? thumbnailUrl,
  }) async {
    try {
      // 1. Verify channel has at least one uploaded video
      final channelDoc = await _firestore
          .collection('channels')
          .doc(channelId)
          .get();
      var videoCount = 0;
      if (channelDoc.exists) {
        videoCount = (channelDoc.data()?['videoCount'] as num?)?.toInt() ?? 0;
      }

      if (videoCount < 1) {
        // Double-check fallback: scan videos collection directly in case of sync delay
        final rootVideosSnap = await _firestore
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .limit(1)
            .get();

        final channelVideosSubSnap = await _firestore
            .collection('channels')
            .doc(channelId)
            .collection('videos')
            .limit(1)
            .get();

        if (rootVideosSnap.docs.isEmpty && channelVideosSubSnap.docs.isEmpty) {
          AppSnackbar.show(
            'Action Restricted',
            'To create a topic, you must have at least one uploaded video on your channel.',
            backgroundColor: AppColors.error,
            colorText: AppColors.textPrimary,
            duration: const Duration(seconds: 4),
          );
          return;
        }
      }

      // 2. Validate and clean handle format
      var cleanHandle = handle.trim();
      if (cleanHandle.startsWith('T/')) {
        cleanHandle = cleanHandle.substring(2);
      }
      if (cleanHandle.startsWith('t/')) {
        cleanHandle = cleanHandle.substring(2);
      }
      cleanHandle = cleanHandle
          .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
          .replaceAll(RegExp('-+'), '-');
      if (cleanHandle.isEmpty) {
        AppSnackbar.show(
          'Validation Error',
          'Topic handle is required and must contain alphanumeric characters.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return;
      }
      final finalHandle = 'T/$cleanHandle';
      final finalHandleLowercase = finalHandle.toLowerCase();

      // Check if handle is already taken
      final existingHandle = await _firestore
          .collection('topics')
          .where('handleLowercase', isEqualTo: finalHandleLowercase)
          .limit(1)
          .get();

      if (existingHandle.docs.isNotEmpty) {
        AppSnackbar.show(
          'Action Restricted',
          'Topic handle is already taken. Please choose a different one.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return;
      }

      final slug = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');

      final existingSlug = await _firestore
          .collection('topics')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      var finalSlug = slug;
      if (existingSlug.docs.isNotEmpty) {
        finalSlug = '$slug-${const Uuid().v4().substring(0, 6)}';
      }

      final newTopicRef = _firestore.collection('topics').doc();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      final topic = Topic(
        id: newTopicRef.id,
        title: title,
        slug: finalSlug,
        handle: finalHandle,
        handleLowercase: finalHandleLowercase,
        description: description,
        category: category,
        thumbnailUrl: thumbnailUrl,
        channelId: channelId,
        creatorId: currentUid,
        visibilityType: visibilityType,
        accessCode: accessCode,
        videoCount: selectedVideoIds.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'underReview',
      );

      await newTopicRef.set(topic.toMap());

      // Update selected videos to link to this new topic in a batch write
      if (selectedVideoIds.isNotEmpty) {
        final batch = _firestore.batch();
        for (final videoId in selectedVideoIds) {
          final videoRef = _firestore.collection('videos').doc(videoId);
          batch.update(videoRef, {
            'topicId': finalSlug,
            'topics': [finalSlug],
          });
        }
        await batch.commit();
      }

      AppSnackbar.show(
        'Success',
        'Topic created successfully',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to create topic: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<List<String>> fetchTopicVideos(String topicSlug) async {
    try {
      final snap = await _firestore
          .collection('videos')
          .where('topicId', isEqualTo: topicSlug)
          .get();
      return snap.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error fetching topic videos: $e');
      return [];
    }
  }

  Future<void> updateTopic({
    required Topic topic,
    required String title,
    required String description,
    required String category,
    required List<String> selectedVideoIds,
    required TopicVisibilityType visibilityType,
    String? accessCode,
    String? thumbnailUrl,
  }) async {
    try {
      final updatedTopic = topic.copyWith(
        title: title,
        description: description,
        category: category,
        thumbnailUrl: thumbnailUrl ?? topic.thumbnailUrl,
        visibilityType: visibilityType,
        accessCode: visibilityType == TopicVisibilityType.private
            ? accessCode
            : null,
        videoCount: selectedVideoIds.length,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('topics')
          .doc(topic.id)
          .update(updatedTopic.toMap());

      final currentLinkedVideos = await fetchTopicVideos(topic.slug);

      final batch = _firestore.batch();

      // Videos that were unlinked: remove topicId and topics entry
      for (final videoId in currentLinkedVideos) {
        if (!selectedVideoIds.contains(videoId)) {
          final videoRef = _firestore.collection('videos').doc(videoId);
          batch.update(videoRef, {
            'topicId': FieldValue.delete(),
            'topics': FieldValue.arrayRemove([topic.slug]),
          });
        }
      }

      // Videos that were newly linked: set topicId and topics entry
      for (final videoId in selectedVideoIds) {
        if (!currentLinkedVideos.contains(videoId)) {
          final videoRef = _firestore.collection('videos').doc(videoId);
          batch.update(videoRef, {
            'topicId': topic.slug,
            'topics': FieldValue.arrayUnion([topic.slug]),
          });
        }
      }

      await batch.commit();

      AppSnackbar.show(
        'Success',
        'Topic updated successfully',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to update topic: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> deleteTopic(Topic topic) async {
    try {
      await _firestore.collection('topics').doc(topic.id).update({
        'status': 'deletion_pending',
        'visibilityType': 'private',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      });
      topicsList.removeWhere((t) => t.id == topic.id);
      AppSnackbar.show(
        'Success',
        'Topic is now private and scheduled for deletion in 30 days',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to schedule topic deletion: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  /// Navigates to topic route using app router
  void viewTopic(Topic topic) {
    if (topic.topicRoute.isNotEmpty) {
      Get.toNamed(topic.topicRoute);
    }
  }

  /// Copies topic deep link URL to clipboard
  void copyLink(Topic topic) {
    final url = DeepLinkService.topicUrl(topic.routePathParameter);
    Clipboard.setData(ClipboardData(text: url));
    AppSnackbar.show(
      'Link Copied',
      'Topic link copied to clipboard: $url',
      backgroundColor: const Color(0xFF10B981),
      colorText: AppColors.textPrimary,
    );
  }

  /// Destructive Confirmation Dialog for deleting topic
  void deleteTopicWithConfirmation(BuildContext context, Topic topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF161B22)
            : AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Topic?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${topic.title}"?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will remove the topic knowledge hub from your studio. Linked videos will remain safe on your channel.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.textSecondary : AppColors.bgPage54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              deleteTopic(topic);
            },
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text(
              'Delete Topic',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Callback for presentation layer to handle EditTopicDialog
  Function(BuildContext context, Topic topic)? onEditTopicRequested;

  /// Triggers Edit Topic Dialog via callback
  void editTopic(BuildContext context, Topic topic) {
    final isOwner =
        Get.isRegistered<AuthService>() &&
        ((topic.channelId != null &&
                topic.channelId!.isNotEmpty &&
                AuthService.to.userChannel?.id == topic.channelId) ||
            (topic.creatorId != null &&
                topic.creatorId!.isNotEmpty &&
                AuthService.to.uid == topic.creatorId));

    if (!isOwner) {
      SnackbarService.error(
        message: 'Only the topic creator channel can edit this topic.',
      );
      return;
    }

    if (onEditTopicRequested != null) {
      onEditTopicRequested!(context, topic);
    }
  }
}
