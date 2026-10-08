import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/components/ui/google_onboarding_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/channel.dart';

/// Manages user profile fields, active fallback getters, and onboarding flow.
class AuthProfileManager {
  final RxnString userDisplayName = RxnString();
  final RxnString userHandle = RxnString();
  final RxnString userBio = RxnString();
  final RxnString userPhotoUrl = RxnString();
  final RxnString userEmail = RxnString();
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
  final RxnString userPhoneNumber = RxnString();
  final RxBool isPhoneVerified = false.obs;
  final RxBool isEmailVerified = false.obs;
  final RxBool needsOnboarding = false.obs;

  StreamSubscription? _userDocSubscription;
  String? _subscribedUid;
  bool _isOnboardingPromptShowing = false;

  /// Loads cached profile information synchronously from local storage.
  void initCachedProfile(String? uid) {
    if (uid == null || uid.isEmpty) return;
    try {
      final box = GetStorage();
      final cachedName = box.read<String>('profile_name_$uid');
      if (cachedName != null && cachedName.isNotEmpty) {
        userDisplayName.value = cachedName;
      }
      final cachedHandle = box.read<String>('profile_handle_$uid');
      if (cachedHandle != null && cachedHandle.isNotEmpty) {
        userHandle.value = cachedHandle;
      }
      final cachedPhoto = box.read<String>('profile_photo_$uid');
      if (cachedPhoto != null && cachedPhoto.isNotEmpty) {
        userPhotoUrl.value = cachedPhoto;
      }
      final cachedBio = box.read<String>('profile_bio_$uid');
      if (cachedBio != null && cachedBio.isNotEmpty) {
        userBio.value = cachedBio;
      }
      final cachedEmail = box.read<String>('profile_email_$uid');
      if (cachedEmail != null && cachedEmail.isNotEmpty) {
        userEmail.value = cachedEmail;
      }
      final cachedPhone = box.read<String>('profile_phone_$uid');
      if (cachedPhone != null && cachedPhone.isNotEmpty) {
        userPhoneNumber.value = cachedPhone;
        isPhoneVerified.value = true;
      }
      final cachedEmailVerified = box.read<bool>('profile_email_verified_$uid') ?? false;
      isEmailVerified.value = cachedEmailVerified;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthProfileManager.initCachedProfile',
      );
    }
  }

  /// Persists profile details locally for instant rendering on page refresh.
  void cacheProfile(String uid) {
    try {
      final box = GetStorage();
      if (userDisplayName.value != null) {
        box.write('profile_name_$uid', userDisplayName.value);
      }
      if (userHandle.value != null) {
        box.write('profile_handle_$uid', userHandle.value);
      }
      if (userPhotoUrl.value != null) {
        box.write('profile_photo_$uid', userPhotoUrl.value);
      }
      if (userBio.value != null) {
        box.write('profile_bio_$uid', userBio.value);
      }
      if (userEmail.value != null) {
        box.write('profile_email_$uid', userEmail.value);
      }
      if (userPhoneNumber.value != null) {
        box.write('profile_phone_$uid', userPhoneNumber.value);
      }
      box.write('profile_email_verified_$uid', isEmailVerified.value);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthProfileManager.cacheProfile');
    }
  }

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
    final email = (user != null && !user.isAnonymous && user.email?.isNotEmpty == true)
        ? user.email!
        : (userEmail.value ?? '');
    if (email.isNotEmpty) {
      return "@${email.split('@')[0]}";
    }
    final phone = user?.phoneNumber ?? '';
    if (user != null && !user.isAnonymous && phone.isNotEmpty) {
      final last4 = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      return '@user_$last4';
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
    if (user == null) {
      _subscribedUid = null;
      _userDocSubscription?.cancel();
      _userDocSubscription = null;
      clearProfile();
      onUserDocMissingOrSignedOut();
      return;
    }

    if (_subscribedUid == user.uid && _userDocSubscription != null) {
      return;
    }

    _subscribedUid = user.uid;
    _userDocSubscription?.cancel();

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

              final resolvedPhone = (data['phoneNumber'] as String?) ??
                  ((data['metadata'] is Map)
                      ? (data['metadata']['phoneNumber'] as String?)
                      : null) ??
                  user.phoneNumber;
              if (resolvedPhone != null && resolvedPhone.isNotEmpty) {
                userPhoneNumber.value = resolvedPhone;
                isPhoneVerified.value = true;
              } else {
                userPhoneNumber.value = null;
                isPhoneVerified.value = false;
              }

              final resolvedEmail = (data['email'] as String?) ?? user.email;
              if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
                userEmail.value = resolvedEmail;
                isEmailVerified.value = user.emailVerified ||
                    (data['emailVerified'] as bool? ?? false) ||
                    (data['isEmailVerified'] as bool? ?? false);
              } else {
                isEmailVerified.value = false;
              }

              final hasCompletedOnboarding =
                  data['hasCompletedOnboarding'] as bool? ??
                  (data['birthdate'] != null &&
                      data['birthdate'].toString().isNotEmpty);
              needsOnboarding.value = !hasCompletedOnboarding;
              cacheProfile(user.uid);
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
    userEmail.value = null;
    userPhoneNumber.value = null;
    isPhoneVerified.value = false;
    isEmailVerified.value = false;
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

  /// Updates profile with optional Age Group, optional Gender, and optional Username/Handle after Sign-In or Settings update.
  Future<void> updateUserProfileOnboarding(
    User? currentUser, {
    String? ageGroup,
    String? gender,
    String? username,
    String? displayName,
  }) async {
    if (currentUser == null) return;

    final updateData = <String, dynamic>{
      'hasCompletedOnboarding': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

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

    if (username != null && username.trim().isNotEmpty) {
      final rawUsername = username.trim().replaceAll('@', '');
      final cleanUsername = ContentValidator.cleanProfanity(rawUsername);
      final formattedHandle = '@$cleanUsername';
      updateData['handle'] = formattedHandle;
      updateData['username'] = cleanUsername;
      userHandle.value = formattedHandle;

      final nameToSet = (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : (userDisplayName.value != null &&
                  userDisplayName.value!.isNotEmpty &&
                  !userDisplayName.value!.startsWith('User '))
              ? userDisplayName.value!
              : cleanUsername;

      updateData['displayName'] = nameToSet;
      updateData['name'] = nameToSet;
      userDisplayName.value = nameToSet;

      try {
        await currentUser.updateDisplayName(nameToSet);
      } catch (authErr, s) {
        ErrorHandler.log(
          authErr,
          stackTrace: s,
          tag: 'AuthProfileManager.updateUserProfileOnboarding.updateDisplayName',
        );
      }
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

    // If an authentication bottom sheet is currently open, defer prompt until it closes
    if (AuthBottomSheet.isOpen) return;

    final ctx = context ?? Get.key.currentContext ?? Get.context;
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
    _subscribedUid = null;
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }
}
