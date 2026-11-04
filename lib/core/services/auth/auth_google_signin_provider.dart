import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart'
    hide GoogleSignInException;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/google_signin_exception_handler.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';

/// Manages Google Sign-In SDK integration across Web and Mobile, including People API extraction.
class AuthGoogleSignInProvider {
  final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  Map<String, dynamic>? lastGooglePeopleData;
  String? lastGoogleEmail;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  /// Retrieves an AuthCredential directly for linking or re-authenticating.
  Future<AuthCredential> getGoogleAuthCredential() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'getGoogleAuthCredential is not supported on web. Use linkWithPopup or reauthenticateWithPopup with GoogleAuthProvider.',
      );
    } else {
      await initialize();
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final googleUser = await googleSignIn.authenticate();
      lastGoogleEmail = googleUser.email;
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInException(
          message: 'Unable to retrieve Google authentication token.',
          code: 'missing-id-token',
          isRetryable: true,
        );
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    }
  }

  /// Initializes the Google Sign-In plugin with the platform client id.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _initFuture ??= _doInitialize();
    return _initFuture;
  }

  Future<void> _doInitialize() async {
    try {
      if (kIsWeb) {
        debugPrint(
          'AuthGoogleSignInProvider: Web platform detected. Client ID handled via meta and Firebase Auth.',
        );
      } else {
        await googleSignIn.initialize(
          serverClientId:
              '768266102263-f1bou7fgaqn2rkqh0cn5p6voksb163qt.apps.googleusercontent.com',
        );
      }
      _isInitialized = true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthGoogleSignInProvider.initialize',
      );
    }
  }

  /// Detects whether the current runtime environment is WebAssembly (dart2wasm).
  ///
  /// In dart2wasm, Dart primitive types [int] and [double] are distinct Wasm types
  /// (unlike dart2js where all numbers are standard JavaScript [Number] objects).
  /// Therefore, `identical(0, 0.0)` evaluates to `false` in WebAssembly and `true` in JavaScript.
  static bool get isWasm =>
      kIsWeb &&
      (const bool.fromEnvironment('dart.tool.dart2wasm') || !identical(0, 0.0));

  /// Initiates Google Sign-In flow across platforms with sanitized error handling.
  Future<UserCredential> signInWithGoogle(FirebaseAuth auth) async {
    try {
      return kIsWeb
          ? await signInWithGoogleWeb(auth)
          : await signInWithGoogleMobile(auth);
    } catch (e, st) {
      final mapped = GoogleSignInExceptionHandler.from(e);
      if (mapped.code == 'user-cancelled' || mapped.code == 'redirecting') {
        if (kDebugMode) {
          debugPrint('ℹ️ [GoogleSignIn] Event: ${mapped.message}');
        }
      } else {
        ErrorHandler.log(
          e,
          stackTrace: st,
          tag: 'AuthGoogleSignInProvider.signInWithGoogle',
        );
        GoogleSignInExceptionHandler.log(mapped, stackTrace: st);
      }
      throw mapped;
    }
  }

  bool _isSigningInWeb = false;

  /// Web authentication flow:
  /// - Uses [signInWithPopup] as the primary flow across all Web environments (both WASM and JavaScript).
  ///   This guarantees instantaneous sign-in without page reloads, preserves runtime memory, and prevents
  ///   third-party cookie/partitioned storage issues common in private browsing (InPrivate/Incognito).
  /// - Automatically falls back to [signInWithRedirect] ONLY if the browser actively blocks popups
  ///   or runs in a webview environment where popups are unsupported.
  Future<UserCredential> signInWithGoogleWeb(
    FirebaseAuth auth, {
    @visibleForTesting bool? isWasmOverride,
    @visibleForTesting bool? forceRedirectForTesting,
  }) async {
    if (_isSigningInWeb) {
      debugPrint('AuthGoogleSignInProvider: Web sign-in is already in progress.');
      throw const GoogleSignInException(
        message: 'Sign-in is already in progress.',
        code: 'user-cancelled',
      );
    }
    _isSigningInWeb = true;

    final provider = GoogleAuthProvider();
    provider.addScope('https://www.googleapis.com/auth/userinfo.email');
    provider.addScope('https://www.googleapis.com/auth/userinfo.profile');
    provider.setCustomParameters({'prompt': 'select_account'});

    try {
      if (forceRedirectForTesting ?? false) {
        try {
          final box = GetStorage();
          box.write('auth_pending_redirect', true);
          box.write(
            'auth_pending_redirect_time',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}

        await auth.signInWithRedirect(provider);
        throw const GoogleSignInException(
          message: 'Redirecting to Google Sign-In...',
          code: 'redirecting',
        );
      }

      try {
        // App Check is already primed on startup; trigger background refresh without blocking
        // the user gesture to prevent browser popup blockers from intercepting the window.open.
        if (kIsWeb && Firebase.apps.isNotEmpty) {
          unawaited(
            FirebaseAppCheck.instance.getToken().catchError((e) {
              debugPrint('AuthGoogleSignInProvider: App Check token prime notice: $e');
              return null;
            }),
          );
        }

        debugPrint(
          'AuthGoogleSignInProvider: Initiating Google Sign-In with popup...',
        );
        return await auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        final code = e.code.toLowerCase();
        if (code == 'popup-closed-by-user' ||
            code == 'cancelled-popup-request') {
          debugPrint('AuthGoogleSignInProvider: User closed Google Sign-In popup.');
          throw const GoogleSignInException(
            message: 'Sign-in was cancelled.',
            code: 'user-cancelled',
            isRetryable: true,
          );
        }

        // Fall back to redirect if popup was blocked, window opener was restricted, or popup is unsupported
        if (code.contains('popup-blocked') ||
            code.contains('not-supported') ||
            code.contains('disallowed-useragent') ||
            code.contains('restricted')) {
          debugPrint(
            'AuthGoogleSignInProvider: Popup unavailable (${e.code}). Falling back to signInWithRedirect.',
          );
          try {
            final box = GetStorage();
            box.write('auth_pending_redirect', true);
            box.write(
              'auth_pending_redirect_time',
              DateTime.now().millisecondsSinceEpoch,
            );
          } catch (_) {}

          await auth.signInWithRedirect(provider);
          throw const GoogleSignInException(
            message: 'Redirecting to Google Sign-In...',
            code: 'redirecting',
          );
        }
        rethrow;
      }
    } finally {
      _isSigningInWeb = false;
    }
  }

  /// Mobile Google Sign-In flow using GoogleSignInAccount credentials.
  Future<UserCredential> signInWithGoogleMobile(FirebaseAuth auth) async {
    await initialize();

    try {
      await googleSignIn.signOut();
    } catch (_) {}

    final googleUser = await googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInException(
        message: 'Unable to retrieve Google authentication token. Please verify Google Play Services and try again.',
        code: 'missing-id-token',
        isRetryable: true,
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    // Prime App Check token in memory prior to exchanging credential with Identity Platform
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAppCheck.instance
            .getToken()
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    final userCredential = await auth.signInWithCredential(credential);

    // Fetch demographics non-blocking in background
    unawaited(
      fetchGooglePeopleData(googleUser).then((data) {
        lastGooglePeopleData = data;
      }).catchError((_) {}),
    );

    return userCredential;
  }

  /// Fetches optional user demographics and address from Google People API with IP fallback.
  Future<Map<String, dynamic>> fetchGooglePeopleData(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      final token = googleUser.authentication.idToken;
      if (token == null || token.isEmpty) return {};
      final headers = {'Authorization': 'Bearer $token'};
      final response = await AppHttpClient.get(
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

      // Step 1: Google People API — location/city/state only.
      // addr['country'] is intentionally ignored: it is a self-reported full
      // name in the account's language ("India", "भारत", etc.) with no
      // guaranteed ISO-code equivalent. Country is always sourced from IP.
      if (response.statusCode == 200) {
        final data = await IsolateComputeUtils.parseJsonMapAsync(response.body);

        if (data['addresses'] != null &&
            (data['addresses'] as List).isNotEmpty) {
          final addr = data['addresses'][0];
          location = addr['formattedValue']?.toString();
          city = addr['city']?.toString();
          state = addr['region']?.toString();
          // addr['country'] deliberately not used — see note above.
        } else if (data['locations'] != null &&
            (data['locations'] as List).isNotEmpty) {
          location = data['locations'][0]['value']?.toString();
        }
      }

      // Step 2: Location lookup via IP — authoritative ISO 2-letter country_code.
      // Also fills city/state if Google People had no address, and builds location string.
      // Uses CORS-friendly ipwho.is first, with ipapi.co as fallback.
      try {
        Map<String, dynamic>? ipData;
        try {
          final res = await AppHttpClient.get(
            Uri.parse('https://ipwho.is/'),
          ).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final parsed = jsonDecode(res.body) as Map<String, dynamic>;
            if (parsed['success'] == true) {
              ipData = parsed;
            }
          }
        } catch (_) {}

        if (ipData == null) {
          try {
            final ipRes = await AppHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
            ).timeout(const Duration(seconds: 3));
            if (ipRes.statusCode == 200) {
              ipData = jsonDecode(ipRes.body) as Map<String, dynamic>;
            }
          } catch (_) {}
        }

        if (ipData != null) {
          // Prefer ISO 2-letter code; fall back to full name only as last resort.
          country =
              ipData['country_code']?.toString() ??
              ipData['country_name']?.toString() ??
              ipData['country']?.toString();
          // Fill city/state only if Google People did not supply them.
          city ??= ipData['city']?.toString();
          state ??= ipData['region']?.toString();
          // Build location string only if Google People had nothing.
          if (location == null || location.isEmpty) {
            final parts = [city, state, country]
                .where((s) => s != null && s.isNotEmpty)
                .toList();
            if (parts.isNotEmpty) {
              location = parts.join(', ');
              isApproximate = true;
            }
          }
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'AuthGoogleSignInProvider.ipLookup',
        );
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
        tag: 'AuthGoogleSignInProvider.fetchGooglePeople',
      );
    }
    return {};
  }

  /// Retries Google Sign-In with exponential backoff on transient network faults.
  Future<UserCredential> retryGoogleSignIn(
    FirebaseAuth auth, {
    int maxRetries = 2,
  }) async {
    var attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      try {
        return await signInWithGoogle(auth);
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

  /// Re-authenticates an existing user via Google provider to ensure fresh tokens
  /// before sensitive operations (such as account deletion).
  Future<UserCredential> reauthenticateWithGoogle(
    User user, {
    @visibleForTesting bool? isWasmOverride,
  }) async {
    try {
      if (kIsWeb) {
        if (Firebase.apps.isNotEmpty) {
          try {
            await FirebaseAppCheck.instance
                .getToken()
                .timeout(const Duration(seconds: 3));
          } catch (_) {}
        }

        final provider = GoogleAuthProvider();
        provider.addScope('https://www.googleapis.com/auth/userinfo.email');
        provider.addScope('https://www.googleapis.com/auth/userinfo.profile');
        provider.setCustomParameters({'prompt': 'select_account'});

        try {
          return await user.reauthenticateWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request') {
            throw const GoogleSignInException(
              message: 'Re-authentication was cancelled.',
              code: 'user-cancelled',
              isRetryable: true,
            );
          }
          if (e.code == 'popup-blocked' ||
              e.code == 'operation-not-supported-in-this-environment') {
            try {
              final box = GetStorage();
              box.write('auth_pending_redirect', true);
              box.write(
                'auth_pending_redirect_time',
                DateTime.now().millisecondsSinceEpoch,
              );
            } catch (_) {}

            await user.reauthenticateWithRedirect(provider);
            throw const GoogleSignInException(
              message: 'Redirecting to Google Sign-In...',
              code: 'redirecting',
            );
          }
          rethrow;
        }
      } else {
        await initialize();
        try {
          await googleSignIn.signOut();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AuthGoogleSignInProvider.reauthSignOut',
          );
        }

        final googleUser = await googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null || idToken.isEmpty) {
          throw const GoogleSignInException(
            message: 'Unable to retrieve Google credentials for re-authentication.',
            code: 'missing-id-token',
            isRetryable: true,
          );
        }

        String? accessToken;
        try {
          final authz = await googleUser.authorizationClient.authorizationForScopes([
            'openid',
            'email',
            'profile',
          ]);
          accessToken = authz?.accessToken;
        } catch (_) {}

        final credential = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );
        return await user.reauthenticateWithCredential(credential);
      }
    } catch (e, st) {
      final mapped = GoogleSignInExceptionHandler.from(e);
      if (mapped.code == 'user-cancelled' || mapped.code == 'redirecting') {
        if (kDebugMode) {
          debugPrint('ℹ️ [GoogleSignIn] Re-authentication event: ${mapped.message}');
        }
      } else {
        ErrorHandler.log(
          e,
          stackTrace: st,
          tag: 'AuthGoogleSignInProvider.reauthenticateWithGoogle',
        );
      }
      throw mapped;
    }
  }

  /// Signs out from Google Sign-In SDK.
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('AuthGoogleSignInProvider.signOut non-fatal error: $e');
      }
    }
  }
}
