import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

class TopicInteractionController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxInt likeCount = 0.obs;
  final RxBool isLiked = false.obs;
  final RxInt commentCount = 0.obs;

  final RxInt initialDbLikeCount = 0.obs;
  final RxBool dbIsLiked = false.obs;
  final RxBool hasCheckedInteraction = false.obs;

  final RxList<Map<String, dynamic>> comments = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingComments = false.obs;

  // Track reply list for each comment ID
  final RxMap<String, List<Map<String, dynamic>>> repliesMap =
      <String, List<Map<String, dynamic>>>{}.obs;

  // Track user comment and reply interactions (isLiked, isDisliked)
  final RxMap<String, Map<String, bool>> userCommentInteractions =
      <String, Map<String, bool>>{}.obs;
  final RxMap<String, Map<String, bool>> userReplyInteractions =
      <String, Map<String, bool>>{}.obs;

  String get currentUserId => AuthService.to.uid;
  String get currentUserName => AuthService.to.user?.displayName ?? 'User';
  String get currentUserProfilePicUrl => AuthService.to.user?.photoURL ?? '';

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
          .collection('users')
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
          .collection('users')
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
          .collection('users')
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
    } catch (e) {
      debugPrint('Error fetching user topic comment/reply interactions: $e');
    }
  }

  Future<void> toggleLike(String topicId) async {
    if (currentUserId.isEmpty) {
      AppSnackbar.show(
        'Authentication Required',
        'Please sign in to like.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final wasLiked = isLiked.value;

    // Optimistic UI updates
    isLiked.value = !wasLiked;
    _updateLikeCount();

    try {
      final batch = _firestore.batch();
      final topicRef = _firestore.collection('topics').doc(topicId);
      final topicLikeRef = topicRef.collection('likes').doc(currentUserId);
      final userLikedRef = _firestore
          .collection('users')
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

        // ALSO follow/save the topic automatically
        final userSavedRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('savedTopics')
            .doc(topicId);

        batch.set(userSavedRef, {
          'topicId': topicId,
          'savedAt': FieldValue.serverTimestamp(),
        });

        // Consolidate updates to topic document into a single operation
        batch.update(topicRef, {
          'likeCount': FieldValue.increment(1),
          'followerCount': FieldValue.increment(1),
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
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(20) // CRITICAL FIX: Prevent massive fetch
          .get();

      comments.value = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final commentRef = _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc();

      // Resolve channel details
      String? channelId;
      String? channelName;
      String? channelProfilePicUrl;
      String? channelHandle;

      if (AuthService.to.hasChannel.value &&
          AuthService.to.userChannel != null) {
        final channel = AuthService.to.userChannel!;
        channelId = channel.id;
        channelName = channel.name;
        channelProfilePicUrl = channel.avatarUrl;
        channelHandle = channel.handle;
      }

      final newComment = <String, dynamic>{
        'id': commentRef.id,
        'topicId': topicId,
        'videoId': topicId, // compatibility alias
        'userId': currentUserId,
        'channelId': channelId ?? currentUserId,
        'channelName': channelName,
        'channelProfilePicUrl': channelProfilePicUrl,
        'channelHandle': channelHandle,
        'text': text.trim(),
        'likeCount': 0,
        'dislikeCount': 0,
        'reportCount': 0,
        'createdAt': Timestamp.now(),
        'isEdited': false,
        'likedBy': <String, bool>{},
        'dislikedBy': <String, bool>{},
        'isHeartedByCreator': false,
        'creatorHeartName': null,
      };

      if (channelId == null) {
        newComment['userName'] = currentUserName;
        newComment['userProfilePicUrl'] = currentUserProfilePicUrl;
      }

      await commentRef.set(newComment);

      // Update commentCount in Firestore topics collection
      await _firestore.collection('topics').doc(topicId).update({
        'commentCount': FieldValue.increment(1),
      });

      // Update local UI count and list
      commentCount.value++;
      comments.insert(0, newComment);
      comments.refresh();
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to add comment: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ==========================
  // REPLIES
  // ==========================
  Future<void> fetchReplies(String topicId, String commentId) async {
    try {
      final snap = await _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .get();

      repliesMap[commentId] = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final replyRef = _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc();

      // Resolve channel details
      String? channelId;
      String? channelName;
      String? channelProfilePicUrl;
      String? channelHandle;

      if (AuthService.to.hasChannel.value &&
          AuthService.to.userChannel != null) {
        final channel = AuthService.to.userChannel!;
        channelId = channel.id;
        channelName = channel.name;
        channelProfilePicUrl = channel.avatarUrl;
        channelHandle = channel.handle;
      }

      final newReply = <String, dynamic>{
        'id': replyRef.id,
        'commentId': commentId,
        'topicId': topicId,
        'videoId': topicId, // compatibility alias
        'userId': currentUserId,
        'channelId': channelId ?? currentUserId,
        'channelName': channelName,
        'channelProfilePicUrl': channelProfilePicUrl,
        'channelHandle': channelHandle,
        'text': text.trim(),
        'likeCount': 0,
        'dislikeCount': 0,
        'reportCount': 0,
        'createdAt': Timestamp.now(),
        'isEdited': false,
        'likedBy': <String, bool>{},
        'dislikedBy': <String, bool>{},
      };

      if (channelId == null) {
        newReply['userName'] = currentUserName;
        newReply['userProfilePicUrl'] = currentUserProfilePicUrl;
      }

      await replyRef.set(newReply);

      // Update commentCount in Firestore topics collection
      await _firestore.collection('topics').doc(topicId).update({
        'commentCount': FieldValue.increment(1),
      });

      // Update local UI count and list
      commentCount.value++;
      if (repliesMap[commentId] == null) {
        repliesMap[commentId] = [];
      }
      repliesMap[commentId]!.add(newReply);
      repliesMap.refresh();
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to add reply: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final currentInteraction =
        userCommentInteractions[commentId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newLiked = !wasLiked;
    final newDisliked = newLiked ? false : wasDisliked;

    // Optimistic UI update
    userCommentInteractions[commentId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userCommentInteractions.refresh();

    final index = comments.indexWhere((c) => c['id'] == commentId);
    int oldLikeCount = 0;
    int oldDislikeCount = 0;
    Map<String, dynamic>? oldComment;
    if (index != -1) {
      oldComment = comments[index];
      oldLikeCount = oldComment['likeCount'] ?? 0;
      oldDislikeCount = oldComment['dislikeCount'] ?? 0;

      int newLikeCount = oldLikeCount;
      int newDislikeCount = oldDislikeCount;
      if (newLiked) {
        newLikeCount++;
        if (wasDisliked) {
          newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
        }
      } else {
        newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      }

      comments[index] = {
        ...oldComment,
        'likeCount': newLikeCount,
        'dislikeCount': newDislikeCount,
      };
      comments.refresh();
    }

    try {
      final commentRef = _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc(commentId);

      final userInteractionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('liked_topic_comments')
          .doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final commentSnap = await transaction.get(commentRef);
        if (!commentSnap.exists) return;

        final data = commentSnap.data() as Map<String, dynamic>;
        final likedBy = Map<String, bool>.from(data['likedBy'] ?? {});
        final dislikedBy = Map<String, bool>.from(data['dislikedBy'] ?? {});

        if (newLiked) {
          likedBy[userId] = true;
          dislikedBy.remove(userId);
          transaction.set(userInteractionRef, {
            'topicId': topicId,
            'isLiked': true,
            'isDisliked': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          likedBy.remove(userId);
          transaction.delete(userInteractionRef);
        }

        transaction.update(commentRef, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likeCount': likedBy.length,
          'dislikeCount': dislikedBy.length,
        });
      });
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final currentInteraction =
        userCommentInteractions[commentId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newDisliked = !wasDisliked;
    final newLiked = newDisliked ? false : wasLiked;

    // Optimistic UI update
    userCommentInteractions[commentId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userCommentInteractions.refresh();

    final index = comments.indexWhere((c) => c['id'] == commentId);
    int oldLikeCount = 0;
    int oldDislikeCount = 0;
    Map<String, dynamic>? oldComment;
    if (index != -1) {
      oldComment = comments[index];
      oldLikeCount = oldComment['likeCount'] ?? 0;
      oldDislikeCount = oldComment['dislikeCount'] ?? 0;

      int newLikeCount = oldLikeCount;
      int newDislikeCount = oldDislikeCount;
      if (newDisliked) {
        newDislikeCount++;
        if (wasLiked) newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      } else {
        newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
      }

      comments[index] = {
        ...oldComment,
        'likeCount': newLikeCount,
        'dislikeCount': newDislikeCount,
      };
      comments.refresh();
    }

    try {
      final commentRef = _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc(commentId);

      final userInteractionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('liked_topic_comments')
          .doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final commentSnap = await transaction.get(commentRef);
        if (!commentSnap.exists) return;

        final data = commentSnap.data() as Map<String, dynamic>;
        final likedBy = Map<String, bool>.from(data['likedBy'] ?? {});
        final dislikedBy = Map<String, bool>.from(data['dislikedBy'] ?? {});

        if (newDisliked) {
          dislikedBy[userId] = true;
          likedBy.remove(userId);
          transaction.set(userInteractionRef, {
            'topicId': topicId,
            'isLiked': false,
            'isDisliked': true,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          dislikedBy.remove(userId);
          transaction.delete(userInteractionRef);
        }

        transaction.update(commentRef, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likeCount': likedBy.length,
          'dislikeCount': dislikedBy.length,
        });
      });
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final currentInteraction =
        userReplyInteractions[replyId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newLiked = !wasLiked;
    final newDisliked = newLiked ? false : wasDisliked;

    userReplyInteractions[replyId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userReplyInteractions.refresh();

    final replies = repliesMap[commentId] ?? [];
    final index = replies.indexWhere((r) => r['id'] == replyId);
    Map<String, dynamic>? oldReply;
    if (index != -1) {
      oldReply = replies[index];
      int newLikeCount = oldReply['likeCount'] ?? 0;
      int newDislikeCount = oldReply['dislikeCount'] ?? 0;
      if (newLiked) {
        newLikeCount++;
        if (wasDisliked) {
          newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
        }
      } else {
        newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      }
      replies[index] = {
        ...oldReply,
        'likeCount': newLikeCount,
        'dislikeCount': newDislikeCount,
      };
      repliesMap.refresh();
    }

    try {
      final replyRef = _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

      final userInteractionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('liked_topic_replies')
          .doc(replyId);

      await _firestore.runTransaction((transaction) async {
        final replySnap = await transaction.get(replyRef);
        if (!replySnap.exists) return;

        final data = replySnap.data() as Map<String, dynamic>;
        final likedBy = Map<String, bool>.from(data['likedBy'] ?? {});
        final dislikedBy = Map<String, bool>.from(data['dislikedBy'] ?? {});

        if (newLiked) {
          likedBy[userId] = true;
          dislikedBy.remove(userId);
          transaction.set(userInteractionRef, {
            'topicId': topicId,
            'commentId': commentId,
            'isLiked': true,
            'isDisliked': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          likedBy.remove(userId);
          transaction.delete(userInteractionRef);
        }

        transaction.update(replyRef, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likeCount': likedBy.length,
          'dislikeCount': dislikedBy.length,
        });
      });
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final currentInteraction =
        userReplyInteractions[replyId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newDisliked = !wasDisliked;
    final newLiked = newDisliked ? false : wasLiked;

    userReplyInteractions[replyId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userReplyInteractions.refresh();

    final replies = repliesMap[commentId] ?? [];
    final index = replies.indexWhere((r) => r['id'] == replyId);
    Map<String, dynamic>? oldReply;
    if (index != -1) {
      oldReply = replies[index];
      int newLikeCount = oldReply['likeCount'] ?? 0;
      int newDislikeCount = oldReply['dislikeCount'] ?? 0;
      if (newDisliked) {
        newDislikeCount++;
        if (wasLiked) newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      } else {
        newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
      }
      replies[index] = {
        ...oldReply,
        'likeCount': newLikeCount,
        'dislikeCount': newDislikeCount,
      };
      repliesMap.refresh();
    }

    try {
      final replyRef = _firestore
          .collection('topics')
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

      final userInteractionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('liked_topic_replies')
          .doc(replyId);

      await _firestore.runTransaction((transaction) async {
        final replySnap = await transaction.get(replyRef);
        if (!replySnap.exists) return;

        final data = replySnap.data() as Map<String, dynamic>;
        final likedBy = Map<String, bool>.from(data['likedBy'] ?? {});
        final dislikedBy = Map<String, bool>.from(data['dislikedBy'] ?? {});

        if (newDisliked) {
          dislikedBy[userId] = true;
          likedBy.remove(userId);
          transaction.set(userInteractionRef, {
            'topicId': topicId,
            'commentId': commentId,
            'isLiked': false,
            'isDisliked': true,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          dislikedBy.remove(userId);
          transaction.delete(userInteractionRef);
        }

        transaction.update(replyRef, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likeCount': likedBy.length,
          'dislikeCount': dislikedBy.length,
        });
      });
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to submit report: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
