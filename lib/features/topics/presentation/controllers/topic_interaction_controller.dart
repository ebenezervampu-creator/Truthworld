import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/theme/app_theme.dart';

class TopicInteractionController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxInt likeCount = 0.obs;
  final RxBool isLiked = false.obs;
  final RxInt commentCount = 0.obs;

  final RxInt initialDbLikeCount = 0.obs;
  final RxBool dbIsLiked = false.obs;
  final RxBool hasCheckedInteraction = false.obs;

  final RxList<Comment> comments = <Comment>[].obs;
  final RxBool isLoadingComments = false.obs;

  // Track reply list for each comment ID
  final RxMap<String, List<Reply>> repliesMap = <String, List<Reply>>{}.obs;

  // Track user comment and reply interactions (isLiked, isDisliked)
  final RxMap<String, Map<String, bool>> userCommentInteractions =
      <String, Map<String, bool>>{}.obs;
  final RxMap<String, Map<String, bool>> userReplyInteractions =
      <String, Map<String, bool>>{}.obs;

  String get currentUserId => AuthService.to.uid;
  String get currentUserName => AuthService.to.activeDisplayName;
  String get currentUserProfilePicUrl => AuthService.to.activePhotoUrl;

  Topic? _topic;

  int get displayLikeCount {
    if (!hasCheckedInteraction.value) {
      return initialDbLikeCount.value;
    }
    if (isLiked.value && !dbIsLiked.value) {
      return initialDbLikeCount.value + 1;
    }
    if (!isLiked.value && dbIsLiked.value) {
      return initialDbLikeCount.value - 1;
    }
    return initialDbLikeCount.value;
  }

  void _updateLikeCount() {
    likeCount.value = displayLikeCount;
  }

  void updateInitialLikeCount(int count) {
    if (initialDbLikeCount.value != count) {
      initialDbLikeCount.value = count;
      _updateLikeCount();
    }
  }

  void initializeTopic(Topic topic) {
    _topic = topic;
    // Set initial values
    initialDbLikeCount.value = topic.likeCount;
    commentCount.value = topic.commentCount;
    dbIsLiked.value = false;
    hasCheckedInteraction.value = false;
    isLiked.value = false;

    _updateLikeCount();

    _checkUserInteraction(topic.id);
    _fetchUserCommentInteractions(topic.id);
    fetchComments(topic.id);
  }

  Future<void> _checkUserInteraction(String topicId) async {
    if (currentUserId.isEmpty) return;
    try {
      // Try nested user's likedTopics subcollection first
      final likedTopicsDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('likedTopics')
          .doc(topicId)
          .get();

      if (likedTopicsDoc.exists) {
        isLiked.value = true;
        dbIsLiked.value = true;
      }
      hasCheckedInteraction.value = true;
      _updateLikeCount();
    } catch (e) {
      debugPrint('Error checking user topic interaction: $e');
    }
  }

  Future<void> _fetchUserCommentInteractions(String topicId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return;
    try {
      userCommentInteractions.clear();
      userReplyInteractions.clear();

      // Fetch comment interactions
      final commentsSnap = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_comments')
          .where('topicId', isEqualTo: topicId)
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in commentsSnap.docs) {
        final data = doc.data();
        userCommentInteractions[doc.id] = {
          'isLiked': data['isLiked'] ?? false,
          'isDisliked': data['isDisliked'] ?? false,
        };
      }
      userCommentInteractions.refresh();

      // Fetch reply interactions
      final repliesSnap = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_replies')
          .where('topicId', isEqualTo: topicId)
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in repliesSnap.docs) {
        final data = doc.data();
        userReplyInteractions[doc.id] = {
          'isLiked': data['isLiked'] ?? false,
          'isDisliked': data['isDisliked'] ?? false,
        };
      }
      userReplyInteractions.refresh();

      if (comments.isNotEmpty) {
        comments.value = comments.map((c) {
          final interaction = userCommentInteractions[c.id];
          if (interaction != null) {
            return c.copyWith(
              isLikedByCurrentUser: interaction['isLiked'] ?? false,
              isDislikedByCurrentUser: interaction['isDisliked'] ?? false,
            );
          }
          return c;
        }).toList();
        comments.refresh();
      }
    } catch (e) {
      debugPrint('Error fetching user topic comment/reply interactions: $e');
    }
  }

  Future<void> toggleLike(String topicId) async {
    if (currentUserId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to like.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final wasLiked = isLiked.value;

    // Optimistic UI updates
    isLiked.value = !wasLiked;
    _updateLikeCount();

    try {
      final batch = _firestore.batch();
      final topicRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId);
      final topicLikeRef = topicRef.collection('likes').doc(currentUserId);
      final userLikedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('likedTopics')
          .doc(topicId);

      if (isLiked.value) {
        // Nested subcollections only (YouTube-standard, no legacy writes)
        batch.set(topicLikeRef, {
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userLikedRef, {
          'topicId': topicId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        batch.update(topicRef, {
          'likeCount': FieldValue.increment(1),
        });
      } else {
        // Nested subcollections only
        batch.delete(topicLikeRef);
        batch.delete(userLikedRef);
        batch.update(topicRef, {'likeCount': FieldValue.increment(-1)});
      }

      await batch.commit();

      // Update dbIsLiked to match the newly committed state
      dbIsLiked.value = isLiked.value;
      _updateLikeCount();

      if (Get.isRegistered<FollowingTopicsController>()) {
        final ctrl = Get.find<FollowingTopicsController>();
        if (isLiked.value && _topic != null) {
          if (!ctrl.favoriteTopics.any((t) => t.id == topicId)) {
            ctrl.favoriteTopics.add(_topic!);
          }
          if (!ctrl.followedTopics.any((t) => t.id == topicId)) {
            ctrl.followedTopics.add(_topic!);
          }
        } else if (!isLiked.value) {
          ctrl.favoriteTopics.removeWhere((t) => t.id == topicId);
        }
      }
    } catch (e) {
      // Revert on error
      isLiked.value = wasLiked;
      _updateLikeCount();
      _checkUserInteraction(topicId); // refresh count
      debugPrint('Error toggling like: $e');
    }
  }

  // ==========================
  // COMMENTS
  // ==========================
  Future<void> fetchComments(String topicId) async {
    isLoadingComments.value = true;
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(20) // CRITICAL FIX: Prevent massive fetch
          .get();

      comments.value = snap.docs.map((doc) {
        final comment = Comment.fromDocumentSnapshot(doc);
        final interaction = userCommentInteractions[comment.id];
        if (interaction != null) {
          return comment.copyWith(
            isLikedByCurrentUser: interaction['isLiked'] ?? false,
            isDislikedByCurrentUser: interaction['isDisliked'] ?? false,
          );
        }
        return comment;
      }).toList();

      // CRITICAL FIX: Removed eager N+1 fetchReplies loop.
      // Replies should only be fetched lazily when requested by the UI.
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    } finally {
      isLoadingComments.value = false;
    }
  }

  Future<void> addComment(String topicId, String text) async {
    if (text.trim().isEmpty) return;
    if (currentUserId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to comment.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      final commentRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc();

      // Resolve channel details
      String? channelId;
      String? channelName;
      String? channelProfilePicUrl;

      if (AuthService.to.hasChannel.value &&
          AuthService.to.userChannel != null) {
        final channel = AuthService.to.userChannel!;
        channelId = channel.id;
        channelName = channel.handle.isNotEmpty ? channel.handle : channel.name;
        channelProfilePicUrl = channel.avatarUrl;
      }

      final commentObj = Comment(
        id: commentRef.id,
        videoId: topicId,
        userId: currentUserId,
        userName: currentUserName,
        userProfilePicUrl: currentUserProfilePicUrl,
        channelId: channelId ?? currentUserId,
        channelName: channelName,
        channelProfilePicUrl: channelProfilePicUrl,
        text: text.trim(),
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      await commentRef.set(commentObj.toMap());

      // Update commentCount in Firestore topics collection
      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(1),
          });

      // Update local UI count and list
      commentCount.value++;
      comments.insert(0, commentObj);
      comments.refresh();
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to add comment: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> fetchReplies(String topicId, String commentId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .get();

      repliesMap[commentId] = snap.docs.map((doc) {
        return Reply.fromDocumentSnapshot(doc);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching replies: $e');
    }
  }

  Future<void> addReply(String topicId, String commentId, String text) async {
    if (text.trim().isEmpty) return;
    if (currentUserId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to reply.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      final replyRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc();

      // Resolve channel details
      String? channelId;
      String? channelName;
      String? channelProfilePicUrl;

      if (AuthService.to.hasChannel.value &&
          AuthService.to.userChannel != null) {
        final channel = AuthService.to.userChannel!;
        channelId = channel.id;
        channelName = channel.handle.isNotEmpty ? channel.handle : channel.name;
        channelProfilePicUrl = channel.avatarUrl;
      }

      final replyObj = Reply(
        id: replyRef.id,
        commentId: commentId,
        videoId: topicId,
        userId: currentUserId,
        userName: currentUserName,
        userProfilePicUrl: currentUserProfilePicUrl,
        channelId: channelId ?? currentUserId,
        channelName: channelName,
        channelProfilePicUrl: channelProfilePicUrl,
        text: text.trim(),
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      await replyRef.set(replyObj.toMap());

      // Update commentCount in Firestore topics collection
      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(1),
          });

      // Update local UI count and list
      commentCount.value++;
      if (repliesMap[commentId] == null) {
        repliesMap[commentId] = [];
      }
      repliesMap[commentId]!.add(replyObj);
      repliesMap.refresh();
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to add reply: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  // ==========================
  // COMMENT & REPLY LIKES / DISLIKES
  // ==========================
  Future<void> toggleCommentLike(String topicId, String commentId) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to interact.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final currentInteraction =
        userCommentInteractions[commentId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newLiked = !wasLiked;
    final newDisliked = !newLiked && wasDisliked;

    // Optimistic UI update
    userCommentInteractions[commentId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userCommentInteractions.refresh();

    final index = comments.indexWhere((c) => c.id == commentId);
    Comment? oldComment;
    if (index != -1) {
      oldComment = comments[index];
      var newLikeCount = oldComment.likeCount;
      var newDislikeCount = oldComment.dislikeCount;
      if (newLiked) {
        newLikeCount++;
        if (wasDisliked) {
          newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
        }
      } else {
        newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      }

      comments[index] = oldComment.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      comments.refresh();
    }

    try {
      final commentRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(userId);
      final dislikeRef = commentRef.collection('dislikes').doc(userId);

      final userInteractionRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_comments')
          .doc(commentId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = _firestore.batch();

      if (likeDoc.exists) {
        batch.delete(likeRef);
        batch.delete(userInteractionRef);
        batch.update(commentRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'isLiked': true,
          'isDisliked': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final updates = <String, dynamic>{
          'likeCount': FieldValue.increment(1),
        };
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          updates['dislikeCount'] = FieldValue.increment(-1);
        }
        batch.update(commentRef, updates);
      }

      await batch.commit();
    } catch (e) {
      userCommentInteractions[commentId] = currentInteraction;
      userCommentInteractions.refresh();
      if (index != -1 && oldComment != null) {
        comments[index] = oldComment;
        comments.refresh();
      }
      debugPrint('Error toggling comment like: $e');
    }
  }

  Future<void> toggleCommentDislike(String topicId, String commentId) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to interact.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final currentInteraction =
        userCommentInteractions[commentId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newDisliked = !wasDisliked;
    final newLiked = !newDisliked && wasLiked;

    // Optimistic UI update
    userCommentInteractions[commentId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userCommentInteractions.refresh();

    final index = comments.indexWhere((c) => c.id == commentId);
    Comment? oldComment;
    if (index != -1) {
      oldComment = comments[index];
      var newLikeCount = oldComment.likeCount;
      var newDislikeCount = oldComment.dislikeCount;
      if (newDisliked) {
        newDislikeCount++;
        if (wasLiked) {
          newLikeCount = (newLikeCount - 1).clamp(0, 999999);
        }
      } else {
        newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
      }

      comments[index] = oldComment.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      comments.refresh();
    }

    try {
      final commentRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(userId);
      final dislikeRef = commentRef.collection('dislikes').doc(userId);

      final userInteractionRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_comments')
          .doc(commentId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = _firestore.batch();

      if (dislikeDoc.exists) {
        batch.delete(dislikeRef);
        batch.delete(userInteractionRef);
        batch.update(commentRef, {
          'dislikeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(dislikeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'isLiked': false,
          'isDisliked': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final updates = <String, dynamic>{
          'dislikeCount': FieldValue.increment(1),
        };
        if (likeDoc.exists) {
          batch.delete(likeRef);
          updates['likeCount'] = FieldValue.increment(-1);
        }
        batch.update(commentRef, updates);
      }

      await batch.commit();
    } catch (e) {
      userCommentInteractions[commentId] = currentInteraction;
      userCommentInteractions.refresh();
      if (index != -1 && oldComment != null) {
        comments[index] = oldComment;
        comments.refresh();
      }
      debugPrint('Error toggling comment dislike: $e');
    }
  }

  Future<void> toggleReplyLike(
    String topicId,
    String commentId,
    String replyId,
  ) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to interact.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final currentInteraction =
        userReplyInteractions[replyId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newLiked = !wasLiked;
    final newDisliked = !newLiked && wasDisliked;

    userReplyInteractions[replyId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userReplyInteractions.refresh();

    final replies = repliesMap[commentId] ?? [];
    final index = replies.indexWhere((r) => r.id == replyId);
    Reply? oldReply;
    if (index != -1) {
      oldReply = replies[index];
      var newLikeCount = oldReply.likeCount;
      var newDislikeCount = oldReply.dislikeCount;
      if (newLiked) {
        newLikeCount++;
        if (wasDisliked) {
          newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
        }
      } else {
        newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      }
      replies[index] = oldReply.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      repliesMap.refresh();
    }

    try {
      final replyRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

      final likeRef = replyRef.collection('likes').doc(userId);
      final dislikeRef = replyRef.collection('dislikes').doc(userId);

      final userInteractionRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_replies')
          .doc(replyId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = _firestore.batch();

      if (likeDoc.exists) {
        batch.delete(likeRef);
        batch.delete(userInteractionRef);
        batch.update(replyRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'commentId': commentId,
          'isLiked': true,
          'isDisliked': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final updates = <String, dynamic>{
          'likeCount': FieldValue.increment(1),
        };
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          updates['dislikeCount'] = FieldValue.increment(-1);
        }
        batch.update(replyRef, updates);
      }

      await batch.commit();
    } catch (e) {
      userReplyInteractions[replyId] = currentInteraction;
      userReplyInteractions.refresh();
      if (index != -1 && oldReply != null) {
        replies[index] = oldReply;
        repliesMap.refresh();
      }
      debugPrint('Error toggling reply like: $e');
    }
  }

  Future<void> toggleReplyDislike(
    String topicId,
    String commentId,
    String replyId,
  ) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to interact.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final currentInteraction =
        userReplyInteractions[replyId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newDisliked = !wasDisliked;
    final newLiked = !newDisliked && wasLiked;

    userReplyInteractions[replyId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userReplyInteractions.refresh();

    final replies = repliesMap[commentId] ?? [];
    final index = replies.indexWhere((r) => r.id == replyId);
    Reply? oldReply;
    if (index != -1) {
      oldReply = replies[index];
      var newLikeCount = oldReply.likeCount;
      var newDislikeCount = oldReply.dislikeCount;
      if (newDisliked) {
        newDislikeCount++;
        if (wasLiked) newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      } else {
        newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
      }
      replies[index] = oldReply.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      repliesMap.refresh();
    }

    try {
      final replyRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

      final likeRef = replyRef.collection('likes').doc(userId);
      final dislikeRef = replyRef.collection('dislikes').doc(userId);

      final userInteractionRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_replies')
          .doc(replyId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = _firestore.batch();

      if (dislikeDoc.exists) {
        batch.delete(dislikeRef);
        batch.delete(userInteractionRef);
        batch.update(replyRef, {
          'dislikeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(dislikeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'commentId': commentId,
          'isLiked': false,
          'isDisliked': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final updates = <String, dynamic>{
          'dislikeCount': FieldValue.increment(1),
        };
        if (likeDoc.exists) {
          batch.delete(likeRef);
          updates['likeCount'] = FieldValue.increment(-1);
        }
        batch.update(replyRef, updates);
      }

      await batch.commit();
    } catch (e) {
      userReplyInteractions[replyId] = currentInteraction;
      userReplyInteractions.refresh();
      if (index != -1 && oldReply != null) {
        replies[index] = oldReply;
        repliesMap.refresh();
      }
      debugPrint('Error toggling reply dislike: $e');
    }
  }

  Future<void> deleteComment(String topicId, String commentId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(-1),
          });

      commentCount.value = (commentCount.value - 1).clamp(0, 999999);
      comments.removeWhere((c) => c.id == commentId);
      comments.refresh();
      AppSnackbar.show(
        'Success',
        'Comment deleted successfully.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      AppSnackbar.show(
        'Error',
        'Failed to delete comment: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> deleteReply(
    String topicId,
    String commentId,
    String replyId,
  ) async {
    try {
      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .delete();

      await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(-1),
          });

      commentCount.value = (commentCount.value - 1).clamp(0, 999999);
      if (repliesMap[commentId] != null) {
        repliesMap[commentId]!.removeWhere((r) => r.id == replyId);
      }
      repliesMap.refresh();
      AppSnackbar.show(
        'Success',
        'Reply deleted successfully.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      debugPrint('Error deleting reply: $e');
      AppSnackbar.show(
        'Error',
        'Failed to delete reply: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  // ==========================
  // REPORT
  // ==========================
  Future<void> reportTopic(
    String topicId,
    String reason,
    String details,
  ) async {
    if (currentUserId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to report.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      await _firestore.collection('topic_reports').add({
        'topicId': topicId,
        'userId': currentUserId,
        'userName': currentUserName,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
      AppSnackbar.show(
        'Report Submitted',
        'Thank you for reporting. Our moderators will review it shortly.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to submit report: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }
}
