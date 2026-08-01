import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';

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
    final likedBy = List<String>.from(previousState.likedBy);
    final dislikedBy = List<String>.from(previousState.dislikedBy);
    final hasLiked = likedBy.contains(uid);

    if (hasLiked) {
      likedBy.remove(uid);
      return CommunityPostReactionState(
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
    final likedBy = List<String>.from(previousState.likedBy);
    final dislikedBy = List<String>.from(previousState.dislikedBy);
    final hasDisliked = dislikedBy.contains(uid);

    if (hasDisliked) {
      dislikedBy.remove(uid);
      return CommunityPostReactionState(
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

class CommunityPostController extends BaseController {
  CommunityPostController({required CommunityPostModel post})
    : _initialPost = post;

  final CommunityPostModel _initialPost;
  CommunityPostModel get post => _initialPost;

  late final Rx<CommunityPostReactionState> reactionState;
  final RxInt commentCount = 0.obs;
  final RxBool isSaved = false.obs;
  final RxBool isHidden = false.obs;

  final TextEditingController commentController = TextEditingController();

  String? get currentUid => AuthService.to.currentUser.value?.uid;

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
          .snapshots();

  Future<void> _checkHiddenStatus() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      final hiddenDocFuture = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('hiddenCommunityPosts')
          .doc(post.id)
          .get();
      final mutedChannelFuture = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('mutedCommunityChannels')
          .doc(post.channelId)
          .get();
      final reportedDocFuture = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('reportedCommunityPosts')
          .doc(post.id)
          .get();

      final results = await Future.wait([
        hiddenDocFuture,
        mutedChannelFuture,
        reportedDocFuture,
      ]);
      if (results[0].exists || results[1].exists || results[2].exists) {
        isHidden.value = true;
      }
    } catch (_) {}
  }

  Future<void> _checkSavedStatus() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('savedCommunityPosts')
          .doc(post.id)
          .get();
      isSaved.value = doc.exists;
    } catch (_) {}
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
    } catch (e) {
      debugPrint('Error updating like status: $e');
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
    } catch (e) {
      debugPrint('Error updating dislike status: $e');
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
        await docRef.delete();
        showSuccess('Post removed from Saved Posts');
      } else {
        isSaved.value = true;
        final data = post.toMap();
        data['savedAt'] = FieldValue.serverTimestamp();
        await docRef.set(data);
        showSuccess('Post saved to Saved Posts');
      }
    } catch (e) {
      isSaved.value = !isSaved.value;
      showError('Failed to save post: $e');
    }
  }

  Future<void> hidePost() async {
    isHidden.value = true;
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
      } catch (_) {}
    }
    showSuccess('Post hidden from your feed');
  }

  Future<void> turnOffChannelPosts() async {
    isHidden.value = true;
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
      } catch (_) {}
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
      if (Get.isRegistered<ChannelController>()) {
        await Get.find<ChannelController>().unsubscribeFromChannel(
          post.channelId,
        );
      } else {
        final channelCtrl = Get.find<ChannelController>();
        await channelCtrl.unsubscribeFromChannel(post.channelId);
      }
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.subscriptions)
          .doc('${post.channelId}_$uid')
          .delete();
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.subscriptions)
          .doc(post.channelId)
          .delete();
    } catch (_) {}

    showSuccess('Unsubscribed from ${post.channelName}');
  }

  Future<void> submitReport(String reason, String details) async {
    final uid = currentUid;
    if (uid == null) return;

    isHidden.value = true;

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
    } catch (_) {}

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
      showError('Failed to update settings: $e');
    }
  }

  Future<void> submitComment(String text) async {
    final uid = currentUid;
    if (uid == null) {
      showWarning('Please sign in to comment.');
      return;
    }

    if (text.trim().isEmpty) return;

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
      showError('Failed to add comment: $e');
    }
  }
}
