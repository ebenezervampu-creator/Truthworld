import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class TopicManagementController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Reactive State
  final RxString searchQuery = ''.obs;
  final RxList<Topic> topicsList = <Topic>[].obs;
  final RxBool rxIsLoading = false.obs;
  final RxString selectedTopicId = ''.obs;
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;
  final RxString activeFilterMode = 'all'.obs; // 'all' | 'public' | 'private'

  void setFilterMode(String mode) {
    activeFilterMode.value = mode;
  }

  // Compatibility getters for TopicSelectionBottomSheet
  RxList<Topic> get availableTopics => topicsList;
  RxBool get isTopicsLoading => rxIsLoading;
  RxString get topicSearchQuery => searchQuery;

  void selectTopic(String id) {
    selectedTopicId.value = id;
  }

  void fetchAvailableTopics() {}

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
      .where((t) =>
          t.visibilityType == TopicVisibilityType.public &&
          t.status.toLowerCase() == 'active' &&
          !t.isArchivedOrDeleted)
      .length;
  int get privateTopicsCount => topicsList
      .where((t) =>
          t.visibilityType == TopicVisibilityType.private &&
          !t.isArchivedOrDeleted)
      .length;
  int get rejectedTopicsCount => topicsList
      .where((t) =>
          (t.status.toLowerCase() == 'verificationrejected' ||
           t.status.toLowerCase() == 'rejected') &&
          !t.isArchivedOrDeleted)
      .length;
  int get underReviewTopicsCount => topicsList
      .where((t) =>
          (t.status.toLowerCase() == 'underreview' ||
           t.status.toLowerCase() == 'pending') &&
          !t.isArchivedOrDeleted)
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TopicManagementController.prepareStorageAuth',
      );
      throw Exception('Storage auth preparation failed.');
    }
  }

  Future<String?> uploadTopicThumbnail(Uint8List bytes, String fileName) async {
    try {
      debugPrint(
        '🚀 [TopicManagementController] Starting uploadTopicThumbnail...',
      );
      await _ensureStorageAuthReady();
      final ref = _storage.ref().child('thumbnails/topics/$fileName');
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': ?currentUid,
          'uploaded': DateTime.now().toString(),
        },
      );
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.timeout(const Duration(seconds: 20));
      final downloadUrl = await ref.getDownloadURL();
      debugPrint(
        '🔗 [TopicManagementController] Uploaded thumbnail URL: $downloadUrl',
      );
      return downloadUrl;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TopicManagementController.uploadThumbnail',
      );
      return null;
    }
  }

  Stream<List<Topic>> fetchChannelTopics(String channelId) {
    return _firestore
        .collection(FirestoreCollections.topics)
        .where('channelId', isEqualTo: channelId)
        .snapshots()
        .map(
          (snapshot) {
            final seenCanonical = <String>{};
            final topics = <Topic>[];
            for (final doc in snapshot.docs) {
              final t = Topic.fromDocumentSnapshot(doc);
              if (t.status != 'deletion_pending' &&
                  t.status != 'archived' &&
                  t.status != 'empty_archived' &&
                  seenCanonical.add(t.canonicalKey)) {
                topics.add(t);
              }
            }
            topics.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return topics;
          },
        );
  }

  Future<List<Map<String, dynamic>>> fetchChannelVideos(
    String channelId,
  ) async {
    try {
      final rootQuery = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .get();

      final subQuery = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection(FirestoreCollections.videos)
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TopicManagementController.fetchChannelVideos',
      );
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
      // 0. Validate at least 1 video is selected
      if (selectedVideoIds.isEmpty) {
        AppSnackbar.warning(
          'At least 1 video is required to create a topic.',
          title: 'Video Required',
        );
        throw Exception('At least 1 video is required to create a topic');
      }

      // 0.1 Validate description has at least 10 characters
      if (description.trim().length < 10) {
        AppSnackbar.warning(
          'Topic description must be at least 10 characters.',
          title: 'Description Required',
        );
        throw Exception('Topic description must be at least 10 characters');
      }

      // 1. Validate and clean handle format
      var cleanHandle = handle.trim();
      if (cleanHandle.startsWith('T/') || cleanHandle.startsWith('t/')) {
        cleanHandle = cleanHandle.substring(2);
      }
      cleanHandle = cleanHandle
          .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
          .replaceAll(RegExp('-+'), '-');
      if (cleanHandle.isEmpty) {
        AppSnackbar.warning(
          'Topic handle is required and must contain alphanumeric characters.',
          title: 'Handle Required',
        );
        throw Exception('Topic handle is required');
      }
      final finalHandle = 'T/$cleanHandle';
      final finalHandleLowercase = finalHandle.toLowerCase();

      // Check if handle is already taken
      final existingHandle = await _firestore
          .collection(FirestoreCollections.topics)
          .where('handleLowercase', isEqualTo: finalHandleLowercase)
          .limit(1)
          .get();

      if (existingHandle.docs.isNotEmpty) {
        AppSnackbar.warning(
          'Topic handle is already taken. Please choose a different one.',
          title: 'Handle Taken',
        );
        throw Exception('Topic handle is already taken');
      }

      var slug = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');

      if (slug.trim().isEmpty) {
        slug = 'topic-${const Uuid().v4().substring(0, 8)}';
      }

      final existingSlug = await _firestore
          .collection(FirestoreCollections.topics)
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (existingSlug.docs.isNotEmpty) {
        AppSnackbar.warning(
          'A topic with this title already exists. Please choose a different title.',
          title: 'Title Taken',
        );
        throw Exception('Topic with this title already exists');
      }

      final finalSlug = slug;

      final newTopicRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc();
      final currentUid = AuthService.to.uid.isNotEmpty
          ? AuthService.to.uid
          : FirebaseAuth.instance.currentUser?.uid;

      if (currentUid == null || currentUid.isEmpty) {
        AppSnackbar.warning(
          'Please sign in to create a topic.',
          title: 'Sign In Required',
        );
        throw Exception('User authentication required to create topic.');
      }

      final topic = Topic(
        id: newTopicRef.id,
        title: title.trim(),
        slug: finalSlug,
        handle: finalHandle,
        handleLowercase: finalHandleLowercase,
        description: description.trim(),
        category: category.trim().isEmpty ? 'General' : category.trim(),
        thumbnailUrl: thumbnailUrl,
        channelId: channelId.trim().isNotEmpty
            ? channelId.trim()
            : (AuthService.to.userChannel?.id ?? ''),
        creatorId: currentUid,
        visibilityType: visibilityType,
        accessCode: accessCode,
        videoCount: selectedVideoIds.length,
        featuredVideoIds: selectedVideoIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
        geminiApproved: false,
      );

      // Create the topic document
      await newTopicRef.set(topic.toMap());

      // Link selected videos
      for (final videoId in selectedVideoIds) {
        try {
          final videoRef = _firestore
              .collection(FirestoreCollections.videos)
              .doc(videoId);
          await videoRef.update({
            'topicId': finalSlug,
            'topics': FieldValue.arrayUnion([finalSlug, cleanHandle, newTopicRef.id]),
          });
        } catch (videoLinkErr, s) {
          ErrorHandler.log(
            videoLinkErr,
            stackTrace: s,
            tag: 'TopicManagementController.createTopic.linkVideo',
          );
        }
      }

      // Sync with local reactive controller list
      if (!topicsList.any((t) => t.id == topic.id || t.slug == topic.slug)) {
        topicsList.insert(0, topic);
        topicsList.refresh();
      }

      AppSnackbar.success(
        'Topic created successfully.',
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicManagementController.createTopic',
      );
      final msg = e.toString();
      if (!msg.contains('Video Required') &&
          !msg.contains('Description Required') &&
          !msg.contains('Handle Required') &&
          !msg.contains('Handle Taken') &&
          !msg.contains('Title Taken') &&
          !msg.contains('Sign In Required')) {
        AppSnackbar.error(
          'Unable to create topic. Please try again.',
        );
      }
      rethrow;
    }
  }

  Future<List<String>> fetchTopicVideos(String topicSlug) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.videos)
          .where('topicId', isEqualTo: topicSlug)
          .get();
      return snap.docs.map((doc) => doc.id).toList();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TopicManagementController.fetchTopicVideos',
      );
      return [];
    }
  }

  Future<bool> updateTopic({
    required Topic topic,
    required String title,
    required String description,
    required String category,
    required List<String> selectedVideoIds,
    required TopicVisibilityType visibilityType,
    String? accessCode,
    String? thumbnailUrl,
    bool showSuccessFeedback = false,
  }) async {
    try {
      if (selectedVideoIds.isEmpty) {
        AppSnackbar.warning(
          'A topic must contain at least 1 video.',
          title: 'Video Required',
        );
        return false;
      }

      final wasRejected = topic.status.toLowerCase() == 'verificationrejected' ||
          topic.status.toLowerCase() == 'rejected';
      final newStatus = wasRejected ? 'underReview' : topic.status;
      final newApproved = wasRejected ? false : topic.geminiApproved;

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
        featuredVideoIds: selectedVideoIds,
        updatedAt: DateTime.now(),
        status: newStatus,
        geminiApproved: newApproved,
        moderationReason: wasRejected ? '' : topic.moderationReason,
      );

      final batch = _firestore.batch();
      batch.update(
        _firestore.collection(FirestoreCollections.topics).doc(topic.id),
        {
          ...updatedTopic.toMap(),
          'status': newStatus,
          'geminiApproved': newApproved ?? false,
          if (wasRejected) 'moderationReason': FieldValue.delete(),
        },
      );

      final currentLinkedVideos = await fetchTopicVideos(topic.slug);

      // Videos that were unlinked: remove topicId and topics entry
      for (final videoId in currentLinkedVideos) {
        if (!selectedVideoIds.contains(videoId)) {
          final videoRef = _firestore
              .collection(FirestoreCollections.videos)
              .doc(videoId);
          batch.update(videoRef, {
            'topicId': FieldValue.delete(),
            'topics': FieldValue.arrayRemove([topic.slug, topic.routePathParameter, topic.id]),
          });
        }
      }

      // Videos that were newly linked: set topicId and topics entry
      for (final videoId in selectedVideoIds) {
        if (!currentLinkedVideos.contains(videoId)) {
          final videoRef = _firestore
              .collection(FirestoreCollections.videos)
              .doc(videoId);
          batch.update(videoRef, {
            'topicId': topic.slug,
            'topics': FieldValue.arrayUnion([topic.slug, topic.routePathParameter, topic.id]),
          });
        }
      }

      await batch.commit();

      // Immediately sync with local controller reactive list
      final index = topicsList.indexWhere((t) => t.id == topic.id);
      if (index != -1) {
        topicsList[index] = updatedTopic;
        topicsList.refresh();
      }

      if (showSuccessFeedback) {
        AppSnackbar.success(
          'Topic updated successfully.',
        );
      }
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update topic. Please try again.',
      );
      return false;
    }
  }

  Future<void> deleteTopic(Topic topic) async {
    try {
      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topic.id)
          .update({
            'status': 'deletion_pending',
            'visibilityType': 'private',
            'deletionRequestedAt': FieldValue.serverTimestamp(),
          });
      topicsList.removeWhere((t) => t.id == topic.id);
      AppSnackbar.success(
        'Topic moved to Trash. It will be retained for 30 days.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to move topic to Trash. Please try again.',
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
    AppSnackbar.success(
      'Topic link copied to clipboard.',
      title: 'Link Copied',
    );
  }

  /// Destructive Confirmation Dialog for deleting topic
  void deleteTopicWithConfirmation(BuildContext context, Topic topic) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Move Topic to Trash?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
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
              'Are you sure you want to move "${topic.title}" to Trash?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleted topics are retained for 30 days before permanent deletion. Linked videos will remain safe on your channel.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              deleteTopic(topic);
            },
            icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Move to Trash',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
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
