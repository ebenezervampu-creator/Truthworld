import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:uuid/uuid.dart';

class TopicManagementController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _ensureStorageAuthReady() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
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
      throw Exception("Storage auth preparation failed: $e");
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
          (snapshot) => snapshot.docs
              .map((doc) => Topic.fromDocumentSnapshot(doc))
              .toList(),
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

      final List<Map<String, dynamic>> videos = [];
      final Set<String> seenIds = {};

      void addDocs(List<QueryDocumentSnapshot> docs) {
        for (var doc in docs) {
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
      int videoCount = 0;
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
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return;
        }
      }

      // 2. Validate and clean handle format
      String cleanHandle = handle.trim();
      if (cleanHandle.startsWith('T/')) {
        cleanHandle = cleanHandle.substring(2);
      }
      if (cleanHandle.startsWith('t/')) {
        cleanHandle = cleanHandle.substring(2);
      }
      cleanHandle = cleanHandle
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')
          .replaceAll(RegExp(r'-+'), '-');
      if (cleanHandle.isEmpty) {
        AppSnackbar.show(
          'Validation Error',
          'Topic handle is required and must contain alphanumeric characters.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      final String finalHandle = 'T/$cleanHandle';
      final String finalHandleLowercase = finalHandle.toLowerCase();

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
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final String slug = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');

      final existingSlug = await _firestore
          .collection('topics')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      String finalSlug = slug;
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
        for (var videoId in selectedVideoIds) {
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
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to create topic: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
      for (var videoId in currentLinkedVideos) {
        if (!selectedVideoIds.contains(videoId)) {
          final videoRef = _firestore.collection('videos').doc(videoId);
          batch.update(videoRef, {
            'topicId': FieldValue.delete(),
            'topics': FieldValue.arrayRemove([topic.slug]),
          });
        }
      }

      // Videos that were newly linked: set topicId and topics entry
      for (var videoId in selectedVideoIds) {
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
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to update topic: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
      AppSnackbar.show(
        'Success',
        'Topic is now private and scheduled for deletion in 30 days',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to schedule topic deletion: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
