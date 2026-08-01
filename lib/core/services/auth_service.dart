import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleSignInException;
import 'package:http/http.dart' as http;
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

  StreamSubscription? _channelSubscription;
  final RxBool isPremiumUser = false.obs;
  final RxnString premiumPlanId = RxnString();
  final RxnString userGender = RxnString();
  final RxnInt userAge = RxnInt();
  final RxnString userBirthdate = RxnString();
  final RxnString userLocation = RxnString();
  final RxnString userCity = RxnString();
  final RxnString userState = RxnString();
  final RxnString userCountry = RxnString();
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
          (snapshot) {
            final activeChannels = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();

            _hasChannel.value = activeChannels.isNotEmpty;
            if (activeChannels.isNotEmpty) {
              _userChannel.value = activeChannels.first;
            } else {
              _userChannel.value = null;
            }
          },
          onError: (error) {
            debugPrint('AuthService Firestore error: $error');
          },
        );
  }

  void _updateUserDocSubscription(User? user) {
    _userDocSubscription?.cancel();
    if (user == null) {
      isPremiumUser.value = false;
      premiumPlanId.value = null;
      userGender.value = null;
      userAge.value = null;
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
              isPremiumUser.value = data['isPremium'] as bool? ?? false;
              premiumPlanId.value = data['premiumPlanId'] as String?;
              userGender.value = data['gender'] as String?;
              userAge.value = (data['age'] as num?)?.toInt();
              userBirthdate.value = data['birthdate'] as String?;
              userLocation.value = data['location'] as String?;
              userCity.value = data['city'] as String?;
              userState.value = data['state'] as String?;
              userCountry.value = data['country'] as String?;
            } else {
              isPremiumUser.value = false;
              premiumPlanId.value = null;
              userGender.value = null;
              userAge.value = null;
              userBirthdate.value = null;
              userLocation.value = null;
              userCity.value = null;
              userState.value = null;
              userCountry.value = null;
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
    final u = _user.value;
    if (u == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(u.uid)
          .update({
            'isPremium': false,
            'premiumPlanId': FieldValue.delete(),
          });
    } catch (e) {
      debugPrint('Error cancelling premium subscription: $e');
    }
  }

  // ================= GOOGLE SIGN IN =================

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        return await _signInWithGoogleMobile();
      }
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
    provider.addScope('https://www.googleapis.com/auth/user.gender.read');
    provider.addScope('https://www.googleapis.com/auth/user.birthday.read');
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

    // Fetch gender, birthday, and location from Google People API if accessible
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
      final dynamic user = googleUser;
      final Map<String, String>? headers = await user.authHeaders;
      if (headers == null) return {};
      final response = await http.get(
        Uri.parse(
          'https://people.googleapis.com/v1/people/me?personFields=genders,birthdays,ageRanges,addresses,locations',
        ),
        headers: headers,
      );

      String? gender;
      String? birthdate;
      int? age;
      String? location;
      String? city;
      String? state;
      String? country;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['genders'] != null && (data['genders'] as List).isNotEmpty) {
          final rawVal = data['genders'][0]['value']?.toString();
          if (rawVal != null && rawVal.isNotEmpty) {
            gender =
                rawVal[0].toUpperCase() + rawVal.substring(1).toLowerCase();
          }
        }

        if (data['birthdays'] != null &&
            (data['birthdays'] as List).isNotEmpty) {
          final bdayObj = data['birthdays'][0]['date'];
          if (bdayObj != null) {
            final year = bdayObj['year'] as int?;
            final month = bdayObj['month'] as int?;
            final day = bdayObj['day'] as int?;
            if (year != null && month != null && day != null) {
              birthdate =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final now = DateTime.now();
              age = now.year - year;
              if (now.month < month || (now.month == month && now.day < day)) {
                age--;
              }
            }
          }
        }

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
            }
          }
        } catch (_) {}
      }

      return {
        'gender': ?gender,
        'birthdate': ?birthdate,
        'age': ?age,
        'location': ?location,
        'city': ?city,
        'state': ?state,
        'country': ?country,
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
      // 1. Delete user data from Firestore (if needed, here we just delete the auth user)
      // Note: In production, you'd likely want a Cloud Function to clean up all user-related collections.

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
          'AuthService: [SYNC] No document found. Initializing NEW user record...',
        );
        final newUser = UserModel.fromFirebaseUser(user).copyWith(
          metadata: metadata,
          gender: _lastGooglePeopleData?['gender'],
          age: _lastGooglePeopleData?['age'],
          birthdate: _lastGooglePeopleData?['birthdate'],
          location: _lastGooglePeopleData?['location'],
          city: _lastGooglePeopleData?['city'],
          state: _lastGooglePeopleData?['state'],
          country: _lastGooglePeopleData?['country'],
        );

        await userDoc.set(newUser.toFirestoreCreate());
        debugPrint(
          'AuthService: [SYNC] ✅ NEW user record created successfully',
        );
      } else {
        debugPrint(
          'AuthService: [SYNC] Document exists. Updating lifecycle timestamps...',
        );
        final currentUser = UserModel.fromFirebaseUser(user).copyWith(
          metadata: metadata,
          gender: _lastGooglePeopleData?['gender'],
          age: _lastGooglePeopleData?['age'],
          birthdate: _lastGooglePeopleData?['birthdate'],
          location: _lastGooglePeopleData?['location'],
          city: _lastGooglePeopleData?['city'],
          state: _lastGooglePeopleData?['state'],
          country: _lastGooglePeopleData?['country'],
        );

        final updateData = currentUser.toFirestoreUpdate();
        // Merge metadata into existing doc to preserve platform history if needed
        // Here we overwrite as it's volatile session metadata
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
          gender: _lastGooglePeopleData?['gender'],
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
      } catch (fallbackError) {
        debugPrint(
          'AuthService: [SYNC] ❌ CRITICAL: Fallback also failed: $fallbackError',
        );
      }
    }
  }
}
