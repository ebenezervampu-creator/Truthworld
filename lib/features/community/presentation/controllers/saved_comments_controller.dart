import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class SavedCommentsController extends GetxController {
  final RxList<SavedCommentModel> comments = <SavedCommentModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
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
        isLoading.value = false;
      },
      onError: (Object error) {
        errorMessage.value = error.toString();
        isLoading.value = false;
        debugPrint('Error listening to saved comments: $error');
      },
    );
  }

  Future<void> unsaveComment(String commentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
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
    if (searchQuery.isEmpty) return comments;
    final query = searchQuery.value.toLowerCase();
    return comments.where((item) {
      return item.text.toLowerCase().contains(query) ||
          item.userName.toLowerCase().contains(query) ||
          item.sourceTitle.toLowerCase().contains(query);
    }).toList();
  }
}
