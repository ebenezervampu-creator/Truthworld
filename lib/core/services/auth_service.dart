import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart'
    hide GoogleSignInException;
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth/auth_barrel.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/core/services/user_session_reset_manager.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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
  final AuthAppleSignInProvider _appleProvider = AuthAppleSignInProvider();
  final AuthPhoneSignInProvider _phoneProvider = AuthPhoneSignInProvider();

  // Sub-manager accessors for advanced modular usage
  AuthPremiumManager get premiumManager => _premiumManager;
  AuthChannelManager get channelManager => _channelManager;
  AuthProfileManager get profileManager => _profileManager;
  AuthFirestoreSync get firestoreSync => _firestoreSync;
  AuthGoogleSignInProvider get googleProvider => _googleProvider;
  AuthAppleSignInProvider get appleProvider => _appleProvider;
  AuthPhoneSignInProvider get phoneProvider => _phoneProvider;

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

  String? _cachedUid;

  String get uid {
    if (_user.value != null && !_user.value!.isAnonymous) {
      return _user.value!.uid;
    }
    if (_isAuthenticated.value && _cachedUid != null && _cachedUid!.isNotEmpty) {
      return _cachedUid!;
    }
    return '';
  }

  String get email =>
      _user.value?.email ?? _profileManager.userEmail.value ?? '';

  // Channel delegation
  RxBool get hasChannel => _channelManager.hasChannel;
  Channel? get userChannel => _channelManager.userChannel;
  Rxn<Channel> get rxUserChannel => _channelManager.rxUserChannel;
  Channel? get deletedChannel => _channelManager.deletedChannel;
  Rxn<Channel> get rxDeletedChannel => _channelManager.rxDeletedChannel;

  void setUserChannel(Channel? channel, [String? uid]) =>
      _channelManager.setUserChannel(channel, uid ?? _user.value?.uid);

  void setDeletedChannel(Channel? channel) =>
      _channelManager.setDeletedChannel(channel);

  void clearUserChannel([String? uid]) =>
      _channelManager.clearUserChannel(uid ?? _user.value?.uid);

  Future<Channel?> ensureChannelLoaded() =>
      _channelManager.ensureChannelLoaded(_user.value, _auth);

  Future<Channel?> refreshUserChannel() =>
      _channelManager.ensureChannelLoaded(_user.value, _auth, forceRefresh: true);

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
  RxnString get userProfession => _profileManager.userProfession;
  RxnString get userEmail => _profileManager.userEmail;
  RxnString get userPhoneNumber => _profileManager.userPhoneNumber;
  RxBool get isPhoneVerified => _profileManager.isPhoneVerified;
  RxBool get isEmailVerified => _profileManager.isEmailVerified;
  RxBool get needsOnboarding => _profileManager.needsOnboarding;
  bool get hasPendingOnboardingPrompt => _profileManager.hasPendingOnboardingPrompt;

  bool _isNewUserHeuristic(User u) {
    final creation = u.metadata.creationTime;
    final lastSignIn = u.metadata.lastSignInTime;
    if (creation != null && lastSignIn != null) {
      return lastSignIn.difference(creation).inSeconds.abs() <= 10;
    }
    return false;
  }

  String get activeDisplayName => _profileManager.getActiveDisplayName(
    userChannel: userChannel,
    hasChannel: hasChannel.value,
    user: user,
  );

  String get activePhotoUrl => _profileManager.getActivePhotoUrl(
    userChannel: userChannel,
    hasChannel: hasChannel.value,
    user: user,
    currentUid: uid,
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
    String? country,
    String? ageGroup,
    String? gender,
    String? username,
    String? displayName,
    String? primaryLanguage,
  }) => _profileManager.updateUserProfileOnboarding(
    user,
    country: country,
    ageGroup: ageGroup,
    gender: gender,
    username: username,
    displayName: displayName,
    primaryLanguage: primaryLanguage,
  );

  Future<void> skipUserOnboarding({String? defaultCountry}) =>
      _profileManager.skipUserOnboarding(user, defaultCountry: defaultCountry);

  Future<void> checkAndPromptOnboarding([BuildContext? context]) =>
      _profileManager.checkAndPromptOnboarding(
        isAuthenticated: _isAuthenticated.value,
        currentUser: user,
        context: context,
      );

  StreamSubscription<User?>? _authStateSub;
  String? _lastHandledUid;
  bool _isInitialAuthRestorationPending = false;

  @override
  void onInit() {
    super.onInit();
    try {
      _auth = FirebaseAuth.instance;
      _initCachedSession();
      _setupAuthStateListener();
      _premiumManager.loadCachedPremiumStatus();
      _channelManager.initCachedChannelStatus(_cachedUid ?? _auth.currentUser?.uid);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.onInit');
    }
  }

  void _initCachedSession() {
    try {
      final box = GetStorage();
      final hasActiveSession =
          box.read<bool>('auth_has_active_session') ?? false;
      final hasPendingRedirect =
          box.read<bool>('auth_pending_redirect') ?? false;

      var validPendingRedirect = false;
      if (hasPendingRedirect) {
        final redirectTime = box.read<int>('auth_pending_redirect_time') ?? 0;
        final elapsed = DateTime.now().millisecondsSinceEpoch - redirectTime;
        if (elapsed < 600000) {
          validPendingRedirect = true;
        } else {
          box.remove('auth_pending_redirect');
          box.remove('auth_pending_redirect_time');
        }
      }

      if (hasActiveSession) {
        _isAuthenticated.value = true;
        _isInitialAuthRestorationPending = kIsWeb;
        _cachedUid = box.read<String>('auth_session_uid');
        if (_cachedUid != null && _cachedUid!.isNotEmpty) {
          _profileManager.initCachedProfile(_cachedUid);
        }
      } else if (validPendingRedirect) {
        _isInitialAuthRestorationPending = kIsWeb;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService._initCachedSession');
    }
  }

  void _setupAuthStateListener() {
    _authStateSub?.cancel();
    _authStateSub = _auth.authStateChanges().listen(_handleAuthChanged);

    final current = _auth.currentUser;
    if (current != null && !current.isAnonymous) {
      _handleAuthChanged(current);
    }
  }

  /// Safe async initialization of authentication streams and caches.
  Future<AuthService> init() async {
    _auth = FirebaseAuth.instance;

    // Enforce persistence on Web so sessions survive tab closures and page refreshes
    if (kIsWeb) {
      try {
        await _auth
            .setPersistence(Persistence.LOCAL)
            .timeout(const Duration(milliseconds: 1000), onTimeout: () {});
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.setPersistence');
      }
    }

    _premiumManager.loadCachedPremiumStatus();
    _channelManager.initCachedChannelStatus(_cachedUid ?? _auth.currentUser?.uid);
    await _googleProvider.initialize();

    // Check for web redirect result if coming back from redirect flow
    if (kIsWeb) {
      final box = GetStorage();
      final wasPendingRedirect =
          box.read<bool>('auth_pending_redirect') ?? false;

      try {
        UserCredential? redirectResult;
        try {
          redirectResult = await _auth
              .getRedirectResult()
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          redirectResult = null;
        }
        final redirectUser = redirectResult?.user;
        if (redirectUser != null && !redirectUser.isAnonymous) {
          box.remove('auth_pending_redirect');
          box.remove('auth_pending_redirect_time');
          _isInitialAuthRestorationPending = false;
          _user.value = redirectUser;
          _isAuthenticated.value = true;
          _cachedUid = redirectUser.uid;
          box.write('auth_has_active_session', true);
          box.write('auth_session_uid', redirectUser.uid);
          await _handlePostSignIn(
            redirectUser,
            lastGooglePeopleData: _googleProvider.lastGooglePeopleData,
          );
          _handleAuthChanged(redirectUser);
          debugPrint(
            'AuthService: Successfully authenticated via redirect (${redirectUser.email})',
          );
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.getRedirectResult');
      }

      // If returning from redirect but getRedirectResult didn't return a user yet,
      // wait briefly for currentUser or IndexedDB to settle
      if (wasPendingRedirect && (_user.value == null || _user.value!.isAnonymous)) {
        for (var i = 0; i < 10; i++) {
          final current = _auth.currentUser;
          if (current != null && !current.isAnonymous) {
            box.remove('auth_pending_redirect');
            box.remove('auth_pending_redirect_time');
            _isInitialAuthRestorationPending = false;
            await _handlePostSignIn(
              current,
              lastGooglePeopleData: _googleProvider.lastGooglePeopleData,
            );
            _handleAuthChanged(current);
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }

      if (wasPendingRedirect && (_user.value == null || _user.value!.isAnonymous)) {
        box.remove('auth_pending_redirect');
        box.remove('auth_pending_redirect_time');
        _isInitialAuthRestorationPending = false;
        _handleAuthChanged(null);
      }
    }

    // Re-verify after async initialization in case auth resolved during async awaits
    final current = _auth.currentUser;
    if (current != null && !current.isAnonymous) {
      _isInitialAuthRestorationPending = false;
      _handleAuthChanged(current);
    } else if (kIsWeb && _isInitialAuthRestorationPending) {
      // IndexedDB reading on Web / Keystore retrieval on Mobile is asynchronous.
      // Poll currentUser or wait up to 1.2 seconds for Firebase Auth to finish hydrating user credentials.
      const pollInterval = Duration(milliseconds: 150);
      const maxAttempts = 8; // 8 * 150ms = 1.2 seconds max
      for (var i = 0; i < maxAttempts; i++) {
        if (!_isInitialAuthRestorationPending) {
          // Resolved concurrently by authStateChanges stream listener!
          break;
        }
        final liveUser = _auth.currentUser;
        if (liveUser != null && !liveUser.isAnonymous) {
          _isInitialAuthRestorationPending = false;
          _handleAuthChanged(liveUser);
          break;
        }
        await Future<void>.delayed(pollInterval);
      }

      // If still pending after the grace period, check one last time before concluding
      // genuine unauthenticated state:
      if (_isInitialAuthRestorationPending) {
        final finalUser = _auth.currentUser;
        _isInitialAuthRestorationPending = false;
        if (finalUser != null && !finalUser.isAnonymous) {
          _handleAuthChanged(finalUser);
        } else {
          debugPrint(
            'AuthService: Verified unauthenticated state after IndexedDB hydration timeout; clearing session.',
          );
          _handleAuthChanged(null);
        }
      }
    }

    // Purge any lingering anonymous session
    try {
      if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
        await _auth.signOut().timeout(const Duration(seconds: 4), onTimeout: () {});
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.purgeAnonymousUser');
    }

    return this;
  }

  bool _isTestOverride = false;

  void _handleAuthChanged(User? u) {
    if (_isTestOverride) return;
    if (u != null && u.isAnonymous) {
      _isInitialAuthRestorationPending = false;
      _lastHandledUid = null;
      _cachedUid = null;
      _user.value = null;
      _isAuthenticated.value = false;
      final box = GetStorage();
      box.write('auth_has_active_session', false);
      box.remove('auth_session_uid');
      _channelManager.clearUserChannel();
      _channelManager.updateChannelSubscription(null);
      UserSessionResetManager.resetAllUserSessions();
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
    final newUid = isRealUser ? u.uid : null;

    final box = GetStorage();
    if (isRealUser) {
      _isInitialAuthRestorationPending = false;
      _user.value = u;
      _isAuthenticated.value = true;
      _cachedUid = u.uid;
      box.write('auth_has_active_session', true);
      box.write('auth_session_uid', u.uid);
      if (u.email != null && u.email!.isNotEmpty) {
        _profileManager.userEmail.value = u.email;
        box.write('profile_email_${u.uid}', u.email);
      }
      if (u.displayName != null && u.displayName!.isNotEmpty) {
        _profileManager.userDisplayName.value = u.displayName;
        box.write('profile_name_${u.uid}', u.displayName);
      }
      if (u.photoURL != null && u.photoURL!.isNotEmpty) {
        _profileManager.userPhotoUrl.value = u.photoURL;
        box.write('profile_photo_${u.uid}', u.photoURL);
      }
    } else {
      if (kIsWeb && _isInitialAuthRestorationPending) {
        debugPrint(
          'AuthService: Initial auth restoration in progress; preserving cached session.',
        );
        return;
      }
      _user.value = null;
      _isAuthenticated.value = false;
      _cachedUid = null;
      box.write('auth_has_active_session', false);
      box.remove('auth_session_uid');
      _channelManager.clearUserChannel();
      UserSessionResetManager.resetAllUserSessions();
    }

    if (_lastHandledUid == newUid && isRealUser) {
      return;
    }

    if (_lastHandledUid != null && _lastHandledUid != newUid) {
      _channelManager.clearUserChannel();
      _profileManager.clearProfile();
      UserSessionResetManager.resetAllUserSessions();
    }
    _lastHandledUid = newUid;

    if (isRealUser) {
      _channelManager.initCachedChannelStatus(u.uid);
      _profileManager.initCachedProfile(u.uid);
    }

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
              if (AppFlavor.isStudio) return;
              if (kIsWeb) {
                final host = Uri.base.host.toLowerCase();
                if (host.startsWith('studio') || host.contains('studio.truthworld.in')) {
                  return;
                }
              }
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
    _authStateSub?.cancel();
    _channelManager.dispose();
    _profileManager.dispose();
    super.onClose();
  }

  Future<String?>? _inFlightTokenRefresh;

  /// Force-refreshes the Firebase Auth ID token and custom claims with single-flight request coalescing.
  Future<String?> forceRefreshToken() async {
    if (_inFlightTokenRefresh != null) {
      return _inFlightTokenRefresh;
    }

    final completer = Completer<String?>();
    _inFlightTokenRefresh = completer.future;

    try {
      final token = await _auth.currentUser?.getIdToken(true);
      logger.info(
        'Firebase Auth token & custom claims force-refreshed successfully',
        tag: 'Auth',
      );
      completer.complete(token);
      return token;
    } catch (e) {
      logger.warning(
        'Failed to force-refresh Firebase Auth token: $e',
        tag: 'Auth',
      );
      completer.complete(null);
      return null;
    } finally {
      _inFlightTokenRefresh = null;
    }
  }

  Future<void> _handlePostSignIn(
    User u, {
    Map<String, dynamic>? lastGooglePeopleData,
    bool isNewUser = false,
  }) async {
    _user.value = u;
    _isAuthenticated.value = true;
    _cachedUid = u.uid;
    final box = GetStorage();
    box.write('auth_has_active_session', true);
    box.write('auth_session_uid', u.uid);
    if (u.email != null && u.email!.isNotEmpty) {
      _profileManager.userEmail.value = u.email;
      box.write('profile_email_${u.uid}', u.email);
    }
    if (u.displayName != null && u.displayName!.isNotEmpty) {
      _profileManager.userDisplayName.value = u.displayName;
      box.write('profile_name_${u.uid}', u.displayName);
    }
    if (u.photoURL != null && u.photoURL!.isNotEmpty) {
      _profileManager.userPhotoUrl.value = u.photoURL;
      box.write('profile_photo_${u.uid}', u.photoURL);
    }

    // Flag needsOnboarding immediately for new users to eliminate modal latency
    // and launch the onboarding flow in under 50ms without waiting for background sync.
    final hasCompletedOnboarding = box.read('profile_completed_${u.uid}') == true;
    final isBrandNew = isNewUser || (!hasCompletedOnboarding && _isNewUserHeuristic(u));

    if (isBrandNew && !hasCompletedOnboarding) {
      needsOnboarding.value = true;
    }

    // Execute post-sign-in synchronization tasks asynchronously in the background.
    // This guarantees sub-millisecond return latency so the modal closes instantly
    // and the onboarding site opens immediately.
    unawaited(
      Future.wait([
        _firestoreSync.syncUserToFirestore(
          u,
          lastGooglePeopleData: lastGooglePeopleData,
          onNeedsOnboardingChanged: (val) => needsOnboarding.value = val,
        ).timeout(
          const Duration(seconds: 6),
          onTimeout: () => debugPrint('AuthService: syncUserToFirestore timed out gracefully.'),
        ).catchError((e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s is StackTrace ? s : null,
            tag: 'AuthService._handlePostSignIn.syncUser',
          );
        }),
        ensureChannelLoaded().timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            debugPrint('AuthService: ensureChannelLoaded timed out gracefully.');
            return null;
          },
        ).catchError((e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s is StackTrace ? s : null,
            tag: 'AuthService._handlePostSignIn.ensureChannel',
          );
          return null;
        }),
        PushNotificationService.to.registerToken(u.uid).catchError((e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s is StackTrace ? s : null,
            tag: 'AuthService._handlePostSignIn.push',
          );
        }),
      ]),
    );
  }

  /// Initiates sign-in using Google provider.
  Future<UserCredential> signInWithGoogle() async {
    final credential = await _googleProvider.signInWithGoogle(_auth);
    final u = credential.user;
    if (u != null) {
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? _isNewUserHeuristic(u);
      await _handlePostSignIn(
        u,
        lastGooglePeopleData: _googleProvider.lastGooglePeopleData,
        isNewUser: isNewUser,
      );
    }
    return credential;
  }

  /// Retries Google Sign-In with exponential backoff.
  Future<UserCredential> retryGoogleSignIn({int maxRetries = 2}) =>
      _googleProvider.retryGoogleSignIn(_auth, maxRetries: maxRetries);

  /// Initiates sign-in using Apple provider across iOS, macOS, Android, and Web.
  Future<UserCredential> signInWithApple() async {
    final credential = await _appleProvider.signInWithApple(_auth);
    final u = credential.user;
    if (u != null) {
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? _isNewUserHeuristic(u);
      await _handlePostSignIn(u, isNewUser: isNewUser);
    }
    return credential;
  }

  /// Returns whether the target platform is an Apple platform (iOS, macOS).
  /// On Web (`kIsWeb`), Google Sign-In is used as the exclusive authentication provider.
  static bool isApplePlatform([TargetPlatform? platform, bool? isWeb]) {
    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb && platform == null) return false;
    final target = platform ?? defaultTargetPlatform;
    return target == TargetPlatform.iOS || target == TargetPlatform.macOS;
  }

  /// Returns whether the target platform is Android.
  static bool isAndroidPlatform([TargetPlatform? platform, bool? isWeb]) {
    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb && platform == null) return false;
    final target = platform ?? defaultTargetPlatform;
    return target == TargetPlatform.android;
  }

  /// Returns whether the target platform is Web.
  static bool isWebPlatform([bool? isWeb]) {
    return isWeb ?? kIsWeb;
  }

  /// Initiates sign-in directly across all apps.
  static Future<void> prompt([BuildContext? context]) async {
    final auth = Get.isRegistered<AuthService>()
        ? AuthService.to
        : Get.put(AuthService());
    await auth.triggerPlatformSignIn();
  }

  /// Triggers platform sign-in directly (Google on Android/Web, Apple on native iOS/macOS).
  Future<UserCredential?> triggerPlatformSignIn({
    TargetPlatform? platformOverride,
    bool? isWebOverride,
  }) async {
    final isApple = isApplePlatform(platformOverride, isWebOverride);

    try {
      final credential = isApple
          ? await signInWithApple()
          : await signInWithGoogle();
      return credential;
    } on GoogleSignInException catch (e) {
      if (e.code == 'redirecting') return null;
      if (e.code == 'user-cancelled' ||
          e.code == 'popup-closed' ||
          e.code == 'popup-closed-by-user') {
        return null;
      }
      AppSnackbar.error(e.displayMessage);
      return null;
    } on AppleSignInException catch (e) {
      if (e.code == 'redirecting') return null;
      if (e.code == 'user-cancelled') return null;
      AppSnackbar.error(e.displayMessage);
      return null;
    } catch (e, st) {
      ErrorHandler.log(e, stackTrace: st, tag: 'AuthService.triggerPlatformSignIn');
      AppSnackbar.error('Unable to complete sign-in. Please try again.');
      return null;
    } finally {
      if (isAuthenticated.value && (needsOnboarding.value || hasPendingOnboardingPrompt)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          checkAndPromptOnboarding();
        });
      }
    }
  }

  /// Initiates phone number verification by sending an SMS OTP.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(PhoneAuthException error) onVerificationFailed,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _phoneProvider.verifyPhoneNumber(
      auth: _auth,
      phoneNumber: phoneNumber,
      resendToken: resendToken,
      onCodeSent: onCodeSent,
      onVerificationCompleted: (cred) async {
        try {
          final userCredential = await _auth.signInWithCredential(cred);
          final u = userCredential.user;
          if (u != null) {
            final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? _isNewUserHeuristic(u);
            await _handlePostSignIn(u, isNewUser: isNewUser);
          }
          onVerificationCompleted(cred);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AuthService.verifyPhoneNumber.autoSignIn',
          );
        }
      },
      onVerificationFailed: onVerificationFailed,
      onCodeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  /// Completes Phone Sign-In using the SMS OTP code and verification ID.
  Future<UserCredential> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
    ConfirmationResult? confirmationResult,
  }) async {
    final credential = await _phoneProvider.signInWithOtp(
      auth: _auth,
      verificationId: verificationId,
      smsCode: smsCode,
      webConfirmation: confirmationResult,
    );
    final u = credential.user;
    if (u != null) {
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? _isNewUserHeuristic(u);
      await _handlePostSignIn(u, isNewUser: isNewUser);
    }
    return credential;
  }

  /// Links a phone number to the current account.
  /// If another account already holds this phone number, securely merges the duplicate
  /// account into the current account and deletes the duplicate account from Firebase Auth and Firestore.
  Future<void> linkPhoneNumber({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AuthException(
        message: 'No authenticated user session found.',
        userMessage: 'Please sign in to verify your phone number.',
        code: 'AUTH_UNAUTHENTICATED',
      );
    }

    final trimmedCode = smsCode.trim();
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: trimmedCode,
    );
    final normalizedPhone =
        AuthPhoneSignInProvider.normalizePhoneNumber(phoneNumber);

    try {
      await currentUser.linkWithCredential(credential);
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .set({
        'phoneNumber': normalizedPhone,
        'isPhoneVerified': true,
        'metadata': {
          'phoneNumber': normalizedPhone,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await currentUser.reload();
      _user.value = _auth.currentUser;
      await syncCurrentUser();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw const PhoneAuthException(
          message: 'This phone number is already linked to another account.',
          userMessage:
              'This phone number is already linked to another account. Please use a different phone number.',
          code: 'credential-already-in-use',
        );
      }
      rethrow;
    }
  }

  /// Links Google email to the current account.
  /// If another account already holds this Google account, securely merges the duplicate
  /// account into the current account and deletes the duplicate account from Firebase Auth and Firestore.
  Future<void> linkGoogleEmail() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AuthException(
        message: 'No authenticated user session found.',
        userMessage: 'Please sign in to verify your email.',
        code: 'AUTH_UNAUTHENTICATED',
      );
    }

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        try {
          await currentUser.linkWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            throw const GoogleSignInException(
              message:
                  'This Google account is already linked to another TruthWorld user.',
              code: 'credential-already-in-use',
            );
          } else {
            rethrow;
          }
        }
      } else {
        final credential = await _googleProvider.getGoogleAuthCredential();
        final email = _googleProvider.lastGoogleEmail;
        try {
          await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            throw const GoogleSignInException(
              message:
                  'This Google account is already linked to another TruthWorld user.',
              code: 'credential-already-in-use',
            );
          } else {
            rethrow;
          }
        }
      }

      await currentUser.reload();
      _user.value = _auth.currentUser;
      await syncCurrentUser();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.linkGoogleEmail');
      rethrow;
    }
  }

  /// Sends a verification email to the user or verifies before updating email.
  Future<void> sendEmailVerification({String? email}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AuthException(
        message: 'No authenticated user session found.',
        userMessage: 'Please sign in to verify your email.',
        code: 'AUTH_UNAUTHENTICATED',
      );
    }

    final trimmedEmail = email?.trim();
    if (trimmedEmail != null &&
        trimmedEmail.isNotEmpty &&
        currentUser.email != trimmedEmail) {
      try {
        await currentUser.verifyBeforeUpdateEmail(trimmedEmail);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw const AuthException(
            message: 'This email is already in use by another account.',
            userMessage:
                'This email is already in use by another account. Please use a different email address.',
            code: 'email-already-in-use',
          );
        } else {
          rethrow;
        }
      }
    } else {
      await currentUser.sendEmailVerification();
    }
  }

  /// Reloads the Firebase user and updates verification status in Firestore.
  Future<bool> reloadAndCheckEmailVerified() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    await currentUser.reload();
    _user.value = _auth.currentUser;
    final isVerified = _auth.currentUser?.emailVerified ?? false;
    if (isVerified) {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .set({
        'email': _auth.currentUser?.email,
        'isEmailVerified': true,
        'emailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await syncCurrentUser();
    }
    return isVerified;
  }

  /// Synchronizes active Firebase User data and profile state to Firestore.
  Future<void> syncCurrentUser() async {
    final u = _auth.currentUser;
    if (u != null) {
      await _firestoreSync.syncUserToFirestore(
        u,
        onNeedsOnboardingChanged: (needs) => needsOnboarding.value = needs,
      );
    }
  }

  /// Signs out user and unregisters push notification device token.
  Future<void> signOut() async {
    try {
      if (Get.isRegistered<PushNotificationService>()) {
        final uidSnapshot = uid;
        if (uidSnapshot.isNotEmpty) {
          await PushNotificationService.to.unregisterToken(uidSnapshot);
        }
      }
      if (Get.isRegistered<AdService>()) {
        await AdService.to.clearUserInteractions();
      }
      if (Get.isRegistered<WatchHistoryService>()) {
        await WatchHistoryService.to.clearHistorySubscriptions();
      }
      _profileManager.dispose();
      _channelManager.dispose();
      await _googleProvider.signOut();
      await _auth.signOut();
    } catch (e) {
      logger.warning('Error during sign out: $e', tag: 'AUTH');
    } finally {
      _isInitialAuthRestorationPending = false;
      final box = GetStorage();
      box.write('auth_has_active_session', false);
      box.remove('auth_session_uid');
      box.remove('auth_pending_redirect');
      box.remove('auth_pending_redirect_time');
      _cachedUid = null;
      _lastHandledUid = null;
      _user.value = null;
      _isAuthenticated.value = false;
      needsOnboarding.value = false;
      _profileManager.clearProfile();
      _channelManager.clearUserChannel();
      UserSessionResetManager.resetAllUserSessions();
    }
  }

  Future<void> logout() => signOut();

  /// Returns the primary auth provider ID for the current signed-in user ('google.com', 'password', etc.)
  String get primaryAuthProvider {
    final u = _auth.currentUser;
    if (u == null || u.providerData.isEmpty) return 'none';
    return u.providerData.first.providerId;
  }

  /// Re-authenticates the current user against their active authentication provider
  /// to refresh the authentication token before sensitive operations (e.g. account deletion).
  Future<UserCredential?> reauthenticate({
    String? password,
    PhoneAuthCredential? phoneCredential,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AuthException(
        message: 'No authenticated user session found.',
        userMessage: 'Please sign in to proceed.',
        code: 'AUTH_UNAUTHENTICATED',
      );
    }

    final providers =
        currentUser.providerData.map((p) => p.providerId).toList();

    if (providers.contains('google.com')) {
      return _googleProvider.reauthenticateWithGoogle(currentUser);
    } else if (providers.contains('password')) {
      if (password == null || password.trim().isEmpty) {
        throw const AuthException(
          message: 'Password required for re-authentication.',
          userMessage:
              'Please enter your account password to verify your identity.',
          code: 'AUTH_REQUIRES_PASSWORD',
        );
      }
      final email = currentUser.email ?? '';
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password.trim(),
      );
      return currentUser.reauthenticateWithCredential(cred);
    } else if (providers.contains('apple.com')) {
      return _appleProvider.reauthenticateWithApple(currentUser);
    } else if (providers.contains('phone')) {
      if (phoneCredential != null) {
        return currentUser.reauthenticateWithCredential(phoneCredential);
      }
      return null;
    } else {
      // Fallback: try Google reauth if supported
      try {
        return await _googleProvider.reauthenticateWithGoogle(currentUser);
      } catch (e) {
        logger.warning('Re-authentication fallback failed: $e', tag: 'AUTH');
        return null;
      }
    }
  }

  /// Deactivates user account: marks status as 'deactivated' in Firestore and signs out.
  Future<void> deactivateAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final uidToDeactivate = currentUser.uid;
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uidToDeactivate)
          .set({
            'status': 'deactivated',
            'deactivatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await signOut();
    }
  }

  /// Permanently deletes user profile, marks associated channel as deleted,
  /// and deletes Firebase Auth user. Automatically handles re-authentication.
  Future<void> deleteAccount({String? password}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final uidToDelete = currentUser.uid;

    // Step 1: Re-authenticate to ensure fresh authentication token for sensitive deletion
    if (!currentUser.isAnonymous) {
      await reauthenticate(password: password);
    }

    // Step 2: Clean up Firestore documents while still authenticated
    await _firestoreSync.deleteAccountData(uidToDelete);

    // Step 3: Delete Firebase Auth user record
    try {
      await currentUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Retry reauth in case token expired during cleanup
        await reauthenticate(password: password);
        await currentUser.delete();
      } else {
        rethrow;
      }
    }

    _user.value = null;
    _isAuthenticated.value = false;
    needsOnboarding.value = false;
  }

  /// Sets authentication state in unit tests without invoking native Firebase Auth.
  @visibleForTesting
  void setAuthenticatedForTesting({required bool isAuthenticated, String? uid}) {
    _isTestOverride = true;
    _isAuthenticated.value = isAuthenticated;
    _cachedUid = uid;
  }
}
