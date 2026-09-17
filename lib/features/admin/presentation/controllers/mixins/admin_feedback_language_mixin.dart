import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Mixin providing user feedback resolution and channel language requests.
mixin AdminFeedbackLanguageMixin on GetxController {
  /// Contract requirements satisfied by base [AdminController]
  bool get isPrimaryOwner;
  RxString get currentAdminEmail;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Feedbacks State
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> feedbacks = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedFeedback = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingFeedbacks = true.obs;
  final RxString feedbackFilterType = 'All'.obs;
  final RxString feedbackFilterStatus = 'All'.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Channel Language Requests State (Exclusive to Primary Owner)
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> languageRequests =
      <Map<String, dynamic>>[].obs;
  final RxInt pendingLanguageRequests = 0.obs;
  final RxBool isLoadingLanguageRequests = false.obs;
  final RxString languageRequestFilterStatus = 'all'.obs;
  final RxString languageRequestSearchQuery = ''.obs;
  final Rxn<Map<String, dynamic>> selectedLanguageRequest =
      Rxn<Map<String, dynamic>>();
  StreamSubscription<QuerySnapshot>? _languageRequestsSub;

  /// Starts listening to real-time channel language requests if primary owner
  void startLanguageRequestsSubscription(
      void Function(StreamSubscription) trackSubscription) {
    if (_languageRequestsSub == null && isPrimaryOwner) {
      _languageRequestsSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.channelLanguageRequests)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .listen(
        (snapshot) {
          final list = snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
          languageRequests.assignAll(list);
          pendingLanguageRequests.value =
              list.where((req) => req['status'] == 'pending').length;
        },
        onError: (e) {
          debugPrint('AdminController Language Requests Stream Error: $e');
        },
      );
      if (_languageRequestsSub != null) {
        trackSubscription(_languageRequestsSub!);
      }
    }
  }

  /// Cancels the channel language request stream subscription
  void stopLanguageRequestsSubscription() {
    if (_languageRequestsSub != null) {
      unawaited(_languageRequestsSub!.cancel());
      _languageRequestsSub = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Feedbacks Logic
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> loadFeedbacks() async {
    isLoadingFeedbacks.value = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.feedback)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      feedbacks.value =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      isLoadingFeedbacks.value = false;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AdminFeedbackLanguageMixin.loadFeedbacks',
      );
      isLoadingFeedbacks.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredFeedbacks {
    return feedbacks.where((fb) {
      if (feedbackFilterType.value != 'All' &&
          fb['feedbackType'] != feedbackFilterType.value) {
        return false;
      }
      if (feedbackFilterStatus.value != 'All' &&
          fb['status'] != feedbackFilterStatus.value) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> updateFeedbackStatus(String id, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.feedback)
          .doc(id)
          .update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await loadFeedbacks();
      if (selectedFeedback.value != null &&
          selectedFeedback.value!['id'] == id) {
        selectedFeedback.value = feedbacks.firstWhere(
          (f) => f['id'] == id,
          orElse: () => selectedFeedback.value!,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AdminFeedbackLanguageMixin.updateFeedbackStatus',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Channel Language Requests Logic
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> loadLanguageRequests() async {
    if (!isPrimaryOwner) return;
    isLoadingLanguageRequests.value = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channelLanguageRequests)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      languageRequests.value =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      pendingLanguageRequests.value = languageRequests
          .where((req) => req['status'] == 'pending')
          .length;
      isLoadingLanguageRequests.value = false;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AdminFeedbackLanguageMixin.loadLanguageRequests',
      );
      isLoadingLanguageRequests.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredLanguageRequests {
    return languageRequests.where((req) {
      final status = (req['status'] ?? 'pending').toString().toLowerCase();
      if (languageRequestFilterStatus.value != 'all' &&
          status != languageRequestFilterStatus.value.toLowerCase()) {
        return false;
      }

      final query = languageRequestSearchQuery.value.trim().toLowerCase();
      if (query.isNotEmpty) {
        final email = (req['userEmail'] ?? '').toString().toLowerCase();
        final name = (req['userName'] ?? '').toString().toLowerCase();
        final langName =
            (req['languageName'] ?? '').toString().toLowerCase();
        final langNative =
            (req['languageNative'] ?? '').toString().toLowerCase();
        final langCode =
            (req['languageCode'] ?? '').toString().toLowerCase();
        final draftName =
            (req['channelNameDraft'] ?? '').toString().toLowerCase();

        final matches = email.contains(query) ||
            name.contains(query) ||
            langName.contains(query) ||
            langNative.contains(query) ||
            langCode.contains(query) ||
            draftName.contains(query);

        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  Future<void> updateLanguageRequestStatus(
      String id, String newStatus) async {
    if (!isPrimaryOwner) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.channelLanguageRequests)
          .doc(id)
          .update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentAdminEmail.value.isNotEmpty
            ? currentAdminEmail.value
            : (FirebaseAuth.instance.currentUser?.email ?? 'owner'),
      });

      // Update in local reactive list
      final index = languageRequests.indexWhere((r) => r['id'] == id);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(languageRequests[index]);
        updated['status'] = newStatus;
        updated['reviewedAt'] = DateTime.now();
        updated['reviewedBy'] = currentAdminEmail.value;
        languageRequests[index] = updated;
        pendingLanguageRequests.value = languageRequests
            .where((req) => req['status'] == 'pending')
            .length;
      }

      if (selectedLanguageRequest.value != null &&
          selectedLanguageRequest.value!['id'] == id) {
        selectedLanguageRequest.value = languageRequests.firstWhere(
          (f) => f['id'] == id,
          orElse: () => selectedLanguageRequest.value!,
        );
      }

      AppSnackbar.success(
        'Language request marked as $newStatus.',
        title: 'Status Updated',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update language request. Please try again.',
      );
    }
  }

  Future<void> deleteLanguageRequest(String id) async {
    if (!isPrimaryOwner) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.channelLanguageRequests)
          .doc(id)
          .delete();

      languageRequests.removeWhere((r) => r['id'] == id);
      pendingLanguageRequests.value = languageRequests
          .where((req) => req['status'] == 'pending')
          .length;

      if (selectedLanguageRequest.value != null &&
          selectedLanguageRequest.value!['id'] == id) {
        selectedLanguageRequest.value = null;
      }

      AppSnackbar.info(
        'Language request has been removed.',
        title: 'Request Deleted',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to delete language request. Please try again.',
      );
    }
  }
}
