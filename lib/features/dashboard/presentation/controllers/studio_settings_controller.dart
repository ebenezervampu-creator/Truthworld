import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Controller for Studio Settings
/// Manages user settings, channel info and monetization preferences
class StudioSettingsController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxMap<String, dynamic> userData = <String, dynamic>{}.obs;
  final RxBool isLoadingData = true.obs;
  final RxBool isDeletingChannel = false.obs;
  final RxBool isLoggingOut = false.obs;

  DocumentReference? _userRef;

  /// Whether _userRef has been initialized (user was authenticated during loadUserData).
  bool get _hasUserRef => _userRef != null;

  void clearSettings() {
    userData.clear();
    _userRef = null;
    isLoadingData.value = false;
  }

  @override
  void onClose() {
    clearSettings();
    super.onClose();
  }

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
        clearSettings();
        return;
      }
      userData.clear();

      _userRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid);
      final doc = await _userRef!.get();

      if (doc.exists) {
        userData.assignAll(Map<String, dynamic>.from(doc.data()! as Map));
      }

      // Check if channel has noAdsForMembers set
      String? targetChannelId;
      if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
        targetChannelId = AuthService.to.userChannel!.id;
      }
      if (targetChannelId == null || targetChannelId.isEmpty) {
        final query = await _firestore
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: user.uid)
            .get();
        if (query.docs.isNotEmpty) {
          targetChannelId = query.docs.first.id;
        }
      }

      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        final channelDoc = await _firestore
            .collection(FirestoreCollections.channels)
            .doc(targetChannelId)
            .get();
        if (channelDoc.exists && channelDoc.data() != null) {
          final cData = channelDoc.data()!;
          final settings = cData['monetizationSettings'];
          final noAds = (cData['noAdsForMembers'] as bool?) ??
              (settings is Map && settings['noAdsForMembers'] == true);
          userData['noAdsForMembers'] = noAds;
        }
      }

      clearError();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'StudioSettingsController.loadUserData',
      );
      setError('Unable to load user settings. Please try again.');
    } finally {
      isLoadingData.value = false;
    }
  }

  /// Toggle "No ads for members" with 30% platform cut on memberships.
  Future<void> toggleNoAdsForMembers(bool enabled) async {
    if (!_hasUserRef) {
      showWarning('Please sign in to change this setting.');
      return;
    }
    try {
      userData['noAdsForMembers'] = enabled;
      userData.refresh();

      await _userRef!.update({'noAdsForMembers': enabled});

      String? targetChannelId;
      if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
        targetChannelId = AuthService.to.userChannel!.id;
      }
      final user = _auth.currentUser;
      if ((targetChannelId == null || targetChannelId.isEmpty) && user != null) {
        final query = await _firestore
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: user.uid)
            .get();
        if (query.docs.isNotEmpty) {
          targetChannelId = query.docs.first.id;
        }
      }

      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        await _firestore
            .collection(FirestoreCollections.channels)
            .doc(targetChannelId)
            .set({
          'noAdsForMembers': enabled,
          'monetizationSettings': {
            'noAdsForMembers': enabled,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (enabled) {
        showSuccess(
          'Channel Premium enabled! Members get zero ads and 4K Ultra HD streaming on your channel (30% platform cut).',
        );
      } else {
        showSuccess(
          'Channel Premium disabled. Standard ad and resolution policies restored (0% commission).',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'StudioSettingsController.toggleNoAdsForMembers',
      );
      showWarning('Unable to update member ad-free setting. Please try again.');
      loadUserData();
    }
  }

  Future<void> updateField(String field, dynamic value) async {
    var effectiveValue = value;
    if (field == 'channelHandle' && value is String) {
      effectiveValue = value.trim().replaceFirst(RegExp('^@+'), '');
    }

    if (effectiveValue is String && (field == 'displayName' || field == 'channelHandle')) {
      final validation = ContentValidator.validate(
        effectiveValue,
        fieldName: field == 'channelHandle' ? 'Channel Handle' : 'Channel Name',
      );
      if (!validation.isValid) {
        showWarning(validation.message);
        loadUserData();
        return;
      }
    }

    if (!_hasUserRef) {
      showWarning('Please sign in to save changes.');
      return;
    }

    try {
      // Optimistic update
      userData[field] = effectiveValue;
      userData.refresh();

      await _userRef!.update({field: effectiveValue});

      // Keep channel doc in sync if applicable
      if (field == 'displayName' || field == 'channelHandle') {
        String? targetChannelId;
        if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
          targetChannelId = AuthService.to.userChannel!.id;
        }
        final user = _auth.currentUser;
        if ((targetChannelId == null || targetChannelId.isEmpty) && user != null) {
          final query = await _firestore
              .collection(FirestoreCollections.channels)
              .where('ownerId', isEqualTo: user.uid)
              .get();
          if (query.docs.isNotEmpty) {
            targetChannelId = query.docs.first.id;
          }
        }
        if (targetChannelId != null && targetChannelId.isNotEmpty) {
          final updateMap = <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (field == 'displayName') {
            updateMap['name'] = effectiveValue;
          } else if (field == 'channelHandle') {
            updateMap['handle'] = effectiveValue;
            updateMap['channelHandle'] = effectiveValue;
          }
          await _firestore
              .collection(FirestoreCollections.channels)
              .doc(targetChannelId)
              .set(updateMap, SetOptions(merge: true));
        }
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'StudioSettingsController');
      showWarning('Unable to save changes. Please try again.');
      loadUserData(); // Refresh from server
    }
  }

  Future<void> updateNestedField(
    String parent,
    String child,
    dynamic value,
  ) async {
    if (!_hasUserRef) {
      showWarning('Please sign in to save changes.');
      return;
    }

    try {
      final updated = Map<String, dynamic>.from(userData[parent] ?? {});
      updated[child] = value;

      // Optimistic update
      userData[parent] = updated;
      userData.refresh();

      await _userRef!.update({parent: updated});
    } catch (e) {
      ErrorHandler.log(e, tag: 'StudioSettingsController');
      showWarning('Unable to save changes. Please try again.');
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

      // Soft-delete the channel with a 30-day grace period
      final now = DateTime.now().toUtc();
      final gracePeriodExpiry = now.add(const Duration(days: 30));

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(targetChannelId)
          .update({
        'status': ChannelStatus.deleted.name,
        'deletionScheduledAt': FieldValue.serverTimestamp(),
        'deletionGracePeriodExpiresAt': Timestamp.fromDate(gracePeriodExpiry),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user doc in Firestore to retain channelId for grace period recovery
      if (_hasUserRef) {
        try {
          await _userRef!.set({
            'channelId': targetChannelId,
            'deletedChannelId': targetChannelId,
            'hasChannel': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'StudioSettingsController.deleteChannel.updateUserDoc',
          );
        }
      }

      // Update AuthService state if available
      if (Get.isRegistered<AuthService>()) {
        AuthService.to.hasChannel.value = false;
      }

      showSuccess(
        'Channel scheduled for deletion. You have a 30-day grace period to cancel and restore it.',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e, tag: 'StudioSettingsController');
      showError('Unable to delete channel. Please try again.');
      return false;
    } finally {
      isDeletingChannel.value = false;
    }
  }

  /// Signs out the active user and redirects to the landing page.
  Future<void> handleSignOut() async {
    try {
      isLoggingOut.value = true;
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().setSelectedIndex(1);
      }
      if (Get.isRegistered<DashboardViewController>()) {
        final viewCtrl = Get.find<DashboardViewController>();
        // Stop in-flight animations before disposing route tree to prevent
        // "AnimationController used after dispose" errors.
        viewCtrl.stopAllAnimations();
        viewCtrl.clearChannelSession();
      }
      if (Get.isRegistered<AuthService>()) {
        await AuthService.to.signOut();
      } else {
        await _auth.signOut();
      }
      clearSettings();
      AppSnackbar.success('You have been successfully signed out.');
      final isStudioContext = AppFlavor.isStudio ||
          Get.currentRoute.toLowerCase().startsWith('/studio') ||
          (kIsWeb &&
              (Uri.base.host.toLowerCase().startsWith('studio') ||
                  Uri.base.path.toLowerCase().startsWith('/studio')));
      if (isStudioContext) {
        Get.offAllNamed(AppRoutes.studio);
      } else {
        Get.offAllNamed('/');
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'StudioSettingsController.handleSignOut',
      );
      AppSnackbar.error('Unable to sign out. Please try again.');
    } finally {
      isLoggingOut.value = false;
    }
  }
}

