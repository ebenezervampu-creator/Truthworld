import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleSignInException;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/google_onboarding_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/google_signin_exception_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/user_model.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();
  FirebaseAuth? _authOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  set _auth(FirebaseAuth val) => _authOverride = val;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final Rxn<User> _user = Rxn<User>();
  Rxn<User> get currentUser => _user;

  User? get user => _user.value;

  final RxBool _isAuthenticated = false.obs;
  RxBool get isAuthenticated => _isAuthenticated;
  bool get isUserSignedIn => _isAuthenticated.value;

  String get uid => (_isAuthenticated.value && _user.value != null && !_user.value!.isAnonymous)
      ? _user.value!.uid
      : '';

  final RxBool _hasChannel = false.obs;
  RxBool get hasChannel => _hasChannel;

  final Rxn<Channel> _userChannel = Rxn<Channel>();
  Channel? get userChannel => _userChannel.value;
  Rxn<Channel> get rxUserChannel => _userChannel;

  void setUserChannel(Channel? channel) {
    _userChannel.value = channel;
    _hasChannel.value = channel != null && channel.status != ChannelStatus.deleted;
    final uid = _user.value?.uid;
    if (uid != null) {
      GetStorage().write('hasChannel_$uid', _hasChannel.value);
    }
  }

  void clearUserChannel() {
    _userChannel.value = null;
    _hasChannel.value = false;
    final uid = _user.value?.uid;
    if (uid != null) {
      GetStorage().write('hasChannel_$uid', false);
    }
  }

  /// Asynchronously guarantees that the user's channel is resolved from Firestore.
  /// Checks ownerId, userId, userDoc channelId, and email fallback.
  Future<Channel?> ensureChannelLoaded() async {
    if (_hasChannel.value && _userChannel.value != null) {
      return _userChannel.value;
    }
    var u = _user.value;
    if (u == null) {
      try {
        u = _auth.currentUser;
      } catch (_) {
        u = null;
      }
    }
    if (u == null || u.isAnonymous) return null;

    try {
      // 1. Direct check by ownerId
      var snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .where('ownerId', isEqualTo: u.uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // 2. Direct check by userId
        snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('userId', isEqualTo: u.uid)
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final activeChannels = snap.docs
            .map(Channel.fromDocumentSnapshot)
            .where((c) => c.status != ChannelStatus.deleted)
            .toList();
        if (activeChannels.isNotEmpty) {
          final ch = activeChannels.first;
          setUserChannel(ch);
          return ch;
        }
      }

      // 3. Direct check user doc for channelId
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(u.uid)
          .get();
      final chId = userDoc.data()?['channelId'] as String?;
      if (chId != null && chId.isNotEmpty) {
        final chDoc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(chId)
            .get();
        if (chDoc.exists && chDoc.data() != null) {
          final ch = Channel.fromDocumentSnapshot(chDoc);
          if (ch.status != ChannelStatus.deleted) {
            setUserChannel(ch);
            return ch;
          }
        }
      }

      // 4. Direct check by email if available
      if (u.email != null && u.email!.isNotEmpty) {
        final emailSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('email', isEqualTo: u.email)
            .limit(1)
            .get();
        final emailChannels = emailSnap.docs
            .map(Channel.fromDocumentSnapshot)
            .where((c) => c.status != ChannelStatus.deleted)
            .toList();
        if (emailChannels.isNotEmpty) {
          final ch = emailChannels.first;
          setUserChannel(ch);
          return ch;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.ensureChannelLoaded');
    }
    return _userChannel.value;
  }

  StreamSubscription? _channelSubscription;
  final RxBool isPremiumUser = false.obs;
  final RxnString premiumPlanId = RxnString();
  final RxnInt premiumStartedAt = RxnInt();
  final RxnInt premiumExpiresAt = RxnInt();

  bool get isTrialExpired {
    final exp = premiumExpiresAt.value;
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch > exp;
  }

  /// Whether user is specifically subscribed to the Audio Premium tier (₹40/mo)
  bool get isAudioPremiumOnly =>
      isPremiumUser.value && premiumPlanId.value == 'audio_monthly';

  /// Whether user is subscribed to full TruthWorld Premium ($2/mo or higher)
  bool get hasFullPremium =>
      isPremiumUser.value && premiumPlanId.value != 'audio_monthly';

  /// Whether user has the $3 tier including on-demand & every video fact-checking
  bool get hasFactCheckPremium =>
      isPremiumUser.value &&
      (premiumPlanId.value == '4k_factchecked_monthly' ||
          premiumPlanId.value == 'factcheck_monthly');

  void checkTrialExpiry() {
    final exp = premiumExpiresAt.value;
    if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
      if (isPremiumUser.value) {
        isPremiumUser.value = false;
        try {
          final box = GetStorage();
          box.write('isPremiumUser', false);
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.checkTrialExpiry');
        }
      }
    }
  }

  String get formattedStartedDate {
    final start = premiumStartedAt.value;
    if (start == null) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(start);
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  String get formattedExpiresDate {
    final exp = premiumExpiresAt.value;
    if (exp == null) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(exp);
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  String get formattedRemainingTime {
    final exp = premiumExpiresAt.value;
    if (exp == null) return 'N/A';
    final diff = DateTime.fromMillisecondsSinceEpoch(exp).difference(
      DateTime.now(),
    );
    if (diff.isNegative) return 'Trial Expired';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (days > 0) {
      return '$days days, $hours hrs remaining';
    } else if (hours > 0) {
      return '$hours hrs, $mins mins remaining';
    } else {
      return '${diff.inMinutes} mins remaining';
    }
  }
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
  final RxBool needsOnboarding = false.obs;
  Map<String, dynamic>? _lastGooglePeopleData;
  StreamSubscription? _userDocSubscription;

  String get activeDisplayName {
    if (userDisplayName.value != null && userDisplayName.value!.trim().isNotEmpty) {
      return userDisplayName.value!.trim();
    }
    if (hasChannel.value && userChannel != null && userChannel!.name.isNotEmpty) {
      return userChannel!.name;
    }
    if (user != null && !user!.isAnonymous && user!.displayName?.isNotEmpty == true) {
      return user!.displayName!;
    }
    return 'User';
  }

  String get activePhotoUrl {
    if (userPhotoUrl.value != null && userPhotoUrl.value!.isNotEmpty) {
      return userPhotoUrl.value!;
    }
    if (hasChannel.value && userChannel != null && userChannel!.avatarUrl.isNotEmpty) {
      return userChannel!.avatarUrl;
    }
    if (user != null && !user!.isAnonymous && user!.photoURL?.isNotEmpty == true) {
      return user!.photoURL!;
    }
    return '';
  }

  String get activeHandle {
    if (userHandle.value != null && userHandle.value!.trim().isNotEmpty) {
      final handle = userHandle.value!.trim();
      return handle.startsWith('@') ? handle : '@$handle';
    }
    if (hasChannel.value && userChannel != null && userChannel!.handle.isNotEmpty) {
      final handle = userChannel!.handle;
      return handle.startsWith('@') ? handle : '@$handle';
    }
    final email = user?.email ?? '';
    if (user != null && !user!.isAnonymous && email.isNotEmpty) {
      return "@${email.split('@')[0]}";
    }
    return '@user';
  }

  String get activeBio {
    if (userBio.value != null && userBio.value!.isNotEmpty) {
      return userBio.value!;
    }
    if (hasChannel.value && userChannel != null && userChannel!.description.isNotEmpty) {
      return userChannel!.description;
    }
    return '';
  }

  /// ✅ SAFE async initialization (no Firebase calls before this)
  Future<AuthService> init() async {
    _auth = FirebaseAuth.instance;

    // Load locally cached Premium status synchronously so page refresh never resets state
    try {
      final box = GetStorage();
      final savedIsPremium = box.read('isPremiumUser') as bool? ?? false;
      final savedPlanId = box.read('premiumPlanId') as String?;
      final savedStartedAt = box.read('premiumStartedAt') as int?;
      final savedExpiresAt = box.read('premiumExpiresAt') as int?;

      premiumStartedAt.value = savedStartedAt;
      premiumExpiresAt.value = savedExpiresAt;

      if (savedExpiresAt != null &&
          DateTime.now().millisecondsSinceEpoch > savedExpiresAt) {
        isPremiumUser.value = false;
        premiumPlanId.value = savedPlanId;
        box.write('isPremiumUser', false);
      } else {
        isPremiumUser.value = savedIsPremium;
        premiumPlanId.value = savedPlanId;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.loadCachedPremiumStatus');
    }

    // Load locally cached Channel status synchronously
    try {
      final box = GetStorage();
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        final savedHasChannel = box.read('hasChannel_$currentUid') as bool?;
        if (savedHasChannel != null) {
          _hasChannel.value = savedHasChannel;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.loadCachedChannelStatus');
    }

    // Google Sign-In v7 requires explicit initialization
    try {
      if (kIsWeb) {
        // On Web, GoogleSignIn requires a clientId (via meta tag or parameter).
        // Since we use FirebaseAuth.signInWithPopup for Web auth, we can skip
        // explicit plugin initialization to avoid the "ClientID not set" assertion.
        debugPrint(
          'AuthService: Web platform detected. Skipping explicit GoogleSignIn initialization.',
        );
      } else {
        await _googleSignIn.initialize(
          serverClientId:
              '768266102263-f1bou7fgaqn2rkqh0cn5p6voksb163qt.apps.googleusercontent.com',
        );
      }
    } catch (e, s) {
      // On some platforms, this might not be implemented or handled automatically.
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.googleSignInInitialize');
    }

    // Purge any lingering anonymous session so guests are never treated as having an account
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
      // Unsigned guests must not hold an anonymous user session
      _isAuthenticated.value = false;
      _updateChannelSubscription(null);
      _updateUserDocSubscription(null);
      needsOnboarding.value = false;
      _auth.signOut().catchError((e) {
        debugPrint('AuthService: signOut anonymous error: $e');
      });
      return;
    }

    final isRealUser = u != null && !u.isAnonymous;
    _isAuthenticated.value = isRealUser;
    _updateChannelSubscription(isRealUser ? u : null);
    _updateUserDocSubscription(isRealUser ? u : null);
    if (isRealUser) {
      _syncUserToFirestore(u).then((_) {
        PushNotificationService.to.registerToken(u.uid);
      });
    } else {
      needsOnboarding.value = false;
    }
  }

  void _updateChannelSubscription(User? user) {
    _channelSubscription?.cancel();

    if (user == null) {
      _hasChannel.value = false;
      _userChannel.value = null;
      return;
    }

    _channelSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.channels)
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) async {
            final activeChannels = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();

            if (activeChannels.isNotEmpty) {
              _hasChannel.value = true;
              _userChannel.value = activeChannels.first;
              GetStorage().write('hasChannel_${user.uid}', true);
              return;
            }

            // Fallback 1: Check by userId if ownerId returned nothing
            try {
              final userSnap = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .where('userId', isEqualTo: user.uid)
                  .get();
              final userChannels = userSnap.docs
                  .map(Channel.fromDocumentSnapshot)
                  .where((c) => c.status != ChannelStatus.deleted)
                  .toList();
              if (userChannels.isNotEmpty) {
                _hasChannel.value = true;
                _userChannel.value = userChannels.first;
                GetStorage().write('hasChannel_${user.uid}', true);
                return;
              }
            } catch (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.fallbackChannelByUserId');
            }

            // Fallback 2: Check user document for channelId reference
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.users)
                  .doc(user.uid)
                  .get();
              final chId = userDoc.data()?['channelId'] as String?;
              if (chId != null && chId.isNotEmpty) {
                final chDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(chId)
                  .get();
                if (chDoc.exists && chDoc.data() != null) {
                  final ch = Channel.fromDocumentSnapshot(chDoc);
                  if (ch.status != ChannelStatus.deleted) {
                    _hasChannel.value = true;
                    _userChannel.value = ch;
                    GetStorage().write('hasChannel_${user.uid}', true);
                    return;
                  }
                }
              }
            } catch (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.fallbackChannelByUserDoc');
            }

            // Fallback 3: Check channels by email to ensure channel is never lost
            if (user.email != null && user.email!.isNotEmpty) {
              try {
                final emailSnap = await FirebaseFirestore.instance
                    .collection(FirestoreCollections.channels)
                    .where('email', isEqualTo: user.email)
                    .get();
                final emailChannels = emailSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((c) => c.status != ChannelStatus.deleted)
                    .toList();
                if (emailChannels.isNotEmpty) {
                  final ch = emailChannels.first;
                  _hasChannel.value = true;
                  _userChannel.value = ch;
                  GetStorage().write('hasChannel_${user.uid}', true);
                  // Update channel ownerId and userId to current active uid
                  try {
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.channels)
                        .doc(ch.id)
                        .update({
                      'ownerId': user.uid,
                      'userId': user.uid,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  } catch (e, s) {
                    ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.updateChannelOwner');
                  }
                  return;
                }
              } catch (e, s) {
                ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.fallbackChannelByEmail');
              }
            }

            _hasChannel.value = false;
            _userChannel.value = null;
            GetStorage().write('hasChannel_${user.uid}', false);
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(error, stackTrace: stackTrace, tag: 'AuthService.channelSubscription');
          },
        );
  }

  void _updateUserDocSubscription(User? user) {
    _userDocSubscription?.cancel();
    final box = GetStorage();
    final cachedIsPremium = box.read('isPremiumUser') as bool? ?? false;
    final cachedPlanId = box.read('premiumPlanId') as String?;
    final cachedStartedAt = box.read('premiumStartedAt') as int?;
    final cachedExpiresAt = box.read('premiumExpiresAt') as int?;

    if (user == null) {
      premiumStartedAt.value = cachedStartedAt;
      premiumExpiresAt.value = cachedExpiresAt;

      if (cachedExpiresAt != null &&
          DateTime.now().millisecondsSinceEpoch > cachedExpiresAt) {
        isPremiumUser.value = false;
        premiumPlanId.value = cachedPlanId;
      } else {
        isPremiumUser.value = cachedIsPremium;
        premiumPlanId.value = cachedPlanId;
      }

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
      needsOnboarding.value = false;
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
              final startAt = (data['premiumStartedAt'] as num?)?.toInt() ?? cachedStartedAt;
              final expAt = (data['premiumExpiresAt'] as num?)?.toInt() ?? cachedExpiresAt;

              premiumStartedAt.value = startAt;
              premiumExpiresAt.value = expAt;

              if (startAt != null) box.write('premiumStartedAt', startAt);
              if (expAt != null) box.write('premiumExpiresAt', expAt);

              final isExpired = expAt != null && DateTime.now().millisecondsSinceEpoch > expAt;

              if (data.containsKey('isPremium')) {
                final isPrem = data['isPremium'] as bool? ?? false;
                final planId = data['premiumPlanId'] as String?;
                final oldIsPremium = isPremiumUser.value;

                if (isExpired) {
                  isPremiumUser.value = false;
                  premiumPlanId.value = planId ?? cachedPlanId;
                  box.write('isPremiumUser', false);
                } else {
                  isPremiumUser.value = isPrem;
                  premiumPlanId.value = planId;
                  box.write('isPremiumUser', isPrem);
                }

                if (oldIsPremium != isPremiumUser.value) {
                  unawaited(forceRefreshToken());
                }

                if (planId != null) {
                  box.write('premiumPlanId', planId);
                } else {
                  box.remove('premiumPlanId');
                }
              } else {
                if (isExpired) {
                  isPremiumUser.value = false;
                } else {
                  isPremiumUser.value = cachedIsPremium;
                }
                premiumPlanId.value = cachedPlanId;
              }
              userDisplayName.value = (data['displayName'] as String?) ?? (data['name'] as String?);
              userHandle.value = data['handle'] as String?;
              userBio.value = data['bio'] as String?;
              userPhotoUrl.value = (data['photoURL'] as String?) ?? (data['photoUrl'] as String?) ?? (data['avatarUrl'] as String?);
              userAvatarStatus.value = data['avatarStatus'] as String?;
              userAvatarStatusReason.value = data['avatarStatusReason'] as String?;
              userAvatarFileId.value = data['avatarFileId'] as String?;
              userGender.value = data['gender'] as String?;
              userAge.value = (data['age'] as num?)?.toInt();
              userAgeGroup.value = data['ageGroup'] as String?;
              userBirthdate.value = data['birthdate'] as String?;
              userLocation.value = data['location'] as String?;
              userCity.value = data['city'] as String?;
              userState.value = data['state'] as String?;
              userCountry.value = data['country'] as String?;

              final hasCompletedOnboarding =
                  data['hasCompletedOnboarding'] as bool? ??
                  (data['birthdate'] != null &&
                      data['birthdate'].toString().isNotEmpty);
              needsOnboarding.value = !hasCompletedOnboarding;
            } else {
              isPremiumUser.value = cachedIsPremium;
              premiumPlanId.value = cachedPlanId;
              premiumStartedAt.value = cachedStartedAt;
              premiumExpiresAt.value = cachedExpiresAt;
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
              needsOnboarding.value = false;
            }
          },
          onError: (e, stackTrace) {
            ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AuthService.userDocSubscription');
          },
        );
  }

  @override
  void onClose() {
    _channelSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.onClose();
  }

  /// Force-refreshes the Firebase Auth ID token and custom claims (for billing/premium updates)
  Future<String?> forceRefreshToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken(true);
      logger.info('Firebase Auth token & custom claims force-refreshed successfully', tag: 'Auth');
      return token;
    } catch (e) {
      logger.warning('Failed to force-refresh Firebase Auth token: $e', tag: 'Auth');
      return null;
    }
  }

  Future<void> cancelPremiumSubscription() async {
    isPremiumUser.value = false;
    premiumPlanId.value = null;
    premiumStartedAt.value = null;
    premiumExpiresAt.value = null;

    final box = GetStorage();
    box.write('isPremiumUser', false);
    box.remove('premiumPlanId');
    box.remove('premiumStartedAt');
    box.remove('premiumExpiresAt');

    final u = _user.value;
    if (u == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(u.uid)
          .update({
            'isPremium': false,
            'premiumPlanId': FieldValue.delete(),
            'premiumStartedAt': FieldValue.delete(),
            'premiumExpiresAt': FieldValue.delete(),
          });
      // Force refresh claims on billing cancellation
      await forceRefreshToken();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.cancelPremiumSubscription');
    }
  }

  // ================= GOOGLE SIGN IN =================

  Future<UserCredential> signInWithGoogle() async {
    try {
      final credential = kIsWeb
          ? await _signInWithGoogleWeb()
          : await _signInWithGoogleMobile();

      final u = credential.user;
      if (u != null) {
        _user.value = u;
        _isAuthenticated.value = true;
        await _syncUserToFirestore(u);
        PushNotificationService.to.registerToken(u.uid);
      }

      return credential;
    } catch (e, st) {
      final mapped = GoogleSignInExceptionHandler.from(e);
      if (mapped.code == 'user-cancelled') {
        if (kDebugMode) {
          debugPrint('ℹ️ [GoogleSignIn] Sign-in cancelled by user.');
        }
      } else {
        ErrorHandler.log(e, stackTrace: st, tag: 'AuthService.signInWithGoogle');
        GoogleSignInExceptionHandler.log(mapped, stackTrace: st);
      }
      throw mapped;
    }
  }

  Future<UserCredential> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    provider.addScope('https://www.googleapis.com/auth/userinfo.email');
    provider.addScope('https://www.googleapis.com/auth/userinfo.profile');
    provider.addScope('https://www.googleapis.com/auth/user.addresses.read');
    provider.setCustomParameters({'prompt': 'select_account'});

    return _auth.signInWithPopup(provider);
  }

  Future<UserCredential> _signInWithGoogleMobile() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.googleSignInMobileSignOut');
    }

    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;

    // Fetch location from Google People API if accessible
    _lastGooglePeopleData = await _fetchGooglePeopleData(googleUser);

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<Map<String, dynamic>> _fetchGooglePeopleData(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      final token = googleUser.authentication.idToken;
      if (token == null || token.isEmpty) return {};
      final headers = {'Authorization': 'Bearer $token'};
      final response = await http.get(
        Uri.parse(
          'https://people.googleapis.com/v1/people/me?personFields=addresses,locations',
        ),
        headers: headers,
      );

      String? location;
      String? city;
      String? state;
      String? country;
      var isApproximate = false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['addresses'] != null &&
            (data['addresses'] as List).isNotEmpty) {
          final addr = data['addresses'][0];
          location = addr['formattedValue']?.toString();
          city = addr['city']?.toString();
          state = addr['region']?.toString();
          country = addr['country']?.toString();
        } else if (data['locations'] != null &&
            (data['locations'] as List).isNotEmpty) {
          location = data['locations'][0]['value']?.toString();
        }
      }

      // IP fallback if Google account address is not set or restricted
      if (location == null || location.isEmpty) {
        try {
          final ipRes = await http
              .get(Uri.parse('https://ipapi.co/json/'))
              .timeout(const Duration(seconds: 3));
          if (ipRes.statusCode == 200) {
            final ipData = jsonDecode(ipRes.body);
            city ??= ipData['city']?.toString();
            state ??= ipData['region']?.toString();
            country ??=
                ipData['country_name']?.toString() ??
                ipData['country_code']?.toString();
            final parts = [
              city,
              state,
              country,
            ].where((s) => s != null && s.isNotEmpty).toList();
            if (parts.isNotEmpty) {
              location = parts.join(', ');
              isApproximate = true;
            }
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.fetchGooglePeople.ipLookup');
        }
      }

      return {
        'location': location,
        'city': city,
        'state': state,
        'country': country,
        'isApproximateLocation': isApproximate,
      };
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthService.fetchGooglePeople',
      );
    }
    return {};
  }

  Future<UserCredential> retryGoogleSignIn({int maxRetries = 2}) async {
    var attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      try {
        return await signInWithGoogle();
      } catch (e) {
        attempts++;
        lastError = e;
        if (attempts >= maxRetries) break;
        await Future.delayed(Duration(seconds: attempts));
      }
    }

    if (lastError is GoogleSignInException) {
      throw lastError;
    }

    throw const GoogleSignInException(
      message: 'Sign-in failed after retries',
      code: 'max-retries-exceeded',
    );
  }

  Future<void> signOut() async {
    try {
      final uidSnapshot = uid;
      if (uidSnapshot.isNotEmpty) {
        await PushNotificationService.to.unregisterToken(uidSnapshot);
      }
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      // Log the error but don't fail - sign out should complete even if there are issues
      logger.warning('Error during sign out: $e', tag: 'AUTH');
      // Ensure the state is updated anyway
      _user.value = null;
      _isAuthenticated.value = false;
      needsOnboarding.value = false;
      rethrow;
    }
  }

  Future<void> logout() => signOut();

  Future<void> deleteAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final uidToDelete = currentUser.uid;

      // 1. Clean up user data & channel from Firestore
      try {
        final userDocRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uidToDelete);
        final userSnap = await userDocRef.get();
        if (userSnap.exists) {
          final channelId = userSnap.data()?['channelId'] as String?;
          if (channelId != null && channelId.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection(FirestoreCollections.channels)
                .doc(channelId)
                .update({
              'status': 'deleted',
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((e, s) {
              ErrorHandler.log(e, stackTrace: s is StackTrace ? s : null, tag: 'AuthService.deleteAccount.channel');
            });
          }
          await userDocRef.delete();
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.deleteAccount.firestore');
      }

      // 2. Delete the Firebase Auth user
      await currentUser.delete();

      // 3. Clear local state
      _user.value = null;
      _isAuthenticated.value = false;
      needsOnboarding.value = false;
    }
  }

  bool _isSyncingUser = false;
  String? _lastSyncedUid;
  DateTime? _lastSyncTime;

  /// ✅ Synchronizes user data to Firestore 'users' collection
  Future<void> _syncUserToFirestore(User user) async {
    if (user.isAnonymous) return;
    // Avoid duplicate simultaneous/rapid syncs during auth state startup bursts
    if (_isSyncingUser && _lastSyncedUid == user.uid) {
      debugPrint('AuthService: [SYNC] Sync already in progress for UID: ${user.uid}. Skipping duplicate.');
      return;
    }
    if (_lastSyncedUid == user.uid &&
        _lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!).inSeconds < 10) {
      debugPrint('AuthService: [SYNC] User ${user.uid} already synced recently. Skipping duplicate.');
      return;
    }

    _isSyncingUser = true;
    _lastSyncedUid = user.uid;

    debugPrint(
      'AuthService: [SYNC] Starting synchronization for UID: ${user.uid}',
    );
    final userDoc = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid);

    try {
      // Capture critical security and lifecycle metadata
      final metadata = <String, dynamic>{
        'creationTime': user.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        'emailVerified': user.emailVerified,
        'phoneNumber': user.phoneNumber,
        'isAnonymous': user.isAnonymous,
        'lastSyncAt': DateTime.now().toIso8601String(),
        'platform': GetPlatform.isWeb ? 'web' : 'mobile',
      };

      debugPrint(
        'AuthService: [SYNC] Checking document existence for UID: ${user.uid}',
      );
      final docSnapshot = await userDoc.get().timeout(
        const Duration(seconds: 10),
      );

      if (!docSnapshot.exists) {
        debugPrint(
          'AuthService: [SYNC] No document found by UID. Checking for legacy account with email: ${user.email}...',
        );

        String? restoredChannelId;
        Map<String, dynamic>? legacyData;

        if (user.email != null && user.email!.isNotEmpty) {
          try {
            final emailQuery = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .where('email', isEqualTo: user.email)
                .limit(5)
                .get();

            final legacyDocs = emailQuery.docs.where((d) => d.id != user.uid).toList();
            if (legacyDocs.isNotEmpty) {
              debugPrint(
                'AuthService: [SYNC] ⚠️ Found ${legacyDocs.length} legacy user doc(s) for email ${user.email}. Consolidating...',
              );
              for (final oldDoc in legacyDocs) {
                final oldData = oldDoc.data();
                legacyData ??= oldData;
                final oldChannelId = oldData['channelId'] as String?;
                if (oldChannelId != null && oldChannelId.isNotEmpty) {
                  restoredChannelId = oldChannelId;
                  // Re-assign channel ownership to active UID
                  try {
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.channels)
                        .doc(oldChannelId)
                        .update({
                      'ownerId': user.uid,
                      'userId': user.uid,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    debugPrint('AuthService: [SYNC] Re-linked channel $oldChannelId to new UID ${user.uid}');
                  } catch (chErr, chStack) {
                    ErrorHandler.log(chErr, stackTrace: chStack, tag: 'AuthService.syncUser.relinkChannel');
                  }
                }

                // Remove stale legacy user document
                try {
                  await oldDoc.reference.delete();
                  debugPrint('AuthService: [SYNC] Cleaned up legacy user doc ${oldDoc.id}');
                } catch (delErr, delStack) {
                  ErrorHandler.log(delErr, stackTrace: delStack, tag: 'AuthService.syncUser.deleteLegacyDoc');
                }
              }
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.syncUser.legacyQuery');
          }
        }

        final hasCompletedOnboarding = legacyData?['hasCompletedOnboarding'] as bool? ?? false;
        needsOnboarding.value = !hasCompletedOnboarding;

        final newUser = UserModel.fromFirebaseUser(user).copyWith(
          metadata: metadata,
          channelId: restoredChannelId ?? legacyData?['channelId'] as String?,
          gender: legacyData?['gender'] as String?,
          age: (legacyData?['age'] as num?)?.toInt() ?? _lastGooglePeopleData?['age'],
          ageGroup: legacyData?['ageGroup'] as String?,
          birthdate: legacyData?['birthdate'] as String? ?? _lastGooglePeopleData?['birthdate'],
          location: legacyData?['location'] as String? ?? _lastGooglePeopleData?['location'],
          city: legacyData?['city'] as String? ?? _lastGooglePeopleData?['city'],
          state: legacyData?['state'] as String? ?? _lastGooglePeopleData?['state'],
          country: legacyData?['country'] as String? ?? _lastGooglePeopleData?['country'],
          hasCompletedOnboarding: hasCompletedOnboarding,
        );

        await userDoc.set(newUser.toFirestoreCreate());
        debugPrint(
          'AuthService: [SYNC] ✅ NEW user record created successfully (legacy data consolidated if present)',
        );
        if (!hasCompletedOnboarding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndPromptOnboarding();
          });
        }
      } else {
        debugPrint(
          'AuthService: [SYNC] Document exists. Updating lifecycle timestamps...',
        );
        final docData = docSnapshot.data() ?? {};
        final hasCompletedOnboarding =
            docData['hasCompletedOnboarding'] as bool? ??
            (docData['birthdate'] != null &&
                docData['birthdate'].toString().isNotEmpty);
        needsOnboarding.value = !hasCompletedOnboarding;

        final existingName = (docData['displayName'] as String?) ?? (docData['name'] as String?);
        final existingPhoto = (docData['photoURL'] as String?) ?? (docData['photoUrl'] as String?) ?? (docData['avatarUrl'] as String?);
        final resolvedName = (existingName != null && existingName.isNotEmpty) ? existingName : (user.displayName ?? '');
        final resolvedPhoto = (existingPhoto != null && existingPhoto.isNotEmpty) ? existingPhoto : (user.photoURL ?? '');

        if (existingName != null && existingName.isNotEmpty && user.displayName != existingName) {
          try {
            await user.updateDisplayName(existingName);
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.syncUser.updateDisplayName');
          }
        }
        if (existingPhoto != null && existingPhoto.isNotEmpty && user.photoURL != existingPhoto) {
          try {
            await user.updatePhotoURL(existingPhoto);
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.syncUser.updatePhotoURL');
          }
        }

        final currentUser = UserModel.fromFirebaseUser(user).copyWith(
          displayName: resolvedName,
          photoURL: resolvedPhoto,
          metadata: metadata,
          age: _lastGooglePeopleData?['age'],
          birthdate: _lastGooglePeopleData?['birthdate'],
          location: _lastGooglePeopleData?['location'],
          city: _lastGooglePeopleData?['city'],
          state: _lastGooglePeopleData?['state'],
          country: _lastGooglePeopleData?['country'],
          hasCompletedOnboarding: hasCompletedOnboarding,
        );

        final updateData = currentUser.toFirestoreUpdate();
        updateData['metadata'] = metadata;
        if (existingName != null && existingName.isNotEmpty) {
          updateData['displayName'] = existingName;
          updateData['name'] = existingName;
        }
        if (existingPhoto != null && existingPhoto.isNotEmpty) {
          updateData['photoURL'] = existingPhoto;
        }

        await userDoc.update(updateData);
        debugPrint(
          'AuthService: [SYNC] ✅ EXISTING user record updated successfully (preserved custom profile)',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthService.syncUser');
      logger.error('Sync failure for ${user.uid}: $e', tag: 'AUTH');

      // Critical Fallback: Use idempotent set() with merge if get() or update() failed
      try {
        debugPrint(
          'AuthService: [SYNC] Attempting idempotent fallback (set with merge)...',
        );
        final fallbackUser = UserModel.fromFirebaseUser(user).copyWith(
          age: _lastGooglePeopleData?['age'],
          birthdate: _lastGooglePeopleData?['birthdate'],
          location: _lastGooglePeopleData?['location'],
          city: _lastGooglePeopleData?['city'],
          state: _lastGooglePeopleData?['state'],
          country: _lastGooglePeopleData?['country'],
        );
        await userDoc.set(
          fallbackUser.toFirestoreCreate(),
          SetOptions(merge: true),
        );
        debugPrint('AuthService: [SYNC] ✅ Idempotent fallback successful');
      } catch (fallbackError, fallbackStack) {
        ErrorHandler.log(
          fallbackError,
          stackTrace: fallbackStack,
          tag: 'AuthService.syncUser.fallback',
        );
      }
    } finally {
      _isSyncingUser = false;
      _lastSyncTime = DateTime.now();
    }
  }

  /// Updates profile with optional Age Group and optional Gender after Google Sign-In or Settings update
  Future<void> updateUserProfileOnboarding({
    String? ageGroup,
    String? gender,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final updateData = <String, dynamic>{
      'hasCompletedOnboarding': true,
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

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(currentUser.uid)
        .set(updateData, SetOptions(merge: true));

    needsOnboarding.value = false;
  }

  /// Skips onboarding while marking it as completed for the current user
  Future<void> skipUserOnboarding() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(currentUser.uid)
        .update({'hasCompletedOnboarding': true});

    needsOnboarding.value = false;
  }

  bool _isOnboardingPromptShowing = false;

  /// Prompts onboarding sheet if a newly signed-in user needs to complete Date of Birth / Gender details
  Future<void> checkAndPromptOnboarding([BuildContext? context]) async {
    if (_isOnboardingPromptShowing) return;

    // Safety guard: Never show for unsigned, guest, or anonymous users
    final currentUser = _auth.currentUser;
    if (currentUser == null ||
        currentUser.isAnonymous ||
        !_isAuthenticated.value) {
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
}
