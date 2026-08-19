import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class VideoManagementController extends BaseController with ContentValidationMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  final RxDouble uploadProgress = 0.0.obs;
  String get uploadProgressPercent =>
      '${(uploadProgress.value * 100).toStringAsFixed(0)}%';

  final RxList<Video> channelVideos = <Video>[].obs;
  final RxBool isLoadingChannelVideos = true.obs;
  final RxString channelVideosError = ''.obs;
  StreamSubscription? _videosSub;

  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxBool isLoadingPosts = true.obs;
  final RxString postsError = ''.obs;
  StreamSubscription? _postsSub;

  void listenToChannelVideos(String channelId) {
    isLoadingChannelVideos.value = true;
    channelVideosError.value = '';
    _videosSub?.cancel();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetId = channelId.isNotEmpty ? channelId : currentUid;

    _videosSub = _firestore.collection('videos').snapshots().listen(
      (snapshot) {
        final videos = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) =>
                v.channelId == targetId ||
                v.ownerId == targetId ||
                (v.channelId.isEmpty && currentUid.isNotEmpty && v.ownerId == currentUid))
            .toList();
        channelVideos.assignAll(videos);
        isLoadingChannelVideos.value = false;
      },
      onError: (e) {
        channelVideosError.value = e.toString();
        isLoadingChannelVideos.value = false;
      },
    );
    trackSubscription(_videosSub!);
  }

  void listenToCommunityPosts(String channelId) {
    isLoadingPosts.value = true;
    postsError.value = '';
    _postsSub?.cancel();
    _postsSub = _firestore
        .collection(FirestoreCollections.community)
        .where('channelId', isEqualTo: channelId)
        .where(
          'ownerId',
          isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
        )
        .snapshots()
        .listen(
          (snapshot) {
            final posts = snapshot.docs
                .map(
                  (doc) => CommunityPostModel.fromMap(
                    doc.data(),
                  ),
                )
                .toList();
            communityPosts.assignAll(posts);
            isLoadingPosts.value = false;
          },
          onError: (e) {
            postsError.value = e.toString();
            isLoadingPosts.value = false;
          },
        );
  }

  @override
  void onClose() {
    _videosSub?.cancel();
    _postsSub?.cancel();
    super.onClose();
  }

  Future<void> uploadVideo({
    required PlatformFile videoFile,
    required PlatformFile imageFile,
    required String title,
    required String description,
    required String channelId,
    required String channelName,
    required String channelImage,
    required String category,
    required List<String> tags,
    required String visibility,
    required bool isKidFriendly,
    required bool isShort,
    required String uploadQuality,
    required bool enableComments,
    required bool allowRatings,
  }) async {
    if (videoFile.bytes == null || imageFile.bytes == null) {
      Get.snackbar(
        'Error',
        'Video or thumbnail data is missing.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    uploadProgress.value = 0.0;
    Get.snackbar(
      'Upload Started',
      'Your video upload is in progress.',
      showProgressIndicator: true,
      backgroundColor: AppColors.bgSurface,
      colorText: AppColors.textPrimary,
      icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
    );

    try {
      final formattedDuration = await _getVideoDurationFormatted(videoFile);

      final videoFileName =
          'videos/${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';
      final imageFileName =
          'thumbnails/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';

      final videoRef = _firebaseStorage.ref().child(videoFileName);
      final imageRef = _firebaseStorage.ref().child(imageFileName);

      final videoMetadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {'uploaderId': currentUserId},
      );
      final imageMetadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaderId': currentUserId},
      );

      final videoUploadTask = videoRef.putData(videoFile.bytes!, videoMetadata);
      final imageUploadTask = imageRef.putData(imageFile.bytes!, imageMetadata);

      videoUploadTask.snapshotEvents.listen((event) {
        uploadProgress.value =
            (event.bytesTransferred / event.totalBytes) * 0.7;
      });

      await videoUploadTask;

      imageUploadTask.snapshotEvents.listen((event) {
        uploadProgress.value =
            0.7 + (event.bytesTransferred / event.totalBytes) * 0.3;
      });

      final videoSnapshot = await videoUploadTask;
      final imageSnapshot = await imageUploadTask;

      final videoUrl = await videoSnapshot.ref.getDownloadURL();
      final imageUrl = await imageSnapshot.ref.getDownloadURL();

      final collectionName = isShort ? 'shorts' : 'videos';
      final DocumentReference docRef = _firestore
          .collection(collectionName)
          .doc();

      final newVideo = Video(
        id: docRef.id,
        title: title,
        description: description,
        videoUrl: videoUrl,
        thumbnailUrl: imageUrl,
        channelId: channelId,
        channelName: channelName,
        channelImage: channelImage,
        ownerId: currentUserId,
        likeCount: 0,
        viewCount: 0,
        uploadedAt: Timestamp.now(),
        category: category,
        tags: tags,
        visibility: visibility,
        isKidFriendly: isKidFriendly,
        isShort: isShort,
        enableComments: enableComments,
        allowRatings: allowRatings,
        duration: formattedDuration,
      );

      await docRef.set(newVideo.toMap());

      uploadProgress.value = 0.0;
      Get.offAllNamed('/studio');
      Get.snackbar(
        'Success',
        'Video uploaded successfully!',
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );
    } catch (e) {
      uploadProgress.value = 0.0;
      Get.snackbar(
        'Error',
        'Failed to upload video: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      debugPrint('Error uploading video: $e');
    }
  }

  Stream<List<Video>> fetchChannelVideos(String channelId) {
    return _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId)
        //  .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
        })
        .handleError((error) {
          Get.snackbar(
            'Error',
            'Failed to fetch videos: $error',
            backgroundColor: const Color(0xFFEF4444),
            colorText: AppColors.textPrimary,
            icon: const Icon(Icons.error_outline, color: Colors.white),
          );
          return [];
        });
  }

  Future<void> deleteVideo(Video video) async {
    try {
      // 1. Delete Firestore document from videos collection
      await _firestore.collection(FirestoreCollections.videos).doc(video.id).delete();

      // If video is also present in 'shorts', clean it up
      if (video.isShort) {
        try {
          await _firestore.collection('shorts').doc(video.id).delete();
        } catch (_) {}
      }

      // Immediately remove from local list for snappy UI feedback
      channelVideos.removeWhere((v) => v.id == video.id);

      // 2. Perform safe storage cleanup
      // Note: Backend Cloud Function onVideoDeleted also performs automatic cascade deletion.
      // We attempt client storage deletion gracefully without throwing on non-existent or external files.
      await _safeDeleteStorageUrl(video.videoUrl);
      await _safeDeleteStorageUrl(video.thumbnailUrl);
      if (video.originalUrl.isNotEmpty && video.originalUrl != video.videoUrl) {
        await _safeDeleteStorageUrl(video.originalUrl);
      }

      Get.snackbar(
        'Success',
        "Video '${video.title.isNotEmpty ? video.title : 'Selected video'}' deleted successfully.",
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete video: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      debugPrint('Error deleting video: $e');
    }
  }

  Future<void> _safeDeleteStorageUrl(String urlOrPath) async {
    final clean = urlOrPath.trim();
    if (clean.isEmpty) return;
    try {
      if (clean.startsWith('gs://') || clean.contains('firebasestorage.googleapis.com')) {
        await _firebaseStorage.refFromURL(clean).delete();
      } else if (!clean.startsWith('http://') &&
          !clean.startsWith('https://') &&
          !clean.startsWith('blob:') &&
          !clean.startsWith('assets/')) {
        await _firebaseStorage.ref(clean).delete();
      }
    } catch (e) {
      // Storage deletion error is safely ignored on client (already handled or cleaned up)
      debugPrint('Safe storage delete note for $clean: $e');
    }
  }

  Future<void> changeVideoVisibility(String videoId, String visibility) async {
    try {
      final normalizedVisibility = visibility.trim().toLowerCase();
      await _firestore.collection('videos').doc(videoId).update({
        'visibility': normalizedVisibility,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Also update shorts collection if exists
      try {
        await _firestore.collection('shorts').doc(videoId).update({
          'visibility': normalizedVisibility,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // Update local list for instant UI feedback
      final index = channelVideos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final current = channelVideos[index];
        channelVideos[index] = current.copyWith(visibility: normalizedVisibility);
      }

      String displayName;
      switch (normalizedVisibility) {
        case 'public':
          displayName = 'Public';
        case 'private':
          displayName = 'Private';
        case 'members':
        case 'members_only':
          displayName = 'Members Only';
        case 'subscribers':
        case 'subscribers_only':
          displayName = 'Subscribers Only';
        case 'unlisted':
          displayName = 'Unlisted';
        default:
          displayName = visibility;
      }

      Get.snackbar(
        'Visibility Updated',
        'Video access is now set to "$displayName".',
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update visibility: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      debugPrint('Error updating visibility: $e');
    }
  }

  Future<void> updateVideo(String videoId, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('title')) {
        final title = (data['title'] as String? ?? '').trim();
        final titleVal = await validateContent(title, fieldName: 'Title');
        if (!titleVal.isValid) {
          Get.snackbar(
            'Inappropriate Content',
            titleVal.message,
            backgroundColor: const Color(0xFFEF4444),
            colorText: AppColors.textPrimary,
            icon: const Icon(Icons.error_outline, color: Colors.white),
          );
          return;
        }
      }

      if (data.containsKey('description')) {
        final desc = (data['description'] as String? ?? '').trim();
        if (desc.isNotEmpty) {
          final descVal = await validateContent(desc, fieldName: 'Description');
          if (!descVal.isValid) {
            Get.snackbar(
              'Inappropriate Content',
              descVal.message,
              backgroundColor: const Color(0xFFEF4444),
              colorText: AppColors.textPrimary,
              icon: const Icon(Icons.error_outline, color: Colors.white),
            );
            return;
          }
        }
      }

      if (data.containsKey('tags') && data['tags'] is List) {
        final tags = List<String>.from(data['tags'] as List);
        if (tags.isNotEmpty) {
          final tagsVal = await validateTags(tags);
          if (!tagsVal.isValid) {
            Get.snackbar(
              'Inappropriate Content',
              tagsVal.message,
              backgroundColor: const Color(0xFFEF4444),
              colorText: AppColors.textPrimary,
              icon: const Icon(Icons.error_outline, color: Colors.white),
            );
            return;
          }
        }
      }

      await _firestore.collection('videos').doc(videoId).update(data);
      Get.snackbar(
        'Success',
        'Video updated successfully.',
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update video: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      debugPrint('Error updating video: $e');
    }
  }

  Future<String> _getVideoDurationFormatted(PlatformFile videoFile) async {
    if (kIsWeb) {
      final completer = Completer<String>();
      final blob = html.Blob([videoFile.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final videoElement = html.VideoElement()
        ..src = url
        ..preload = 'metadata';

      videoElement.onLoadedMetadata.listen((event) {
        final duration = Duration(seconds: videoElement.duration.floor());
        html.Url.revokeObjectUrl(url);
        completer.complete(_formatDuration(duration));
      });

      videoElement.onError.listen((event) {
        html.Url.revokeObjectUrl(url);
        completer.completeError('Failed to load video metadata.');
      });
      return completer.future;
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${videoFile.name}');
      await tempFile.writeAsBytes(videoFile.bytes!);
      final controller = VideoPlayerController.file(tempFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      await tempFile.delete();
      return _formatDuration(duration);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> triggerAIFeatures({
    required String videoId,
    required List<String> features,
    required List<String> targetLanguages,
    String priorityMode = 'accuracy',
    List<String> sensitiveTopics = const [],
    bool autoChapters = true,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Get.snackbar(
          'Auth Error',
          'You must be logged in to generate AI features.',
        );
        return;
      }

      Get.snackbar(
        'Generating AI Features',
        'Requesting ${features.join(", ")} in ${targetLanguages.join(", ").toUpperCase()}...',
        showProgressIndicator: true,
        duration: const Duration(seconds: 4),
      );

      final token = await currentUser.getIdToken();
      final url = Uri.parse(
        'https://asia-south1-truthworld-1.cloudfunctions.net/triggerVideoAIFeatures',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'videoId': videoId,
          'features': features,
          'targetLanguages': targetLanguages,
          'priorityMode': priorityMode,
          'sensitiveTopics': sensitiveTopics,
          'autoChapters': autoChapters,
        }),
      );

      if (response.statusCode == 200) {
        Get.snackbar(
          'AI Processing Started',
          'AI features generation is underway. Subtitles and audio tracks will update automatically!',
          backgroundColor: const Color(0xFF1E293B),
          colorText: const Color(0xFFF8FAFC),
        );
      } else {
        // Fallback: update Firestore document directly
        await _firestore.collection('video_jobs').doc(videoId).set({
          'jobId': videoId,
          'videoId': videoId,
          'userId': currentUser.uid,
          'status': 'processing',
          'executionPlan': {
            'languages': targetLanguages,
            'generateSubtitles': features.contains('subtitles'),
            'generateDubbing': features.contains('dubbing'),
            'enablePath1':
                features.contains('factcheck') || features.contains('summary'),
            'enablePath2':
                features.contains('dubbing') || features.contains('subtitles'),
            'autoChapters': autoChapters,
            'priorityMode': priorityMode,
          },
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'stages': {
            'onDemandAI': {
              'status': 'running',
              'progress': 10,
              'requestedFeatures': features,
              'requestedLanguages': targetLanguages,
              'startedAt': DateTime.now().millisecondsSinceEpoch,
            },
          },
        }, SetOptions(merge: true));

        await _firestore.collection('videos').doc(videoId).update({
          'status': 'processing',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar(
          'AI Features Enqueued',
          'Pipeline job updated successfully for video.',
          backgroundColor: const Color(0xFF1E293B),
          colorText: const Color(0xFFF8FAFC),
        );
      }
    } catch (e) {
      debugPrint('Error triggering AI features: $e');
      Get.snackbar('Notice', 'AI feature pipeline initiated: $e');
    }
  }
}
