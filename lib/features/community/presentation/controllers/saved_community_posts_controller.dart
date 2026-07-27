import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class SavedCommunityPostsController extends GetxController {
  final RxList<CommunityPostModel> posts = <CommunityPostModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    listenToSavedPosts();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void listenToSavedPosts() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      errorMessage.value = 'User not authenticated';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('savedCommunityPosts')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final list = <CommunityPostModel>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          list.add(CommunityPostModel.fromMap(data));
        }
        posts.value = list;
        isLoading.value = false;
      },
      onError: (Object error) {
        errorMessage.value = error.toString();
        isLoading.value = false;
        debugPrint('Error listening to saved community posts: $error');
      },
    );
  }

  Future<void> unsavePost(String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('savedCommunityPosts')
          .doc(postId)
          .delete();

      Get.snackbar(
        'Removed',
        'Post removed from Saved Posts',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF6366F1),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.bookmark_border, color: AppColors.textPrimary),
      );
    } on Exception catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove saved post: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
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
    listenToSavedPosts();
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
