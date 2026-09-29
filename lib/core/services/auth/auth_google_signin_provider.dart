import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// Initializes the Google Sign-In plugin with the platform client id.
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        debugPrint(
          'AuthGoogleSignInProvider: Web platform detected. Skipping explicit GoogleSignIn initialization.',
        );
      } else {
        await googleSignIn.initialize(
          serverClientId:
              '768266102263-f1bou7fgaqn2rkqh0cn5p6voksb163qt.apps.googleusercontent.com',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthGoogleSignInProvider.initialize',
      );
    }
  }

  /// Initiates Google Sign-In flow across platforms with sanitized error handling.
  Future<UserCredential> signInWithGoogle(FirebaseAuth auth) async {
    try {
      return kIsWeb
          ? await signInWithGoogleWeb(auth)
          : await signInWithGoogleMobile(auth);
    } catch (e, st) {
      final mapped = GoogleSignInExceptionHandler.from(e);
      if (mapped.code == 'user-cancelled') {
        if (kDebugMode) {
          debugPrint('ℹ️ [GoogleSignIn] Sign-in cancelled by user.');
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

  /// Web popup authentication flow with required scopes.
  Future<UserCredential> signInWithGoogleWeb(FirebaseAuth auth) async {
    final provider = GoogleAuthProvider();
    provider.addScope('https://www.googleapis.com/auth/userinfo.email');
    provider.addScope('https://www.googleapis.com/auth/userinfo.profile');
    provider.addScope('https://www.googleapis.com/auth/user.addresses.read');
    provider.setCustomParameters({'prompt': 'select_account'});

    return auth.signInWithPopup(provider);
  }

  /// Mobile Google Sign-In flow using GoogleSignInAccount credentials.
  Future<UserCredential> signInWithGoogleMobile(FirebaseAuth auth) async {
    try {
      await googleSignIn.signOut();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthGoogleSignInProvider.mobileSignOut',
      );
    }

    final googleUser = await googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;

    // Fetch location from Google People API if accessible
    lastGooglePeopleData = await fetchGooglePeopleData(googleUser);

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return auth.signInWithCredential(credential);
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
  Future<UserCredential> reauthenticateWithGoogle(User user) async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('https://www.googleapis.com/auth/userinfo.email');
        provider.addScope('https://www.googleapis.com/auth/userinfo.profile');
        provider.setCustomParameters({'prompt': 'select_account'});
        return await user.reauthenticateWithPopup(provider);
      } else {
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
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        return await user.reauthenticateWithCredential(credential);
      }
    } catch (e, st) {
      final mapped = GoogleSignInExceptionHandler.from(e);
      if (mapped.code == 'user-cancelled') {
        if (kDebugMode) {
          debugPrint('ℹ️ [GoogleSignIn] Re-authentication cancelled by user.');
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
      await googleSignIn.signOut();
    }
  }
}
