import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_interaction_cache.dart';

class CommunityPostReactionState {
  const CommunityPostReactionState({
    required this.likes,
    required this.dislikes,
    required this.likedBy,
    required this.dislikedBy,
    required this.isLiked,
    required this.isDisliked,
  });
  final int likes;
  final int dislikes;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final bool isLiked;
  final bool isDisliked;
}

class CommunityPostCardReactionEngine {
  static CommunityPostReactionState toggleLike(
    CommunityPostReactionState previousState,
    String uid,
  ) {
    final hasLiked = previousState.likedBy.contains(uid);

    if (hasLiked) {
      final likedBy = List<String>.from(previousState.likedBy)..remove(uid);
      return CommunityPostReactionState(
        likes: (previousState.likes - 1).clamp(0, 999999999),
        dislikes: previousState.dislikes,
        likedBy: likedBy,
        dislikedBy: previousState.dislikedBy,
        isLiked: false,
        isDisliked: previousState.dislikedBy.contains(uid),
      );
    } else {
      final hadDisliked = previousState.dislikedBy.contains(uid);
      final dislikedBy = hadDisliked
          ? (List<String>.from(previousState.dislikedBy)..remove(uid))
          : previousState.dislikedBy;
      final likedBy = List<String>.from(previousState.likedBy);
      if (!likedBy.contains(uid)) {
        likedBy.add(uid);
      }
      return CommunityPostReactionState(
        likes: previousState.likes + 1,
        dislikes: hadDisliked
            ? (previousState.dislikes - 1).clamp(0, 999999999)
            : previousState.dislikes,
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: true,
        isDisliked: false,
      );
    }
  }

  static CommunityPostReactionState toggleDislike(
    CommunityPostReactionState previousState,
    String uid,
  ) {
    final hasDisliked = previousState.dislikedBy.contains(uid);

    if (hasDisliked) {
      final dislikedBy = List<String>.from(previousState.dislikedBy)..remove(uid);
      return CommunityPostReactionState(
        likes: previousState.likes,
        dislikes: (previousState.dislikes - 1).clamp(0, 999999999),
        likedBy: previousState.likedBy,
        dislikedBy: dislikedBy,
        isLiked: previousState.likedBy.contains(uid),
        isDisliked: false,
      );
    } else {
      final hadLiked = previousState.likedBy.contains(uid);
      final likedBy = hadLiked
          ? (List<String>.from(previousState.likedBy)..remove(uid))
          : previousState.likedBy;
      final dislikedBy = List<String>.from(previousState.dislikedBy);
      if (!dislikedBy.contains(uid)) {
        dislikedBy.add(uid);
      }
      return CommunityPostReactionState(
        likes: hadLiked
            ? (previousState.likes - 1).clamp(0, 999999999)
            : previousState.likes,
        dislikes: previousState.dislikes + 1,
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: false,
        isDisliked: true,
      );
    }
  }
}

class CommunityPostController extends BaseController with ContentValidationMixin {
  CommunityPostController({required CommunityPostModel post})
    : _initialPost = post;

  final CommunityPostModel _initialPost;
  CommunityPostModel get post => _initialPost;

  late final Rx<CommunityPostReactionState> reactionState;
  final RxInt commentCount = 0.obs;
  final RxBool isSaved = false.obs;
  final RxBool isHidden = false.obs;

  final TextEditingController commentController = TextEditingController();

  String? get currentUid =>
      Get.isRegistered<AuthService>() ? AuthService.to.currentUser.value?.uid : null;

  @override
  void onInit() {
    super.onInit();
    final likedBy = List<String>.from(post.likedBy);
    final dislikedBy = List<String>.from(post.dislikedBy);
    final uid = currentUid;

    reactionState = CommunityPostReactionState(
      likes: post.likes,
      dislikes: post.dislikes,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      isLiked: uid != null && likedBy.contains(uid),
      isDisliked: uid != null && dislikedBy.contains(uid),
    ).obs;

    commentCount.value = post.commentCount;

    _checkSavedStatus();
    _checkHiddenStatus();
  }

  @override
  void onClose() {
    commentController.dispose();
    super.onClose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get commentsStream =>
      FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .doc(post.id)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots();

  Future<void> _checkHiddenStatus() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      await CommunityInteractionCache.ensureInitialized(uid);
      if (CommunityInteractionCache.isHidden(post.id, post.channelId)) {
        isHidden.value = true;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController._checkHiddenStatus');
    }
  }

  Future<void> _checkSavedStatus() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      await CommunityInteractionCache.ensureInitialized(uid);
      isSaved.value = CommunityInteractionCache.isSaved(post.id);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController._checkSavedStatus');
    }
  }

  Future<void> toggleLike() async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to like posts.');
      return;
    }

    final previousState = reactionState.value;

    final likedBy = [...previousState.likedBy];
    final dislikedBy = [...previousState.dislikedBy];
    final hasLiked = likedBy.contains(uid);

    late CommunityPostReactionState nextState;

    if (hasLiked) {
      likedBy.remove(uid);
      nextState = CommunityPostReactionState(
        likes: (previousState.likes - 1).clamp(0, 999999999),
        dislikes: previousState.dislikes,
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: false,
        isDisliked: dislikedBy.contains(uid),
      );
    } else {
      final hadDisliked = dislikedBy.remove(uid);
      if (!likedBy.contains(uid)) {
        likedBy.add(uid);
      }
      nextState = CommunityPostReactionState(
        likes: previousState.likes + 1,
        dislikes: hadDisliked
            ? (previousState.dislikes - 1).clamp(0, 999999999)
            : previousState.dislikes,
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: true,
        isDisliked: false,
      );
    }

    reactionState.value = nextState;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .doc(post.id);
      final updates = <String, dynamic>{};

      if (previousState.isLiked && !nextState.isLiked) {
        updates['likes'] = FieldValue.increment(-1);
        updates['likedby'] = FieldValue.arrayRemove([uid]);
      } else if (!previousState.isLiked && nextState.isLiked) {
        updates['likes'] = FieldValue.increment(1);
        updates['likedby'] = FieldValue.arrayUnion([uid]);
      }

      if (previousState.isDisliked && !nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(-1);
        updates['dislikedby'] = FieldValue.arrayRemove([uid]);
      } else if (!previousState.isDisliked && nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(1);
        updates['dislikedby'] = FieldValue.arrayUnion([uid]);
      }

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.toggleLike');
      reactionState.value = previousState;
    }
  }

  Future<void> toggleDislike() async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to dislike posts.');
      return;
    }

    final previousState = reactionState.value;

    final likedBy = [...previousState.likedBy];
    final dislikedBy = [...previousState.dislikedBy];
    final hasDisliked = dislikedBy.contains(uid);

    late CommunityPostReactionState nextState;

    if (hasDisliked) {
      dislikedBy.remove(uid);
      nextState = CommunityPostReactionState(
        likes: previousState.likes,
        dislikes: (previousState.dislikes - 1).clamp(0, 999999999),
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: likedBy.contains(uid),
        isDisliked: false,
      );
    } else {
      final hadLiked = likedBy.remove(uid);
      if (!dislikedBy.contains(uid)) {
        dislikedBy.add(uid);
      }
      nextState = CommunityPostReactionState(
        likes: hadLiked
            ? (previousState.likes - 1).clamp(0, 999999999)
            : previousState.likes,
        dislikes: previousState.dislikes + 1,
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: false,
        isDisliked: true,
      );
    }

    reactionState.value = nextState;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .doc(post.id);
      final updates = <String, dynamic>{};

      if (previousState.isDisliked && !nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(-1);
        updates['dislikedby'] = FieldValue.arrayRemove([uid]);
      } else if (!previousState.isDisliked && nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(1);
        updates['dislikedby'] = FieldValue.arrayUnion([uid]);
      }

      if (previousState.isLiked && !nextState.isLiked) {
        updates['likes'] = FieldValue.increment(-1);
        updates['likedby'] = FieldValue.arrayRemove([uid]);
      } else if (!previousState.isLiked && nextState.isLiked) {
        updates['likes'] = FieldValue.increment(1);
        updates['likedby'] = FieldValue.arrayUnion([uid]);
      }

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.toggleDislike');
      reactionState.value = previousState;
    }
  }

  Future<void> toggleBookmark() async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to save posts.');
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection('savedCommunityPosts')
        .doc(post.id);

    try {
      if (isSaved.value) {
        isSaved.value = false;
        CommunityInteractionCache.setSaved(post.id, false);
        await docRef.delete();
        showSuccess('Post removed from Saved Posts');
      } else {
        isSaved.value = true;
        CommunityInteractionCache.setSaved(post.id, true);
        final data = post.toMap();
        data['savedAt'] = FieldValue.serverTimestamp();
        await docRef.set(data);
        showSuccess('Post saved to Saved Posts');
      }
    } catch (e) {
      isSaved.value = !isSaved.value;
      CommunityInteractionCache.setSaved(post.id, isSaved.value);
      ErrorHandler.log(e, tag: 'CommunityPostController');
      showError('Unable to save post. Please try again.');
    }
  }

  Future<void> hidePost() async {
    isHidden.value = true;
    CommunityInteractionCache.markHidden(post.id);
    final uid = currentUid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection('hiddenCommunityPosts')
            .doc(post.id)
            .set({
              'postId': post.id,
              'hiddenAt': FieldValue.serverTimestamp(),
            });
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.hidePost');
      }
    }
    showSuccess('Post hidden from your feed');
  }

  Future<void> turnOffChannelPosts() async {
    isHidden.value = true;
    CommunityInteractionCache.markChannelMuted(post.channelId);
    final uid = currentUid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection('mutedCommunityChannels')
            .doc(post.channelId)
            .set({
              'channelId': post.channelId,
              'channelName': post.channelName,
              'mutedAt': FieldValue.serverTimestamp(),
            });
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.turnOffChannelPosts');
      }
    }
    showSuccess('Community posts from ${post.channelName} turned off');
  }

  Future<void> unsubscribeChannel() async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to manage subscriptions.');
      return;
    }
    try {
      final channelCtrl = Get.isRegistered<ChannelController>()
          ? Get.find<ChannelController>()
          : Get.put(ChannelController());
      await channelCtrl.unsubscribeFromChannel(post.channelId);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.unsubscribeChannel.ctrl');
    }

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.subscriptions)
          .doc('${post.channelId}_$uid')
          .delete();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.unsubscribeChannel.subscriptions');
    }

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.subscriptions)
          .doc(post.channelId)
          .delete();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.unsubscribeChannel.userSubscriptions');
    }

    showSuccess('Unsubscribed from ${post.channelName}');
  }

  Future<void> submitReport(String reason, String details) async {
    final uid = currentUid;
    if (uid == null) return;

    if (details.trim().isNotEmpty) {
      final detailsVal = await validateContent(details, fieldName: 'Report details');
      if (!detailsVal.isValid) {
        showWarning(detailsVal.message);
        return;
      }
    }

    isHidden.value = true;
    CommunityInteractionCache.markReported(post.id);

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .add({
            'postId': post.id,
            'channelId': post.channelId,
            'userId': uid,
            'reportedBy': uid,
            'reason': reason,
            'details': details,
            'reportedAt': FieldValue.serverTimestamp(),
            'type': 'community_post',
          });

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('reportedCommunityPosts')
          .doc(post.id)
          .set({
            'postId': post.id,
            'reason': reason,
            'reportedAt': FieldValue.serverTimestamp(),
          });
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.submitReport');
    }

    showSuccess(
      'Thank you for reporting. This post has been hidden from your feed.',
    );
  }

  Future<void> updateCountSettings(bool showLike, bool showDislike) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .doc(post.id)
          .update({
            'showLikeCount': showLike,
            'showDislikeCount': showDislike,
          });
      showSuccess('Post count settings updated.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'CommunityPostController');
      showError('Unable to update settings. Please try again.');
    }
  }

  Future<void> moveToTrash() async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to delete posts.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .doc(post.id)
          .update({
        'status': 'deletion_pending',
        'visibility': 'private',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      isHidden.value = true;
      showSuccess('Post moved to Trash. It will be retained for 30 days.');
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostController.moveToTrash');
      showError('Unable to move post to Trash. Please try again.');
    }
  }

  Future<void> submitComment(String text) async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to comment.');
      return;
    }

    if (text.trim().isEmpty) return;

    final validation = await validateContent(text, fieldName: 'Comment');
    if (!validation.isValid) {
      showWarning(validation.message);
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    final commentRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.community)
        .doc(post.id)
        .collection('comments')
        .doc();

    final postRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.community)
        .doc(post.id);

    final activeDisplayName = AuthService.to.activeDisplayName;
    final activePhotoUrl = AuthService.to.activePhotoUrl;
    final activeHandle = AuthService.to.activeHandle;
    final isChannel = AuthService.to.hasChannel.value;

    batch.set(commentRef, {
      'id': commentRef.id,
      'userId': uid,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'dislikes': 0,
      'repliesCount': 0,
      'userName': activeDisplayName,
      'userImage': activePhotoUrl,
      'userHandle': activeHandle,
      'isChannel': isChannel,
      if (isChannel && AuthService.to.userChannel != null)
        'channelId': AuthService.to.userChannel!.id,
    });

    batch.update(postRef, {'commentCount': FieldValue.increment(1)});

    try {
      await batch.commit();
      commentCount.value++;
      commentController.clear();
      showSuccess('Comment added successfully');
    } catch (e) {
      ErrorHandler.log(e, tag: 'CommunityPostController');
      showError('Unable to add comment. Please try again.');
    }
  }
}
