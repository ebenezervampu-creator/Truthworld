import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleSignInException;
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/google_signin_exception_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/data/models/user_model.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();

  late FirebaseAuth _auth;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final Rxn<User> _user = Rxn<User>();
  Rxn<User> get currentUser => _user;

  User? get user => _user.value;
  Future<String?> get idToken async => await _auth.currentUser?.getIdToken();

  final RxBool _isAuthenticated = false.obs;
  RxBool get isAuthenticated => _isAuthenticated;

  String get uid => _user.value?.uid ?? '';

  final RxBool _hasChannel = false.obs;
  RxBool get hasChannel => _hasChannel;

  StreamSubscription? _channelSubscription;

  /// ✅ SAFE async initialization (no Firebase calls before this)
  Future<AuthService> init() async {
    _auth = FirebaseAuth.instance;
    
    // Google Sign-In v7 requires explicit initialization
    try {
      if (kIsWeb) {
        // On Web, GoogleSignIn requires a clientId (via meta tag or parameter).
        // Since we use FirebaseAuth.signInWithPopup for Web auth, we can skip 
        // explicit plugin initialization to avoid the "ClientID not set" assertion.
        debugPrint('AuthService: Web platform detected. Skipping explicit GoogleSignIn initialization.');
      } else {
        await _googleSignIn.initialize();
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
    if (u != null) {
      _syncUserToFirestore(u);
    }
  }

  void _updateChannelSubscription(User? user) {
    _channelSubscription?.cancel();

    if (user == null) {
      _hasChannel.value = false;
      return;
    }

    _channelSubscription = FirebaseFirestore.instance
        .collection('channels')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            _hasChannel.value = snapshot.docs.isNotEmpty;
          },
          onError: (error) {
            debugPrint('AuthService Firestore error: $error');
          },
        );
  }

  @override
  void onClose() {
    _channelSubscription?.cancel();
    super.onClose();
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
      if (kDebugMode) {
        debugPrint('AuthService: Google Sign-In Error: $e');
        debugPrint('AuthService: StackTrace: $st');
      }
      final mapped = GoogleSignInExceptionHandler.from(e);
      GoogleSignInExceptionHandler.log(mapped, stackTrace: st);
      throw mapped;
    }
  }

  Future<UserCredential> _signInWithGoogleWeb() async {
    final GoogleAuthProvider provider = GoogleAuthProvider();
    provider.addScope('https://www.googleapis.com/auth/userinfo.email');
    provider.addScope('https://www.googleapis.com/auth/userinfo.profile');
    provider.setCustomParameters({'prompt': 'select_account'});
    
    return await _auth.signInWithPopup(provider);
  }

  Future<UserCredential> _signInWithGoogleMobile() async {
    final googleUser = await _googleSignIn.authenticate();

    // In v7.x, authenticate() returns a non-nullable GoogleSignInAccount.
    // If cancelled, it throws a PlatformException or similar.
    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<UserCredential> retryGoogleSignIn({int maxRetries = 2}) async {
    int attempts = 0;
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
      isRetryable: false,
    );
  }

  Future<void> signOut() async {
    try {
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
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    
    try {
      // Capture critical security and lifecycle metadata
      final Map<String, dynamic> metadata = {
        'creationTime': user.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        'emailVerified': user.emailVerified,
        'phoneNumber': user.phoneNumber,
        'isAnonymous': user.isAnonymous,
        'lastSyncAt': DateTime.now().toIso8601String(),
        'platform': GetPlatform.isWeb ? 'web' : 'mobile',
      };

      DocumentSnapshot docSnapshot;
      try {
        docSnapshot = await userDoc.get();
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          debugPrint('AuthService: Firestore server is offline/unavailable. Profile sync deferred.');
          return;
        }
        rethrow;
      }
      
      if (!docSnapshot.exists) {
        final newUser = UserModel.fromFirebaseUser(user).copyWith(
          metadata: metadata,
        );
        
        await userDoc.set(newUser.toFirestoreCreate());
      } else {
        final currentUser = UserModel.fromFirebaseUser(user).copyWith(
          metadata: metadata,
        );
        
        final updateData = currentUser.toFirestoreUpdate();
        updateData['metadata'] = metadata;
        
        await userDoc.update(updateData);
      }
    } catch (e) {
      logger.warning('Auth sync error for ${user.uid}: $e', tag: 'AUTH');
    }
  }
}




