import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
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

  String? _activeChannelId;

  void ensureInitialized(String channelId) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetId = channelId.isNotEmpty ? channelId : currentUid;

    if (_activeChannelId == targetId && _videosSub != null && _postsSub != null) {
      return;
    }
    _activeChannelId = targetId;
    listenToChannelVideos(targetId);
    listenToCommunityPosts(targetId);
  }

  String get activeChannelId => _activeChannelId ?? '';
  void refreshChannelVideos() => fetchChannelVideos();
  void refreshCommunityPosts() => fetchCommunityPosts();

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
      onError: (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoManagementController.listenToChannelVideos',
        );
        channelVideosError.value = 'Unable to load videos. Please check your connection and try again.';
        isLoadingChannelVideos.value = false;
      },
    );
    trackSubscription(_videosSub!);
  }

  void listenToCommunityPosts(String channelId) {
    isLoadingPosts.value = true;
    postsError.value = '';
    _postsSub?.cancel();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetId = channelId.isNotEmpty ? channelId : currentUid;

    _postsSub = _firestore
        .collection(FirestoreCollections.community)
        .snapshots()
        .listen(
          (snapshot) {
            final posts = snapshot.docs
                .map(
                  (doc) => CommunityPostModel.fromMap(
                    doc.data(),
                  ),
                )
                .where((p) =>
                    p.channelId == targetId ||
                    p.ownerId == targetId ||
                    (p.channelId.isEmpty && currentUid.isNotEmpty && p.ownerId == currentUid))
                .toList();
            communityPosts.assignAll(posts);
            isLoadingPosts.value = false;
          },
          onError: (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'VideoManagementController.listenToCommunityPosts',
            );
            postsError.value = 'Unable to load community posts. Please check your connection and try again.';
            isLoadingPosts.value = false;
          },
        );
    trackSubscription(_postsSub!);
  }

  void fetchChannelVideos([String? channelId]) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetId = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : (_activeChannelId?.isNotEmpty == true ? _activeChannelId! : currentUid);
    listenToChannelVideos(targetId);
  }

  void fetchCommunityPosts([String? channelId]) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetId = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : (_activeChannelId?.isNotEmpty == true ? _activeChannelId! : currentUid);
    listenToCommunityPosts(targetId);
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
      AppSnackbar.warning(
        'Video or thumbnail data is missing. Please select both files.',
      );
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    uploadProgress.value = 0.0;
    AppSnackbar.info(
      'Your video upload is in progress.',
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

      final UploadTask videoUploadTask;
      final UploadTask imageUploadTask;

      if (kIsWeb) {
        if (videoFile.bytes == null || imageFile.bytes == null) {
          throw Exception('Media bytes are null on Web platform');
        }
        videoUploadTask = videoRef.putData(videoFile.bytes!, videoMetadata);
        imageUploadTask = imageRef.putData(imageFile.bytes!, imageMetadata);
      } else {
        if (videoFile.path != null && File(videoFile.path!).existsSync()) {
          videoUploadTask = videoRef.putFile(File(videoFile.path!), videoMetadata);
        } else if (videoFile.bytes != null) {
          videoUploadTask = videoRef.putData(videoFile.bytes!, videoMetadata);
        } else {
          throw Exception('Video file missing path and bytes');
        }

        if (imageFile.path != null && File(imageFile.path!).existsSync()) {
          imageUploadTask = imageRef.putFile(File(imageFile.path!), imageMetadata);
        } else if (imageFile.bytes != null) {
          imageUploadTask = imageRef.putData(imageFile.bytes!, imageMetadata);
        } else {
          throw Exception('Image file missing path and bytes');
        }
      }

      videoUploadTask.snapshotEvents.listen(
        (event) {
          uploadProgress.value =
              (event.bytesTransferred / event.totalBytes) * 0.7;
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoManagementController.videoUpload',
        ),
      );

      await videoUploadTask;

      imageUploadTask.snapshotEvents.listen(
        (event) {
          uploadProgress.value =
              0.7 + (event.bytesTransferred / event.totalBytes) * 0.3;
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoManagementController.imageUpload',
        ),
      );

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
      AppSnackbar.success(
        'Video uploaded successfully!',
      );
    } catch (e) {
      uploadProgress.value = 0.0;
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to upload video. Please try again.',
      );
    }
  }

  Stream<List<Video>> streamChannelVideos(String channelId) {
    return _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId)
        //  .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
        })
        .handleError((error) {
          ErrorHandler.log(error);
          AppSnackbar.error(
            'Unable to load videos. Please try again.',
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
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'VideoManagement.deleteShortDoc',
          );
        }
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

      AppSnackbar.success(
        "Video '${video.title.isNotEmpty ? video.title : 'Selected video'}' deleted successfully.",
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to delete video. Please try again.',
      );
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoManagement.safeDeleteStorageUrl',
      );
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
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoManagement.updateShortVisibility',
        );
      }

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

      AppSnackbar.success(
        'Video access is now set to "$displayName".',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update video visibility. Please try again.',
      );
    }
  }

  Future<void> batchChangeVideoVisibility(List<String> videoIds, String visibility) async {
    for (final id in videoIds) {
      await changeVideoVisibility(id, visibility);
    }
  }

  Future<void> batchDeleteVideos(List<Video> videos) async {
    for (final v in videos) {
      await deleteVideo(v);
    }
  }

  Future<void> updateVideo(String videoId, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('title')) {
        final title = (data['title'] as String? ?? '').trim();
        final titleVal = await validateContent(title, fieldName: 'Title');
        if (!titleVal.isValid) {
          AppSnackbar.warning(
            titleVal.message,
          );
          return;
        }
      }

      if (data.containsKey('description')) {
        final desc = (data['description'] as String? ?? '').trim();
        if (desc.isNotEmpty) {
          final descVal = await validateContent(desc, fieldName: 'Description');
          if (!descVal.isValid) {
            AppSnackbar.warning(
              descVal.message,
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
            AppSnackbar.warning(
              tagsVal.message,
            );
            return;
          }
        }
      }

      await _firestore.collection('videos').doc(videoId).update(data);
      AppSnackbar.success(
        'Video updated successfully.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update video. Please try again.',
      );
    }
  }

  Future<String> _getVideoDurationFormatted(PlatformFile videoFile) async {
    if (kIsWeb) {
      final bytes = videoFile.bytes;
      if (bytes == null) {
        return _formatDuration(Duration.zero);
      }
      final duration = await WebPlatformUtils.getVideoDurationFromBytes(bytes);
      return _formatDuration(duration ?? Duration.zero);
    } else {
      final File targetFile;
      var shouldDelete = false;
      if (videoFile.path != null && File(videoFile.path!).existsSync()) {
        targetFile = File(videoFile.path!);
      } else {
        final tempDir = await getTemporaryDirectory();
        targetFile = File('${tempDir.path}/${videoFile.name}');
        if (videoFile.bytes != null) {
          await targetFile.writeAsBytes(videoFile.bytes!);
          shouldDelete = true;
        }
      }
      final controller = VideoPlayerController.file(targetFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      if (shouldDelete) {
        await targetFile.delete().catchError((_) => targetFile);
      }
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
    int durationSeconds = 0,
    Channel? channel,
    String priorityMode = 'accuracy',
    List<String> sensitiveTopics = const [],
    bool autoChapters = true,
    String factCheckTier = 'standard',
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppSnackbar.warning('Please sign in to generate AI features.');
        return;
      }

      // Validate and debit channel balance for dubbing (Dubbing is NOT free)
      if (features.contains('dubbing') && channel != null) {
        final walletService = ChannelWalletService();
        final balance = await walletService.getSpendableBalanceForChannelId(channel.id);
        final dubbingLanguages = targetLanguages.where(isDubbingSupported).toList();
        final dubbingCost = ChannelWalletService.calculateDubbingCost(
          languageCount: dubbingLanguages.length,
          durationSeconds: durationSeconds,
          channelType: channel.channelType,
        );

        if (!balance.canAfford(dubbingCost)) {
          final rate = ChannelWalletService.getFlatDubbingPricePerLanguage(
            durationSeconds: durationSeconds,
            channelType: channel.channelType,
          );
          AppSnackbar.warning(
            'Dubbing is not free. Your channel balance of \$${balance.totalSpendableBalance.toStringAsFixed(2)} is insufficient for the flat dubbing cost of \$${dubbingCost.toStringAsFixed(2)} (\$${rate.toStringAsFixed(2)}/lang × ${dubbingLanguages.length} languages for ${durationSeconds}s video). Please add funds to your wallet.',
          );
          return;
        }

        // Deduct from channel balance
        await walletService.spendForVideoAIFeatures(
          channel: channel,
          userId: currentUser.uid,
          videoId: videoId,
          videoTitle: 'Video #$videoId',
          features: features.toSet(),
          targetLanguages: targetLanguages,
          durationSeconds: durationSeconds,
          priorityMode: priorityMode,
          autoChapters: autoChapters,
          factCheckTier: factCheckTier,
        );
      }

      AppSnackbar.info(
        'Requesting ${features.join(", ")} in ${targetLanguages.join(", ").toUpperCase()}...',
      );

      final token = await currentUser.getIdToken();
      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/triggerVideoAIFeatures',
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
          'durationSeconds': durationSeconds,
          'priorityMode': priorityMode,
          'sensitiveTopics': sensitiveTopics,
          'autoChapters': autoChapters,
          'factCheckTier': factCheckTier,
        }),
      );

      if (response.statusCode == 200) {
        AppSnackbar.success(
          'AI features generation is underway. Subtitles and audio tracks will update automatically!',
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
            'durationSeconds': durationSeconds,
            'factCheckTier': factCheckTier,
            'enablePath1': features.contains('factcheck'),
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

        AppSnackbar.success(
          'Pipeline job updated successfully for video.',
        );
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'VideoManagement');
      AppSnackbar.error('Unable to initiate AI feature pipeline. Please try again.');
    }
  }
}
