import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';

class LanguageRequest {
  final String id;
  final String language;
  final String type;
  final dynamic createdAt;
  final int count;

  LanguageRequest({
    required this.id,
    required this.language,
    this.type = '',
    this.createdAt,
    required this.count,
  });

  factory LanguageRequest.fromMap(Map<String, dynamic> map, String id) {
    return LanguageRequest(
      id: id,
      language: map['language'] as String? ?? '',
      type: map['type'] as String? ?? '',
      createdAt: map['createdAt'],
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Controller responsible specifically for video user interactions (likes, dislikes, subscriptions, language requests).
class VideoEngagementController extends BaseController {
  final RxBool isLiked = false.obs;
  final RxBool isDisliked = false.obs;
  final RxBool isSubscribed = false.obs;

  final RxList<LanguageRequest> languageRequests = <LanguageRequest>[].obs;
  final RxBool isLoadingLanguageRequests = false.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> checkUserInteractions(String videoId, String channelId) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty || videoId.isEmpty) return;

    try {
      final futures = await Future.wait([
        _firestore
            .collection(FirestoreCollections.videos)
            .doc(videoId)
            .collection('likes')
            .doc(userId)
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.videos)
            .doc(videoId)
            .collection('dislikes')
            .doc(userId)
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.subscriptions)
            .doc('${channelId}_$userId')
            .getCacheFirst(),
      ]);

      isLiked.value = futures[0].exists;
      isDisliked.value = futures[1].exists;
      isSubscribed.value = futures[2].exists;
    } catch (e) {
      if (!e.toString().contains('permission-denied')) {
        debugPrint(
          '[VideoEngagementController] Error checking interactions: $e',
        );
      }
    }
  }

  Future<void> toggleLike(
    String videoId,
    int defaultLikeCount,
    int defaultDislikeCount,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty || videoId.isEmpty) return;

    final mainController = Get.find<MainController>();
    final wasLiked = isLiked.value;
    final wasDisliked = isDisliked.value;

    isLiked.value = !wasLiked;
    if (isLiked.value) isDisliked.value = false;

    final currentLikes = mainController.videoLikes[videoId] ?? defaultLikeCount;
    final currentDislikes =
        mainController.videoDislikes[videoId] ?? defaultDislikeCount;

    if (isLiked.value) {
      mainController.videoLikes[videoId] = currentLikes + 1;
      if (wasDisliked) {
        mainController.videoDislikes[videoId] = (currentDislikes - 1).clamp(
          0,
          999999999,
        );
      }
    } else {
      mainController.videoLikes[videoId] = (currentLikes - 1).clamp(
        0,
        999999999,
      );
    }

    try {
      await mainController.likeVideo(videoId, userId);
    } catch (e) {
      // Revert on error
      isLiked.value = wasLiked;
      isDisliked.value = wasDisliked;
      mainController.videoLikes[videoId] = currentLikes;
      mainController.videoDislikes[videoId] = currentDislikes;
    }
  }

  Future<void> toggleDislike(
    String videoId,
    int defaultLikeCount,
    int defaultDislikeCount,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty || videoId.isEmpty) return;

    final mainController = Get.find<MainController>();
    final wasLiked = isLiked.value;
    final wasDisliked = isDisliked.value;

    isDisliked.value = !wasDisliked;
    if (isDisliked.value) isLiked.value = false;

    final currentLikes = mainController.videoLikes[videoId] ?? defaultLikeCount;
    final currentDislikes =
        mainController.videoDislikes[videoId] ?? defaultDislikeCount;

    if (isDisliked.value) {
      mainController.videoDislikes[videoId] = currentDislikes + 1;
      if (wasLiked) {
        mainController.videoLikes[videoId] = (currentLikes - 1).clamp(
          0,
          999999999,
        );
      }
    } else {
      mainController.videoDislikes[videoId] = (currentDislikes - 1).clamp(
        0,
        999999999,
      );
    }

    try {
      await mainController.dislikeVideo(videoId, userId);
    } catch (e) {
      // Revert on error
      isLiked.value = wasLiked;
      isDisliked.value = wasDisliked;
      mainController.videoLikes[videoId] = currentLikes;
      mainController.videoDislikes[videoId] = currentDislikes;
    }
  }

  void fetchLanguageRequests(String videoId) {
    if (videoId.isEmpty) return;
    isLoadingLanguageRequests.value = true;
    _firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('language_requests')
        .get()
        .then((snapshot) {
          final requests = snapshot.docs.map((doc) {
            return LanguageRequest.fromMap(doc.data(), doc.id);
          }).toList();
          languageRequests.assignAll(requests);
          isLoadingLanguageRequests.value = false;
        })
        .catchError((e) {
          debugPrint(
            '[VideoEngagementController] Error fetching language requests: $e',
          );
          isLoadingLanguageRequests.value = false;
        });
  }
}
