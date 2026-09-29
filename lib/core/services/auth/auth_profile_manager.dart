import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/google_onboarding_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/channel.dart';

/// Manages user profile fields, active fallback getters, and onboarding flow.
class AuthProfileManager {
  final RxnString userDisplayName = RxnString();
  final RxnString userHandle = RxnString();
  final RxnString userBio = RxnString();
  final RxnString userPhotoUrl = RxnString();
  final RxnString userAvatarStatus = RxnString();
  final RxnString userAvatarStatusReason = RxnString();
  final RxnString userAvatarFileId = RxnString();
  final RxnString userGender = RxnString();
  final RxnInt userAge = RxnInt();
  final RxnString userAgeGroup = RxnString();
  final RxnString userBirthdate = RxnString();
  final RxnString userLocation = RxnString();
  final RxnString userCity = RxnString();
  final RxnString userState = RxnString();
  final RxnString userCountry = RxnString();
  final RxnString userProfession = RxnString();
  final RxBool needsOnboarding = false.obs;

  StreamSubscription? _userDocSubscription;
  bool _isOnboardingPromptShowing = false;

  /// Resolves display name prioritizing channel → user doc → Firebase user → fallback.
  String getActiveDisplayName({
    Channel? userChannel,
    bool hasChannel = false,
    User? user,
  }) {
    // When user has a channel, channel name takes precedence
    if (hasChannel && userChannel != null && userChannel.name.isNotEmpty) {
      return userChannel.name;
    }
    if (userDisplayName.value != null &&
        userDisplayName.value!.trim().isNotEmpty) {
      return userDisplayName.value!.trim();
    }
    if (user != null &&
        !user.isAnonymous &&
        user.displayName?.isNotEmpty == true) {
      return user.displayName!;
    }
    return 'User';
  }

  /// Resolves avatar photo prioritizing channel → user doc → Firebase user → empty.
  String getActivePhotoUrl({
    Channel? userChannel,
    bool hasChannel = false,
    User? user,
  }) {
    // When user has a channel, channel avatar takes precedence
    if (hasChannel && userChannel != null && userChannel.avatarUrl.isNotEmpty) {
      return userChannel.avatarUrl;
    }
    if (userPhotoUrl.value != null && userPhotoUrl.value!.isNotEmpty) {
      return userPhotoUrl.value!;
    }
    if (user != null &&
        !user.isAnonymous &&
        user.photoURL?.isNotEmpty == true) {
      return user.photoURL!;
    }
    return '';
  }

  /// Resolves handle prioritizing channel → user doc → user email prefix → '@user'.
  String getActiveHandle({
    Channel? userChannel,
    bool hasChannel = false,
    User? user,
  }) {
    // When user has a channel, channel handle takes precedence
    if (hasChannel && userChannel != null && userChannel.handle.isNotEmpty) {
      final handle = userChannel.handle;
      return handle.startsWith('@') ? handle : '@$handle';
    }
    if (userHandle.value != null && userHandle.value!.trim().isNotEmpty) {
      final handle = userHandle.value!.trim();
      return handle.startsWith('@') ? handle : '@$handle';
    }
    final email = user?.email ?? '';
    if (user != null && !user.isAnonymous && email.isNotEmpty) {
      return "@${email.split('@')[0]}";
    }
    return '@user';
  }

  /// Resolves user biography prioritizing user doc -> user channel description -> empty.
  String getActiveBio({
    Channel? userChannel,
    bool hasChannel = false,
    User? user,
  }) {
    if (userBio.value != null && userBio.value!.isNotEmpty) {
      return userBio.value!;
    }
    if (hasChannel &&
        userChannel != null &&
        userChannel.description.isNotEmpty) {
      return userChannel.description;
    }
    return '';
  }

  /// Listens to real-time updates from Firestore 'users' document.
  void updateUserDocSubscription(
    User? user, {
    required void Function(Map<String, dynamic> data) onUserData,
    required VoidCallback onUserDocMissingOrSignedOut,
  }) {
    _userDocSubscription?.cancel();

    if (user == null) {
      clearProfile();
      onUserDocMissingOrSignedOut();
      return;
    }

    _userDocSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() ?? {};
              onUserData(data);

              userDisplayName.value =
                  (data['displayName'] as String?) ??
                  (data['name'] as String?);
              userHandle.value = data['handle'] as String?;
              userBio.value = data['bio'] as String?;
              userPhotoUrl.value =
                  (data['photoURL'] as String?) ??
                  (data['photoUrl'] as String?) ??
                  (data['avatarUrl'] as String?);
              userAvatarStatus.value = data['avatarStatus'] as String?;
              userAvatarStatusReason.value =
                  data['avatarStatusReason'] as String?;
              userAvatarFileId.value = data['avatarFileId'] as String?;
              userGender.value = data['gender'] as String?;
              userAge.value = (data['age'] as num?)?.toInt();
              userAgeGroup.value = data['ageGroup'] as String?;
              userBirthdate.value = data['birthdate'] as String?;
              userLocation.value = data['location'] as String?;
              userCity.value = data['city'] as String?;
              userState.value = data['state'] as String?;
              userCountry.value = data['country'] as String?;
              userProfession.value = (data['profession'] as String?) ??
                  (data['occupation'] as String?);

              final hasCompletedOnboarding =
                  data['hasCompletedOnboarding'] as bool? ??
                  (data['birthdate'] != null &&
                      data['birthdate'].toString().isNotEmpty);
              needsOnboarding.value = !hasCompletedOnboarding;
            } else {
              onUserDocMissingOrSignedOut();
              clearProfile();
            }
          },
          onError: (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'AuthProfileManager.userDocSubscription',
            );
          },
        );
  }

  /// Clears in-memory profile observables.
  void clearProfile() {
    userDisplayName.value = null;
    userHandle.value = null;
    userBio.value = null;
    userPhotoUrl.value = null;
    userAvatarStatus.value = null;
    userAvatarStatusReason.value = null;
    userAvatarFileId.value = null;
    userGender.value = null;
    userAge.value = null;
    userAgeGroup.value = null;
    userBirthdate.value = null;
    userLocation.value = null;
    userCity.value = null;
    userState.value = null;
    userCountry.value = null;
    userProfession.value = null;
    needsOnboarding.value = false;
  }

  /// Updates profile with optional Age Group and optional Gender after Google Sign-In or Settings update.
  Future<void> updateUserProfileOnboarding(
    User? currentUser, {
    String? ageGroup,
    String? gender,
  }) async {
    if (currentUser == null) return;

    final updateData = <String, dynamic>{'hasCompletedOnboarding': true};

    if (ageGroup != null && ageGroup.trim().isNotEmpty) {
      final trimmedAge = ageGroup.trim();
      updateData['ageGroup'] = trimmedAge;
      userAgeGroup.value = trimmedAge;
    } else {
      updateData['ageGroup'] = FieldValue.delete();
      userAgeGroup.value = null;
    }

    if (gender != null && gender.trim().isNotEmpty) {
      final trimmedGender = gender.trim();
      updateData['gender'] = trimmedGender;
      userGender.value = trimmedGender;
    } else {
      updateData['gender'] = FieldValue.delete();
      userGender.value = null;
    }

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(currentUser.uid)
        .set(updateData, SetOptions(merge: true));

    needsOnboarding.value = false;
  }

  /// Skips onboarding while marking it as completed for the current user.
  Future<void> skipUserOnboarding(User? currentUser) async {
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(currentUser.uid)
        .update({'hasCompletedOnboarding': true});

    needsOnboarding.value = false;
  }

  /// Prompts onboarding sheet if a newly signed-in user needs to complete Date of Birth / Gender details.
  Future<void> checkAndPromptOnboarding({
    required bool isAuthenticated,
    required User? currentUser,
    BuildContext? context,
  }) async {
    if (_isOnboardingPromptShowing) return;

    // Safety guard: Never show for unsigned, guest, or anonymous users
    if (currentUser == null || currentUser.isAnonymous || !isAuthenticated) {
      needsOnboarding.value = false;
      return;
    }

    // Only prompt if onboarding is actually flagged as needed (new signed user)
    if (!needsOnboarding.value) return;

    final ctx = context ?? Get.context;
    if (ctx == null) return;

    if (ctx.mounted && !_isOnboardingPromptShowing) {
      _isOnboardingPromptShowing = true;
      try {
        await GoogleOnboardingSheet.show(ctx);
      } finally {
        _isOnboardingPromptShowing = false;
      }
    }
  }

  /// Cancels active Firestore user document subscription.
  void dispose() {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }
}
