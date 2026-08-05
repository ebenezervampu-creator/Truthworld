import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class SavedCommentsController extends BaseController {
  final RxList<SavedCommentModel> comments = <SavedCommentModel>[].obs;
  final RxBool rxIsLoading = true.obs;
  final RxString rxErrorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    listenToSavedComments();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void listenToSavedComments() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      rxErrorMessage.value = 'User not authenticated';
      rxIsLoading.value = false;
      return;
    }

    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(currentUser.uid)
        .collection('savedComments')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final list = <SavedCommentModel>[];
            for (final doc in snapshot.docs) {
              list.add(SavedCommentModel.fromMap(doc.data(), doc.id));
            }
            comments.value = list;
            rxIsLoading.value = false;
          },
          onError: (Object error) {
            rxErrorMessage.value = error.toString();
            rxIsLoading.value = false;
            debugPrint('Error listening to saved comments: $error');
          },
        );
  }

  Future<void> unsaveComment(String commentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .collection('savedComments')
          .doc(commentId)
          .delete();

      Get.snackbar(
        'Removed',
        'Comment removed from Saved Comments',
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
        'Failed to remove saved comment: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  final RxString selectedCategory =
      'all'.obs; // 'all', 'video', 'topic', 'community_post'

  int get totalCount => comments.length;
  int get videoCount => comments.where((c) => c.sourceType == 'video').length;
  int get topicCount => comments.where((c) => c.sourceType == 'topic').length;
  int get communityCount =>
      comments.where((c) => c.sourceType == 'community_post').length;

  void setSelectedCategory(String category) {
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
      HapticFeedback.lightImpact();
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

  void refreshComments() {
    listenToSavedComments();
    HapticFeedback.mediumImpact();
  }

  List<SavedCommentModel> get filteredComments {
    var list = comments.toList();

    // Category filter
    if (selectedCategory.value != 'all') {
      list = list
          .where((item) => item.sourceType == selectedCategory.value)
          .toList();
    }

    // Search query filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      list = list.where((item) {
        return item.text.toLowerCase().contains(query) ||
            item.userName.toLowerCase().contains(query) ||
            item.sourceTitle.toLowerCase().contains(query);
      }).toList();
    }

    return list;
  }
}
