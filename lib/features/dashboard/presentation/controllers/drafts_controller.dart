import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/base/ui_event.dart';
import 'package:truthworld/features/dashboard/data/models/draft_model.dart';

/// Controller for managing creator studio video and community drafts.
class DraftsController extends BaseController {
  DraftsController({this.channelId});

  final String? channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage _storage = GetStorage();

  static const String _storageKey = 'user_drafts_v1';

  final RxList<DraftModel> videoDrafts = <DraftModel>[].obs;
  final RxList<DraftModel> communityDrafts = <DraftModel>[].obs;

  late final TextEditingController searchController;

  @override
  void onInit() {
    super.onInit();
    searchController = trackTextController(TextEditingController());
    loadDrafts();
  }

  /// Load drafts from local [GetStorage] cache and sync with Firestore collection `user_drafts`
  Future<void> loadDrafts() async {
    rxState.value = ViewState.loading;
    try {
      // 1. Load local drafts from GetStorage for instant display
      _loadLocalDrafts();

      // 2. Sync real-time drafts from Firestore user_drafts collection if logged in
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        final query = _firestore
            .collection('user_drafts')
            .where('userId', isEqualTo: userId);

        final subscription = query.snapshots().listen(
          (snapshot) {
            final fetchedDrafts = snapshot.docs
                .map((doc) => DraftModel.fromMap(doc.data(), doc.id))
                .toList();

            _updateDraftLists(fetchedDrafts);
            _saveToLocalStorage(fetchedDrafts);

            rxState.value = (videoDrafts.isEmpty && communityDrafts.isEmpty)
                ? ViewState.empty
                : ViewState.success;
          },
          onError: (error) {
            if (videoDrafts.isEmpty && communityDrafts.isEmpty) {
              rxState.value = ViewState.empty;
            } else {
              rxState.value = ViewState.success;
            }
          },
        );

        trackSubscription(subscription);
      } else {
        rxState.value = (videoDrafts.isEmpty && communityDrafts.isEmpty)
            ? ViewState.empty
            : ViewState.success;
      }
    } catch (e) {
      if (videoDrafts.isEmpty && communityDrafts.isEmpty) {
        rxState.value = ViewState.error;
      } else {
        rxState.value = ViewState.success;
      }
    }
  }

  void _loadLocalDrafts() {
    try {
      final rawData = _storage.read<List>(_storageKey);
      if (rawData != null && rawData.isNotEmpty) {
        final localDrafts = rawData
            .map((e) => DraftModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _updateDraftLists(localDrafts);
      }
    } catch (_) {}
  }

  void _updateDraftLists(List<DraftModel> drafts) {
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    videoDrafts.assignAll(drafts.where((d) => d.type == 'video'));
    communityDrafts.assignAll(drafts.where((d) => d.type == 'communityPost'));
  }

  void _saveToLocalStorage(List<DraftModel> drafts) {
    try {
      _storage.write(_storageKey, drafts.map((d) => d.toMap()).toList());
    } catch (_) {}
  }

  /// Save or update a draft item persistently
  Future<void> saveDraft(DraftModel draft) async {
    final updatedDraft = draft.copyWith(updatedAt: DateTime.now());

    // Update in-memory reactive lists
    if (updatedDraft.type == 'video') {
      final index = videoDrafts.indexWhere((d) => d.id == updatedDraft.id);
      if (index >= 0) {
        videoDrafts[index] = updatedDraft;
      } else {
        videoDrafts.insert(0, updatedDraft);
      }
    } else {
      final index = communityDrafts.indexWhere((d) => d.id == updatedDraft.id);
      if (index >= 0) {
        communityDrafts[index] = updatedDraft;
      } else {
        communityDrafts.insert(0, updatedDraft);
      }
    }

    final allDrafts = [...videoDrafts, ...communityDrafts];
    _saveToLocalStorage(allDrafts);

    if (rxState.value == ViewState.empty) {
      rxState.value = ViewState.success;
    }

    // Save to Firestore if user is authenticated
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      try {
        final draftData = updatedDraft.toMap();
        draftData['userId'] = userId;
        await _firestore
            .collection('user_drafts')
            .doc(updatedDraft.id)
            .set(draftData, SetOptions(merge: true));
      } catch (e) {
        emitUiEvent(
          const UiEventShowSnackbar(
            title: 'Draft Saved Locally',
            message: 'Saved locally, will sync when online.',
          ),
        );
      }
    }
  }

  /// Delete draft by ID from local storage and Firestore
  Future<void> deleteDraft(String id) async {
    videoDrafts.removeWhere((d) => d.id == id);
    communityDrafts.removeWhere((d) => d.id == id);

    final allDrafts = [...videoDrafts, ...communityDrafts];
    _saveToLocalStorage(allDrafts);

    if (videoDrafts.isEmpty && communityDrafts.isEmpty) {
      rxState.value = ViewState.empty;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      try {
        await _firestore.collection('user_drafts').doc(id).delete();
      } catch (_) {}
    }

    emitUiEvent(const UiEventShowToast(message: 'Draft deleted'));
  }

  /// Resume editing a draft item
  void resumeDraft(DraftModel draft) {
    if (draft.type == 'video') {
      Get.toNamed('/upload/video', arguments: {
        'draft': draft,
        'draftId': draft.id,
        'videoId': draft.id,
      });
    } else if (draft.type == 'communityPost') {
      Get.toNamed(
        '/upload/community',
        arguments: {'draft': draft, 'draftId': draft.id, 'postId': draft.id},
      );
    } else {
      emitUiEvent(
        UiEventShowSnackbar(
          title: 'Resume Draft',
          message: 'Resuming "${draft.title}"...',
        ),
      );
    }
  }
}
