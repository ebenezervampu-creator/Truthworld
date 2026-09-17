import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_ctrl;
import 'package:truthworld/features/settings/data/models/accessibility_settings.dart';
import 'package:truthworld/features/settings/data/models/digital_wellbeing_settings.dart';
import 'package:truthworld/features/settings/data/models/download_settings.dart';
import 'package:truthworld/features/settings/data/models/playback_settings.dart';
import 'package:truthworld/features/settings/data/repositories/settings_repository.dart';

class UserSettingsController extends BaseController {
  static UserSettingsController get to {
    if (!Get.isRegistered<UserSettingsController>()) {
      Get.put(UserSettingsController());
    }
    return Get.find<UserSettingsController>();
  }

  final SettingsRepository _repository = SettingsRepository();

  // --- Reactive Settings Models ---
  final Rx<DigitalWellbeingSettings> wellbeing = const DigitalWellbeingSettings().obs;
  final Rx<PlaybackSettings> playback = const PlaybackSettings().obs;
  final Rx<DownloadSettings> downloads = const DownloadSettings().obs;
  final Rx<AccessibilitySettings> accessibility = const AccessibilitySettings().obs;

  // --- Reactive Individual Preferences ---
  final RxBool pushNotificationsEnabled = true.obs;
  final RxString channelAlerts = 'Personalized'.obs;
  final RxBool isSearchHistoryPaused = false.obs;
  final RxList<String> blockedUsers = <String>[].obs;
  final RxList<String> mutedKeywords = <String>[].obs;

  // --- Dynamic Media Storage State ---
  final RxDouble cacheSizeMB = 0.0.obs;

  // --- Platform Feature Capabilities ---
  bool get isBackgroundPlaybackSupported => !kIsWeb;
  bool get isSDCardAvailable => false; // Dynamic check for Android SD cards

  @override
  void onInit() {
    super.onInit();
    loadAllSettings();
    calculateCacheSize();
  }

  void loadAllSettings() {
    wellbeing.value = _repository.getDigitalWellbeing();
    playback.value = _repository.getPlayback();
    downloads.value = _repository.getDownloads();
    accessibility.value = _repository.getAccessibility();

    pushNotificationsEnabled.value = _repository.getPushEnabled();
    channelAlerts.value = _repository.getChannelAlerts();
    isSearchHistoryPaused.value = _repository.getSearchHistoryPaused();
    blockedUsers.assignAll(_repository.getBlockedUsers());
    mutedKeywords.assignAll(_repository.getMutedKeywords());
  }

  // ================= DIGITAL WELLBEING =================

  void updateWellbeing(DigitalWellbeingSettings updated) {
    wellbeing.value = updated;
    _repository.updateDigitalWellbeing(updated);
  }

  void setBreakReminder(int minutes) {
    updateWellbeing(wellbeing.value.copyWith(breakReminderMinutes: minutes));
    if (Get.isRegistered<DigitalWellbeingService>()) {
      DigitalWellbeingService.to.resetBreakTimer();
    }
  }

  void toggleBedtimeReminder(bool enabled) {
    updateWellbeing(wellbeing.value.copyWith(bedtimeEnabled: enabled));
  }

  void setBedtimeSchedule(
    String start,
    String end,
    String days, {
    bool? pauseAutoplay,
    bool? muteNotifications,
  }) {
    updateWellbeing(
      wellbeing.value.copyWith(
        bedtimeStartTime: start,
        bedtimeEndTime: end,
        bedtimeDaysSchedule: days,
        pauseAutoplayDuringBedtime:
            pauseAutoplay ?? wellbeing.value.pauseAutoplayDuringBedtime,
        muteNotificationsDuringBedtime:
            muteNotifications ?? wellbeing.value.muteNotificationsDuringBedtime,
      ),
    );
  }

  void toggleBedtimeAutoplay(bool pauseAutoplay) {
    updateWellbeing(
      wellbeing.value.copyWith(pauseAutoplayDuringBedtime: pauseAutoplay),
    );
  }

  void toggleBedtimeMuteNotifications(bool mute) {
    updateWellbeing(
      wellbeing.value.copyWith(muteNotificationsDuringBedtime: mute),
    );
  }

  bool verifyParentalPin(String inputPin) {
    final current = wellbeing.value;

    // Check if locked out
    if (current.lockoutUntil != null) {
      final lockoutTime = DateTime.parse(current.lockoutUntil!);
      if (DateTime.now().isBefore(lockoutTime)) {
        return false;
      }
    }

    final isValid = current.verifyPin(inputPin);
    if (isValid) {
      updateWellbeing(current.copyWith(failedPinAttempts: 0));
      return true;
    } else {
      final attempts = current.failedPinAttempts + 1;
      String? newLockout;
      if (attempts >= 5) {
        newLockout = DateTime.now()
            .add(const Duration(minutes: 15))
            .toIso8601String();
      }
      updateWellbeing(
        current.copyWith(
          failedPinAttempts: attempts,
          lockoutUntil: newLockout,
        ),
      );
      return false;
    }
  }

  void setParentalPin(String rawPin) {
    final hashed = DigitalWellbeingSettings.hashPin(rawPin);
    updateWellbeing(
      wellbeing.value.copyWith(
        parentalPinEnabled: true,
        hashedPin: hashed,
        failedPinAttempts: 0,
      ),
    );
  }

  void disableParentalPin() {
    updateWellbeing(
      wellbeing.value.copyWith(
        parentalPinEnabled: false,
        failedPinAttempts: 0,
      ),
    );
  }

  // ================= PLAYBACK & MEDIA =================

  void updatePlayback(PlaybackSettings updated) {
    playback.value = updated;
    _repository.updatePlayback(updated);
  }

  void setWifiQuality(String quality) {
    updatePlayback(playback.value.copyWith(wifiQuality: quality));
  }

  void setCellularQuality(String quality) {
    updatePlayback(playback.value.copyWith(cellularQuality: quality));
  }

  void toggleAutoplayNext(bool value) {
    updatePlayback(playback.value.copyWith(autoplayNext: value));
  }

  void setSeekDuration(int seconds) {
    updatePlayback(playback.value.copyWith(seekDurationSeconds: seconds));
  }

  void setVolumeNormalization(String mode) {
    updatePlayback(playback.value.copyWith(volumeNormalizationMode: mode));
  }

  void setBackgroundPlayback(String mode) {
    updatePlayback(playback.value.copyWith(backgroundPlaybackMode: mode));
  }

  void toggleStatsForNerds(bool value) {
    updatePlayback(playback.value.copyWith(statsForNerdsEnabled: value));
  }

  // ================= SMART DOWNLOADS & STORAGE =================

  void updateDownloads(DownloadSettings updated) {
    downloads.value = updated;
    _repository.updateDownloads(updated);
  }

  void toggleSmartDownloads(bool enabled) {
    updateDownloads(downloads.value.copyWith(smartDownloadsEnabled: enabled));
  }

  void setMaxStorageLimit(String limit) {
    updateDownloads(downloads.value.copyWith(maxStorageLimit: limit));
  }

  void setDownloadLocation(String location) {
    updateDownloads(downloads.value.copyWith(downloadLocation: location));
  }

  void setDownloadQuality(String quality) {
    updateDownloads(downloads.value.copyWith(downloadQuality: quality));
  }

  Future<void> clearCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
          await tempDir.create();
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UserSettingsController.clearCache',
      );
    }
    cacheSizeMB.value = 0.0;
  }

  Future<void> calculateCacheSize() async {
    if (kIsWeb) {
      cacheSizeMB.value = 0.0;
      return;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        var totalBytes = 0;
        await for (final entity in tempDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
        cacheSizeMB.value = totalBytes / (1024 * 1024);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UserSettingsController.calculateCacheSize',
      );
    }
  }

  // ================= ACCESSIBILITY & COMFORT =================

  void updateAccessibility(AccessibilitySettings updated) {
    accessibility.value = updated;
    _repository.updateAccessibility(updated);
  }

  void toggleReduceMotion(bool val) {
    updateAccessibility(accessibility.value.copyWith(reduceMotion: val));
  }

  void toggleHighContrastSubtitles(bool val) => updateAccessibility(
    accessibility.value.copyWith(highContrastSubtitles: val),
  );
  void toggleHapticFeedback(bool val) =>
      updateAccessibility(accessibility.value.copyWith(hapticFeedback: val));
  void setCaptionSize(String size) =>
      updateAccessibility(accessibility.value.copyWith(captionSize: size));
  void setColorBlindSupport(String mode) => updateAccessibility(
    accessibility.value.copyWith(colorBlindSupport: mode),
  );

  // ================= NOTIFICATIONS & PRIVACY =================

  void togglePushNotifications(bool value) {
    pushNotificationsEnabled.value = value;
    _repository.setPushEnabled(value);
    _syncNotificationPreferenceToFirestore('pushEnabled', value);
  }

  void setChannelAlerts(String level) {
    channelAlerts.value = level;
    _repository.setChannelAlerts(level);
    _syncNotificationPreferenceToFirestore('channelAlerts', level);
  }

  void _syncNotificationPreferenceToFirestore(String key, dynamic value) {
    try {
      if (Get.isRegistered<AuthService>()) {
        final uid = AuthService.to.uid;
        if (uid.isNotEmpty) {
          FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(uid)
              .set({
                'notificationSettings': {
                  key: value,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              }, SetOptions(merge: true))
              .catchError((Object e, StackTrace s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'UserSettingsController.updateNotificationSetting.firestore',
                );
              });
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UserSettingsController.updateNotificationSetting',
      );
    }
  }

  void toggleSearchHistoryPaused() {
    isSearchHistoryPaused.value = !isSearchHistoryPaused.value;
    _repository.setSearchHistoryPaused(isSearchHistoryPaused.value);
  }

  void clearSearchHistory() {
    _repository.clearSearchHistory();
    if (Get.isRegistered<search_ctrl.SearchController>()) {
      Get.find<search_ctrl.SearchController>().clearRecentSearches();
    }
  }

  void blockUser(String username) {
    final trimmed = username.trim();
    if (trimmed.isNotEmpty && !blockedUsers.contains(trimmed)) {
      blockedUsers.add(trimmed);
      _repository.setBlockedUsers(blockedUsers.toList());
    }
  }

  void unblockUser(String username) {
    blockedUsers.remove(username);
    _repository.setBlockedUsers(blockedUsers.toList());
  }

  void addMutedKeyword(String keyword) {
    final trimmed = keyword.trim().toLowerCase();
    if (trimmed.isNotEmpty && !mutedKeywords.contains(trimmed)) {
      mutedKeywords.add(trimmed);
      _repository.setMutedKeywords(mutedKeywords.toList());
    }
  }

  void removeMutedKeyword(String keyword) {
    mutedKeywords.remove(keyword);
    _repository.setMutedKeywords(mutedKeywords.toList());
  }

  // ================= RESET OPTIONS =================

  Future<void> resetWellbeing() async {
    await _repository.resetWellbeing();
    wellbeing.value = _repository.getDigitalWellbeing();
  }

  Future<void> resetPlayback() async {
    await _repository.resetPlayback();
    playback.value = _repository.getPlayback();
  }

  Future<void> resetDownloads() async {
    await _repository.resetDownloads();
    downloads.value = _repository.getDownloads();
  }

  Future<void> resetAccessibility() async {
    await _repository.resetAccessibility();
    accessibility.value = _repository.getAccessibility();
  }

  Future<void> resetAllSettings() async {
    await _repository.resetAll();
    loadAllSettings();
  }

  // ================= PROFILE & AVATAR MANAGEMENT =================

  final RxBool isUpdatingProfile = false.obs;
  final RxBool isUploadingAvatar = false.obs;
  final RxDouble avatarUploadProgress = 0.0.obs;
  StreamSubscription<DocumentSnapshot>? _avatarVerificationSubscription;

  @override
  void onClose() {
    _avatarVerificationSubscription?.cancel();
    super.onClose();
  }

  Future<bool> updateProfileDetails({
    required String displayName,
    required String handle,
    required String bio,
    required String gender,
    int? age,
    String? location,
  }) async {
    final auth = AuthService.to;
    final uid = auth.uid;
    if (uid.isEmpty) {
      AppSnackbar.error('User not authenticated');
      return false;
    }

    final cleanName = ContentValidator.cleanProfanity(displayName.trim());
    final cleanHandle = ContentValidator.cleanProfanity(handle.trim());
    final formattedHandle = cleanHandle.startsWith('@') ? cleanHandle : '@$cleanHandle';
    final cleanBio = ContentValidator.cleanProfanity(bio.trim());
    final cleanLocation = location?.trim() ?? '';

    isUpdatingProfile.value = true;
    try {
      // 1. Optimistically update AuthService in-memory reactive properties for instant UI response
      auth.userDisplayName.value = cleanName;
      auth.userHandle.value = formattedHandle;
      auth.userBio.value = cleanBio;
      auth.userGender.value = gender;
      auth.userAge.value = age;
      if (cleanLocation.isNotEmpty) {
        auth.userLocation.value = cleanLocation;
      } else {
        auth.userLocation.value = null;
      }

      // 2. Update FirebaseAuth currentUser displayName
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(cleanName);
      } catch (authErr, s) {
        ErrorHandler.log(
          authErr,
          stackTrace: s,
          tag: 'UserSettingsController.saveProfile.updateDisplayName',
        );
      }

      // 3. Prepare Firestore update map for users collection
      final userUpdates = <String, dynamic>{
        'displayName': cleanName,
        'name': cleanName,
        'handle': formattedHandle,
        'bio': cleanBio,
        'gender': gender,
        'age': age,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (cleanLocation.isNotEmpty) {
        userUpdates['location'] = cleanLocation;
      } else {
        userUpdates['location'] = FieldValue.delete();
        userUpdates['city'] = FieldValue.delete();
        userUpdates['state'] = FieldValue.delete();
        userUpdates['country'] = FieldValue.delete();
        auth.userCity.value = null;
        auth.userState.value = null;
        auth.userCountry.value = null;
      }

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(userUpdates, SetOptions(merge: true));

      // 4. If user has channel, synchronize channel document and auth.userChannel
      if (auth.hasChannel.value && auth.userChannel != null) {
        final channelId = auth.userChannel!.id;
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update({
              'name': cleanName,
              'displayName': cleanName,
              'handle': formattedHandle,
              'description': cleanBio,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        auth.setUserChannel(
          auth.userChannel?.copyWith(
            name: cleanName,
            handle: formattedHandle,
            description: cleanBio,
          ),
        );
      }

      AppSnackbar.success('Profile details saved.');
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to save profile details. Please try again.');
      return false;
    } finally {
      isUpdatingProfile.value = false;
    }
  }

  Future<void> changeAvatar({
    required ImageSource source,
    BuildContext? context,
  }) async {
    final auth = AuthService.to;
    final currentFirebaseUser = FirebaseAuth.instance.currentUser;
    final uid = (currentFirebaseUser != null && !currentFirebaseUser.isAnonymous)
        ? currentFirebaseUser.uid
        : auth.uid;

    if (uid.isEmpty) {
      AppSnackbar.error('User not authenticated. Please sign in again.');
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (pickedFile == null) return;

      final croppedFile = await ImageCropperService.cropChannelAvatar(
        imagePath: pickedFile.path,
        context: context ?? Get.context,
      );
      if (croppedFile == null) return; // User canceled crop

      isUploadingAvatar.value = true;
      avatarUploadProgress.value = 0.1;

      // Force fresh Firebase Auth token to guarantee storage authorization
      try {
        await currentFirebaseUser?.getIdToken();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserSettingsController.uploadAvatar.getIdToken',
        );
      }

      final bytes = await croppedFile.readAsBytes();
      if (bytes.isEmpty) {
        AppSnackbar.error('Selected image is empty. Please choose another image.');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar_${uid}_$timestamp.jpg';
      final storagePath = 'avatars/$uid/$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': uid,
          'category': 'avatar',
          'userId': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = storageRef.putData(bytes, metadata);

      uploadTask.snapshotEvents.listen(
        (taskSnapshot) {
          if (taskSnapshot.totalBytes > 0) {
            avatarUploadProgress.value =
                0.1 + (0.8 * (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes));
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UserSettingsController.avatarUpload',
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      avatarUploadProgress.value = 1.0;

      // Update in-memory AuthService immediately
      auth.userPhotoUrl.value = downloadUrl;
      auth.userAvatarFileId.value = fileName;
      auth.userAvatarStatus.value = 'PENDING';
      auth.userAvatarStatusReason.value = null;

      // Update FirebaseAuth currentUser
      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(downloadUrl);
      } catch (authErr, s) {
        ErrorHandler.log(
          authErr,
          stackTrace: s,
          tag: 'UserSettingsController.uploadAvatar.updatePhotoURL',
        );
      }

      // Update Firestore users collection
      final userAvatarUpdates = <String, dynamic>{
        'photoURL': downloadUrl,
        'avatarUrl': downloadUrl,
        'avatarFileId': fileName,
        'avatarStatus': 'PENDING',
        'avatarStatusReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(userAvatarUpdates, SetOptions(merge: true));

      // If user has a channel, update channel document as well
      if (auth.hasChannel.value && auth.userChannel != null) {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(auth.userChannel!.id)
            .update({
              'avatarUrl': downloadUrl,
              'photoUrl': downloadUrl,
              'avatarFileId': fileName,
              'avatarStatus': 'PENDING',
              'avatarStatusReason': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        auth.setUserChannel(
          auth.userChannel?.copyWith(
            avatarUrl: downloadUrl,
          ),
        );
      }

      AppSnackbar.info(
        'Avatar uploaded! Google Vision AI is validating safety...',
      );

      // Real-time listener on image_verification record for Google Cloud Vision completion
      _avatarVerificationSubscription?.cancel();
      _avatarVerificationSubscription = FirebaseFirestore.instance
          .collection('image_verification')
          .doc(fileName)
          .snapshots()
          .listen((verifSnap) {
        if (verifSnap.exists) {
          final data = verifSnap.data();
          final status = (data?['status'] as String?) ?? 'PENDING';
          final reason = (data?['reason'] as String?) ?? '';
          auth.userAvatarStatus.value = status;
          auth.userAvatarStatusReason.value = reason;

          if (status == 'APPROVED') {
            AppSnackbar.success('Avatar verified successfully by Google Vision AI.');
            _avatarVerificationSubscription?.cancel();
          } else if (status == 'REJECTED') {
            AppSnackbar.error(
              reason.isNotEmpty
                  ? 'Avatar rejected: $reason'
                  : 'Avatar rejected: violates image safety standards.',
            );
            _avatarVerificationSubscription?.cancel();
          } else if (status == 'FLAGGED') {
            AppSnackbar.warning(
              'Avatar flagged for potential review. Sent to moderation queue.',
            );
          }
        }
      }, onError: (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UserSettingsController.avatarVerification',
        );
      });
    } on FirebaseException catch (fe) {
      ErrorHandler.log(fe, tag: 'UserSettingsController.changeAvatar');
      if (fe.code == 'unauthorized' || fe.code == 'permission-denied') {
        AppSnackbar.error('Storage permission denied. Please sign in again.');
      } else {
        AppSnackbar.error('Unable to update avatar. Please try again.');
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'UserSettingsController.changeAvatar');
      AppSnackbar.error('Unable to change avatar. Please try again.');
    } finally {
      isUploadingAvatar.value = false;
      avatarUploadProgress.value = 0.0;
    }
  }

  Future<void> removeAvatar() async {
    final auth = AuthService.to;
    final uid = auth.uid;
    if (uid.isEmpty) return;

    try {
      auth.userPhotoUrl.value = null;
      auth.userAvatarFileId.value = null;
      auth.userAvatarStatus.value = null;
      auth.userAvatarStatusReason.value = null;

      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserSettingsController.removeAvatar.updatePhotoURL',
        );
      }

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set({
            'photoURL': FieldValue.delete(),
            'avatarUrl': FieldValue.delete(),
            'avatarFileId': FieldValue.delete(),
            'avatarStatus': FieldValue.delete(),
            'avatarStatusReason': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (auth.hasChannel.value && auth.userChannel != null) {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(auth.userChannel!.id)
            .update({
              'avatarUrl': FieldValue.delete(),
              'photoUrl': FieldValue.delete(),
              'avatarFileId': FieldValue.delete(),
              'avatarStatus': FieldValue.delete(),
              'avatarStatusReason': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        auth.setUserChannel(
          auth.userChannel?.copyWith(
            avatarUrl: '',
          ),
        );
      }

      AppSnackbar.success('Avatar removed.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'UserSettingsController.removeAvatar');
      AppSnackbar.error('Unable to remove avatar. Please try again.');
    }
  }
}
