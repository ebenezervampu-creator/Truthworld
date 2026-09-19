import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart'
    hide GoogleSignInException;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth/auth_barrel.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/data/models/channel.dart';

export 'auth/auth_barrel.dart';

/// Central authentication service coordinating sessions, profile sync, channel state, and premium tiers.
class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();

  final AuthPremiumManager _premiumManager = AuthPremiumManager();
  final AuthChannelManager _channelManager = AuthChannelManager();
  final AuthProfileManager _profileManager = AuthProfileManager();
  final AuthFirestoreSync _firestoreSync = AuthFirestoreSync();
  final AuthGoogleSignInProvider _googleProvider = AuthGoogleSignInProvider();

  // Sub-manager accessors for advanced modular usage
  AuthPremiumManager get premiumManager => _premiumManager;
  AuthChannelManager get channelManager => _channelManager;
  AuthProfileManager get profileManager => _profileManager;
  AuthFirestoreSync get firestoreSync => _firestoreSync;
  AuthGoogleSignInProvider get googleProvider => _googleProvider;

  FirebaseAuth? _authOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  set _auth(FirebaseAuth val) => _authOverride = val;

  GoogleSignIn get _googleSignIn => _googleProvider.googleSignIn;

  final Rxn<User> _user = Rxn<User>();
  Rxn<User> get currentUser => _user;
  User? get user => _user.value;

  final RxBool _isAuthenticated = false.obs;
  RxBool get isAuthenticated => _isAuthenticated;
  bool get isUserSignedIn => _isAuthenticated.value;

  String get uid =>
      (_isAuthenticated.value &&
          _user.value != null &&
          !_user.value!.isAnonymous)
      ? _user.value!.uid
      : '';

  // Channel delegation
  RxBool get hasChannel => _channelManager.hasChannel;
  Channel? get userChannel => _channelManager.userChannel;
  Rxn<Channel> get rxUserChannel => _channelManager.rxUserChannel;

  void setUserChannel(Channel? channel) =>
      _channelManager.setUserChannel(channel, _user.value?.uid);

  void clearUserChannel() =>
      _channelManager.clearUserChannel(_user.value?.uid);

  Future<Channel?> ensureChannelLoaded() =>
      _channelManager.ensureChannelLoaded(_user.value, _auth);

  // Premium delegation
  RxBool get isPremiumUser => _premiumManager.isPremiumUser;
  RxnString get premiumPlanId => _premiumManager.premiumPlanId;
  RxnInt get premiumStartedAt => _premiumManager.premiumStartedAt;
  RxnInt get premiumExpiresAt => _premiumManager.premiumExpiresAt;

  bool get isTrialExpired => _premiumManager.isTrialExpired;
  bool get isAudioPremiumOnly => _premiumManager.isAudioPremiumOnly;
  bool get hasFullPremium => _premiumManager.hasFullPremium;
  bool get hasFactCheckPremium => _premiumManager.hasFactCheckPremium;
  void checkTrialExpiry() => _premiumManager.checkTrialExpiry();
  String get formattedStartedDate => _premiumManager.formattedStartedDate;
  String get formattedExpiresDate => _premiumManager.formattedExpiresDate;
  String get formattedRemainingTime => _premiumManager.formattedRemainingTime;

  Future<void> cancelPremiumSubscription() =>
      _premiumManager.cancelPremiumSubscription(
        _user.value,
        onTokenRefresh: forceRefreshToken,
      );

  // Profile delegation
  RxnString get userDisplayName => _profileManager.userDisplayName;
  RxnString get userHandle => _profileManager.userHandle;
  RxnString get userBio => _profileManager.userBio;
  RxnString get userPhotoUrl => _profileManager.userPhotoUrl;
  RxnString get userAvatarStatus => _profileManager.userAvatarStatus;
  RxnString get userAvatarStatusReason =>
      _profileManager.userAvatarStatusReason;
  RxnString get userAvatarFileId => _profileManager.userAvatarFileId;
  RxnString get userGender => _profileManager.userGender;
  RxnInt get userAge => _profileManager.userAge;
  RxnString get userAgeGroup => _profileManager.userAgeGroup;
  RxnString get userBirthdate => _profileManager.userBirthdate;
  RxnString get userLocation => _profileManager.userLocation;
  RxnString get userCity => _profileManager.userCity;
  RxnString get userState => _profileManager.userState;
  RxnString get userCountry => _profileManager.userCountry;
  RxDouble get userWalletBalance => _profileManager.userWalletBalance;
  double get walletBalance => _profileManager.userWalletBalance.value;
  RxBool get needsOnboarding => _profileManager.needsOnboarding;

  String get activeDisplayName => _profileManager.getActiveDisplayName(
    userChannel: userChannel,
    hasChannel: hasChannel.value,
    user: user,
  );

  String get activePhotoUrl => _profileManager.getActivePhotoUrl(
    userChannel: userChannel,
    hasChannel: hasChannel.value,
    user: user,
  );

  String get activeHandle => _profileManager.getActiveHandle(
    userChannel: userChannel,
    hasChannel: hasChannel.value,
    user: user,
  );

  String get activeBio => _profileManager.getActiveBio(
    userChannel: userChannel,
    hasChannel: hasChannel.value,
    user: user,
  );

  Future<void> updateUserProfileOnboarding({
    String? ageGroup,
    String? gender,
  }) => _profileManager.updateUserProfileOnboarding(
    user,
    ageGroup: ageGroup,
    gender: gender,
  );

  Future<void> skipUserOnboarding() => _profileManager.skipUserOnboarding(user);

  Future<void> checkAndPromptOnboarding([BuildContext? context]) =>
      _profileManager.checkAndPromptOnboarding(
        isAuthenticated: _isAuthenticated.value,
        currentUser: user,
        context: context,
      );

  @override
  void onInit() {
    super.onInit();
    try {
      _auth = FirebaseAuth.instance;
      final current = _auth.currentUser;
      if (current != null && !current.isAnonymous) {
        _user.value = current;
        _isAuthenticated.value = true;
      }
      _premiumManager.loadCachedPremiumStatus();
      _channelManager.initCachedChannelStatus(current?.uid);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.onInit');
    }
  }

  /// Safe async initialization of authentication streams and caches.
  Future<AuthService> init() async {
    _auth = FirebaseAuth.instance;

    _premiumManager.loadCachedPremiumStatus();
    _channelManager.initCachedChannelStatus(_auth.currentUser?.uid);
    await _googleProvider.initialize();

    // Purge any lingering anonymous session
    try {
      if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
        await _auth.signOut();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.purgeAnonymousUser');
    }

    _user.bindStream(_auth.authStateChanges());
    ever(_user, _handleAuthChanged);

    return this;
  }

  void _handleAuthChanged(User? u) {
    if (u != null && u.isAnonymous) {
      _isAuthenticated.value = false;
      _channelManager.updateChannelSubscription(null);
      _profileManager.updateUserDocSubscription(
        null,
        onUserData: (_) {},
        onUserDocMissingOrSignedOut: _premiumManager.resetToCached,
      );
      needsOnboarding.value = false;
      _auth.signOut().catchError((e) {
        debugPrint('AuthService: signOut anonymous error: $e');
      });
      return;
    }

    final isRealUser = u != null && !u.isAnonymous;
    _isAuthenticated.value = isRealUser;
    _channelManager.updateChannelSubscription(isRealUser ? u : null);
    _profileManager.updateUserDocSubscription(
      isRealUser ? u : null,
      onUserData:
          (data) => _premiumManager.updateFromUserData(
            data,
            onTokenRefresh: forceRefreshToken,
          ),
      onUserDocMissingOrSignedOut: _premiumManager.resetToCached,
    );

    if (isRealUser) {
      _firestoreSync
          .syncUserToFirestore(
            u,
            lastGooglePeopleData: _googleProvider.lastGooglePeopleData,
            onNeedsOnboardingChanged: (val) => needsOnboarding.value = val,
            onPromptOnboarding: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                checkAndPromptOnboarding();
              });
            },
          )
          .then((_) {
            PushNotificationService.to.registerToken(u.uid);
          });
    } else {
      needsOnboarding.value = false;
    }
  }

  @override
  void onClose() {
    _channelManager.dispose();
    _profileManager.dispose();
    super.onClose();
  }

  /// Force-refreshes the Firebase Auth ID token and custom claims
  Future<String?> forceRefreshToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken(true);
      logger.info(
        'Firebase Auth token & custom claims force-refreshed successfully',
        tag: 'Auth',
      );
      return token;
    } catch (e) {
      logger.warning(
        'Failed to force-refresh Firebase Auth token: $e',
        tag: 'Auth',
      );
      return null;
    }
  }

  /// Initiates sign-in using Google provider.
  Future<UserCredential> signInWithGoogle() async {
    final credential = await _googleProvider.signInWithGoogle(_auth);
    final u = credential.user;
    if (u != null) {
      _user.value = u;
      _isAuthenticated.value = true;
      await _firestoreSync.syncUserToFirestore(
        u,
        lastGooglePeopleData: _googleProvider.lastGooglePeopleData,
        onNeedsOnboardingChanged: (val) => needsOnboarding.value = val,
      );
      PushNotificationService.to.registerToken(u.uid);
    }
    return credential;
  }

  /// Retries Google Sign-In with exponential backoff.
  Future<UserCredential> retryGoogleSignIn({int maxRetries = 2}) =>
      _googleProvider.retryGoogleSignIn(_auth, maxRetries: maxRetries);

  /// Signs out user and unregisters push notification device token.
  Future<void> signOut() async {
    try {
      final uidSnapshot = uid;
      if (uidSnapshot.isNotEmpty) {
        await PushNotificationService.to.unregisterToken(uidSnapshot);
      }
      await _googleProvider.signOut();
      await _auth.signOut();
    } catch (e) {
      logger.warning('Error during sign out: $e', tag: 'AUTH');
      _user.value = null;
      _isAuthenticated.value = false;
      needsOnboarding.value = false;
      rethrow;
    }
  }

  Future<void> logout() => signOut();

  /// Deletes user profile, marks associated channel as deleted, and deletes Firebase Auth user.
  Future<void> deleteAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final uidToDelete = currentUser.uid;
      await _firestoreSync.deleteAccountData(uidToDelete);
      await currentUser.delete();
      _user.value = null;
      _isAuthenticated.value = false;
      needsOnboarding.value = false;
    }
  }
}
