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
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/google_signin_exception_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/user_model.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();

  late FirebaseAuth _auth;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final Rxn<User> _user = Rxn<User>();
  Rxn<User> get currentUser => _user;

  User? get user => _user.value;

  final RxBool _isAuthenticated = false.obs;
  RxBool get isAuthenticated => _isAuthenticated;

  String get uid => _user.value?.uid ?? '';

  final RxBool _hasChannel = false.obs;
  RxBool get hasChannel => _hasChannel;

  final Rxn<Channel> _userChannel = Rxn<Channel>();
  Channel? get userChannel => _userChannel.value;
  Rxn<Channel> get rxUserChannel => _userChannel;

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

  void checkTrialExpiry() {
    final exp = premiumExpiresAt.value;
    if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
      if (isPremiumUser.value) {
        isPremiumUser.value = false;
        try {
          final box = GetStorage();
          box.write('isPremiumUser', false);
        } catch (_) {}
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
    if (hasChannel.value && userChannel != null) {
      return userChannel!.name;
    }
    return user?.displayName ?? 'User';
  }

  String get activePhotoUrl {
    if (hasChannel.value && userChannel != null) {
      return userChannel!.avatarUrl;
    }
    return user?.photoURL ?? '';
  }

  String get activeHandle {
    if (hasChannel.value && userChannel != null) {
      final handle = userChannel!.handle;
      return handle.startsWith('@') ? handle : '@$handle';
    }
    final email = user?.email ?? '';
    return email.isNotEmpty ? "@${email.split('@')[0]}" : '@user';
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
    } catch (e) {
      debugPrint('AuthService: error loading cached premium status: $e');
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
    } catch (e) {
      // On some platforms, this might not be implemented or handled automatically.
      debugPrint('AuthService: GoogleSignIn.initialize() error: $e');
    }

    _user.bindStream(_auth.authStateChanges());
    ever(_user, _handleAuthChanged);

    return this;
  }

  void _handleAuthChanged(User? u) {
    _isAuthenticated.value = u != null;
    _updateChannelSubscription(u);
    _updateUserDocSubscription(u);
    if (u != null) {
      _syncUserToFirestore(u).then((_) {
        PushNotificationService.to.registerToken(u.uid);
      });
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
                return;
              }
            } catch (e) {
              debugPrint('AuthService: fallback channel check by userId error: $e');
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
                    return;
                  }
                }
              }
            } catch (e) {
              debugPrint('AuthService: fallback channel check by user doc error: $e');
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
                  } catch (_) {}
                  return;
                }
              } catch (e) {
                debugPrint('AuthService: fallback channel check by email error: $e');
              }
            }

            _hasChannel.value = false;
            _userChannel.value = null;
          },
          onError: (error) {
            debugPrint('AuthService Firestore error: $error');
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

      userGender.value = null;
      userAge.value = null;
      userAgeGroup.value = null;
      userBirthdate.value = null;
      userLocation.value = null;
      userCity.value = null;
      userState.value = null;
      userCountry.value = null;
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

                if (isExpired) {
                  isPremiumUser.value = false;
                  premiumPlanId.value = planId ?? cachedPlanId;
                  box.write('isPremiumUser', false);
                } else {
                  isPremiumUser.value = isPrem;
                  premiumPlanId.value = planId;
                  box.write('isPremiumUser', isPrem);
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
              userGender.value = null;
              userAge.value = null;
              userAgeGroup.value = null;
              userBirthdate.value = null;
              userLocation.value = null;
              userCity.value = null;
              userState.value = null;
              userCountry.value = null;
              needsOnboarding.value = true;
            }
          },
          onError: (e) {
            debugPrint('Error listening to user document: $e');
          },
        );
  }

  @override
  void onClose() {
    _channelSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.onClose();
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
    } catch (e) {
      debugPrint('Error cancelling premium subscription: $e');
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
        if (kDebugMode) {
          debugPrint('AuthService: Google Sign-In Error: $e');
          debugPrint('AuthService: StackTrace: $st');
        }
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
    } catch (_) {}

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
        } catch (_) {}
      }

      return {
        'location': location,
        'city': city,
        'state': state,
        'country': country,
        'isApproximateLocation': isApproximate,
      };
    } catch (e) {
      debugPrint(
        'AuthService: Error fetching Google People API profile data: $e',
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
            }).catchError((_) {});
          }
          await userDocRef.delete();
        }
      } catch (e) {
        debugPrint('AuthService: Error deleting user Firestore record: $e');
      }

      // 2. Delete the Firebase Auth user
      await currentUser.delete();

      // 3. Clear local state
      _user.value = null;
      _isAuthenticated.value = false;
    }
  }

  /// ✅ Synchronizes user data to Firestore 'users' collection
  Future<void> _syncUserToFirestore(User user) async {
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
                  } catch (chErr) {
                    debugPrint('AuthService: [SYNC] Error re-linking channel $oldChannelId: $chErr');
                  }
                }

                // Remove stale legacy user document
                try {
                  await oldDoc.reference.delete();
                  debugPrint('AuthService: [SYNC] Cleaned up legacy user doc ${oldDoc.id}');
                } catch (delErr) {
                  debugPrint('AuthService: [SYNC] Error deleting legacy user doc ${oldDoc.id}: $delErr');
                }
              }
            }
          } catch (e) {
            debugPrint('AuthService: [SYNC] Error during email consolidation query: $e');
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

        if (!hasCompletedOnboarding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndPromptOnboarding();
          });
        }

        final currentUser = UserModel.fromFirebaseUser(user).copyWith(
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

        await userDoc.update(updateData);
        debugPrint(
          'AuthService: [SYNC] ✅ EXISTING user record updated successfully',
        );
      }
    } catch (e) {
      debugPrint('AuthService: [SYNC] ⚠️ Sync Warning/Error: $e');
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          checkAndPromptOnboarding();
        });
      } catch (fallbackError) {
        debugPrint(
          'AuthService: [SYNC] ❌ CRITICAL: Fallback also failed: $fallbackError',
        );
      }
    }
  }

  /// Updates profile with optional Age Group and optional Gender after Google Sign-In
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
      updateData['ageGroup'] = ageGroup.trim();
    }

    if (gender != null && gender.trim().isNotEmpty) {
      updateData['gender'] = gender.trim();
    }

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(currentUser.uid)
        .update(updateData);

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

  /// Prompts onboarding sheet if the user needs to complete Date of Birth / Gender details
  Future<void> checkAndPromptOnboarding([BuildContext? context]) async {
    if (_isOnboardingPromptShowing) return;
    final ctx = context ?? Get.context;
    if (ctx == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // If needsOnboarding has not been determined or is false, query Firestore doc
    if (!needsOnboarding.value) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(currentUser.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final hasCompleted = data['hasCompletedOnboarding'] as bool? ??
              (data['birthdate'] != null &&
                  data['birthdate'].toString().isNotEmpty);
          needsOnboarding.value = !hasCompleted;
        } else {
          needsOnboarding.value = true;
        }
      } catch (e) {
        debugPrint('AuthService: Error checking onboarding status: $e');
      }
    }

    if (needsOnboarding.value && ctx.mounted && !_isOnboardingPromptShowing) {
      _isOnboardingPromptShowing = true;
      try {
        await GoogleOnboardingSheet.show(ctx);
      } finally {
        _isOnboardingPromptShowing = false;
      }
    }
  }
}
