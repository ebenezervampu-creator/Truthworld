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
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';

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
          onError: (Object error, StackTrace stackTrace) {
            ErrorHandler.log(error, stackTrace: stackTrace, context: 'SavedCommentsController');
            rxErrorMessage.value = AppException.from(error, stackTrace).displayMessage;
            rxIsLoading.value = false;
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

      AppSnackbar.success(
        'Comment removed from saved comments.',
      );
    } on Exception catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to remove saved comment. Please try again.',
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
