import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';

class SavedCommunityPostsController extends BaseController {
  final RxList<CommunityPostModel> posts = <CommunityPostModel>[].obs;
  final RxBool rxIsLoading = true.obs;
  final RxString rxErrorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSavedPosts();
  }

  /// Backward-compatible alias for one-shot fetch of saved posts
  Future<void> listenToSavedPosts() => fetchSavedPosts();

  Future<void> fetchSavedPosts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      rxErrorMessage.value = 'User not authenticated';
      rxIsLoading.value = false;
      return;
    }

    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .collection('savedCommunityPosts')
          .orderBy('savedAt', descending: true)
          .limit(50)
          .get();

      final list = <CommunityPostModel>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        list.add(CommunityPostModel.fromMap(data));
      }
      posts.value = list;
      rxIsLoading.value = false;
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace: stackTrace, context: 'SavedCommunityPostsController');
      rxErrorMessage.value = AppException.from(error, stackTrace).displayMessage;
      rxIsLoading.value = false;
    }
  }

  Future<void> unsavePost(String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    posts.removeWhere((p) => p.id == postId);

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .collection('savedCommunityPosts')
          .doc(postId)
          .delete();

      AppSnackbar.success(
        'Post removed from saved posts.',
      );
    } on Exception catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to remove saved post. Please try again.',
      );
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
    HapticFeedback.lightImpact();
  }

  void refreshPosts() {
    fetchSavedPosts();
    HapticFeedback.mediumImpact();
  }

  List<CommunityPostModel> get filteredPosts {
    if (searchQuery.isEmpty) return posts;
    final query = searchQuery.value.toLowerCase();
    return posts.where((post) {
      return post.title.toLowerCase().contains(query) ||
          post.description.toLowerCase().contains(query) ||
          post.channelName.toLowerCase().contains(query);
    }).toList();
  }
}
