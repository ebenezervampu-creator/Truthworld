import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';

/// Controller for Studio Settings
/// Manages user settings, channel info and monetization preferences
class StudioSettingsController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxMap<String, dynamic> userData = <String, dynamic>{}.obs;
  final RxBool isLoadingData = true.obs;
  final RxBool isDeletingChannel = false.obs;

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

  /// Deletes (archives) the active channel for the current user.
  Future<bool> deleteChannel() async {
    try {
      isDeletingChannel.value = true;
      final user = _auth.currentUser;
      if (user == null) {
        showWarning('You must be signed in to delete a channel.');
        return false;
      }

      String? targetChannelId;
      if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
        targetChannelId = AuthService.to.userChannel!.id;
      }

      if (targetChannelId == null || targetChannelId.isEmpty) {
        // Fallback query to find active channel owned by current user
        final query = await _firestore
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: user.uid)
            .get();

        final activeDocs = query.docs.where((doc) {
          final status = doc.data()['status'];
          return status != ChannelStatus.deleted.name;
        }).toList();

        if (activeDocs.isNotEmpty) {
          targetChannelId = activeDocs.first.id;
        }
      }

      if (targetChannelId == null || targetChannelId.isEmpty) {
        showWarning('No active channel found to delete.');
        return false;
      }

      // Soft-delete the channel
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(targetChannelId)
          .update({
        'status': ChannelStatus.deleted.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user doc in Firestore to clear channel reference
      try {
        await _userRef.update({
          'channelId': FieldValue.delete(),
          'hasChannel': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Note: Error updating user document during channel deletion: $e');
      }

      // Update AuthService state if available
      if (Get.isRegistered<AuthService>()) {
        AuthService.to.hasChannel.value = false;
      }

      showSuccess('Channel deleted successfully.');
      return true;
    } catch (e) {
      debugPrint('Error deleting channel: $e');
      showError('Failed to delete channel: $e');
      return false;
    } finally {
      isDeletingChannel.value = false;
    }
  }
}

