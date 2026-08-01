import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

/// Controller for Studio Settings
/// Manages user settings, channel info and monetization preferences
class StudioSettingsController extends BaseController {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final userData = <String, dynamic>{}.obs;
  final isLoadingData = true.obs;

  late DocumentReference _userRef;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      isLoadingData.value = true;
      final user = _auth.currentUser;

      if (user == null) {
        isLoadingData.value = false;
        return;
      }

      _userRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid);
      final doc = await _userRef.get();

      if (doc.exists) {
        userData.assignAll(Map<String, dynamic>.from(doc.data()! as Map));
      }

      clearError();
    } catch (e) {
      setError('Failed to load user settings');
      debugPrint('Error loading user data: $e');
    } finally {
      isLoadingData.value = false;
    }
  }

  Future<void> updateField(String field, dynamic value) async {
    try {
      // Optimistic update
      userData[field] = value;
      userData.refresh();

      await _userRef.update({field: value});
    } catch (e) {
      // Revert if failed (or just notify)
      // Actually real apps would revert, here we just show error
      showWarning('Failed to save $field: $e');
      loadUserData(); // Refresh from server
    }
  }

  Future<void> updateNestedField(
    String parent,
    String child,
    dynamic value,
  ) async {
    try {
      final updated = Map<String, dynamic>.from(userData[parent] ?? {});
      updated[child] = value;

      // Optimistic update
      userData[parent] = updated;
      userData.refresh();

      await _userRef.update({parent: updated});
    } catch (e) {
      showWarning('Failed to save $child: $e');
      loadUserData(); // Refresh
    }
  }

  String getVisibilityLabel(String value) {
    switch (value) {
      case 'unlisted':
        return 'Unlisted';
      case 'private':
        return 'Private';
      default:
        return 'Public';
    }
  }
}
