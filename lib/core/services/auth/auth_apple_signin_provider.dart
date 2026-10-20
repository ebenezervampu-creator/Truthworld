import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';

/// Manages Apple Sign-In SDK integration across Web, iOS, macOS, and Android.
class AuthAppleSignInProvider {
  bool _isSigningIn = false;

  /// Initiates Apple Sign-In flow across platforms with sanitized error handling.
  Future<UserCredential> signInWithApple(FirebaseAuth auth) async {
    if (_isSigningIn) {
      debugPrint('AuthAppleSignInProvider: Apple sign-in is already in progress.');
      throw const AppleSignInException(
        message: 'Sign-in is already in progress.',
        userMessage: 'Sign-in is already in progress. Please wait a moment.',
        code: 'in-progress',
      );
    }
    _isSigningIn = true;

    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      if (kIsWeb) {
        if (Firebase.apps.isNotEmpty) {
          try {
            await FirebaseAppCheck.instance
                .getToken()
                .timeout(const Duration(seconds: 3));
          } catch (_) {}
        }
        if (kIsWasm) {
          debugPrint('AuthAppleSignInProvider: WebAssembly detected. Initiating signInWithRedirect.');
          await auth.signInWithRedirect(appleProvider);
          throw const AppleSignInException(
            message: 'Redirecting to Apple Sign-In...',
            userMessage: 'Redirecting to Apple Sign-In...',
            code: 'redirecting',
          );
        }
        return await auth.signInWithPopup(appleProvider);
      } else {
        return await auth.signInWithProvider(appleProvider);
      }
    } catch (e, st) {
      final mapped = _mapAppleAuthException(e, st);
      if (mapped.code == 'user-cancelled' || mapped.code == 'redirecting') {
        if (kDebugMode) {
          debugPrint('ℹ️ [AppleSignIn] Event: ${mapped.message}');
        }
      } else {
        ErrorHandler.log(
          e,
          stackTrace: st,
          tag: 'AuthAppleSignInProvider.signInWithApple',
        );
      }
      throw mapped;
    } finally {
      _isSigningIn = false;
    }
  }

  /// Re-authenticates user with Apple provider before sensitive operations.
  Future<UserCredential> reauthenticateWithApple(User user) async {
    final appleProvider = AppleAuthProvider();
    appleProvider.addScope('email');
    appleProvider.addScope('name');

    if (kIsWeb) {
      if (kIsWasm) {
        await user.reauthenticateWithRedirect(appleProvider);
        throw const AppleSignInException(
          message: 'Redirecting to Apple Sign-In...',
          userMessage: 'Redirecting to Apple Sign-In...',
          code: 'redirecting',
        );
      }
      return user.reauthenticateWithPopup(appleProvider);
    } else {
      return user.reauthenticateWithProvider(appleProvider);
    }
  }

  AppleSignInException _mapAppleAuthException(dynamic exception, StackTrace st) {
    final str = exception.toString().toLowerCase();

    if (str.contains('canceled') ||
        str.contains('cancelled') ||
        str.contains('popup_closed_by_user') ||
        str.contains('popup has been closed') ||
        str.contains('web-context-cancelled') ||
        str.contains('user-cancelled')) {
      return AppleSignInException(
        message: 'User cancelled Apple Sign-In.',
        userMessage: 'Sign-in was cancelled.',
        code: 'user-cancelled',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('popup-blocked')) {
      return AppleSignInException(
        message: 'Popup was blocked by your browser.',
        userMessage:
            'Sign-in popup was blocked. Please allow popups and try again.',
        code: 'popup-blocked',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('account-exists-with-different-credential') ||
        str.contains('credential-already-in-use')) {
      return AppleSignInException(
        message: 'Account exists with different credential.',
        userMessage:
            'An account already exists with this email using another sign-in method. Please sign in with your original provider.',
        code: 'account-exists',
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('network-request-failed') ||
        str.contains('socketexception')) {
      return AppleSignInException(
        message: 'Network error during Apple sign-in.',
        userMessage:
            'Unable to connect. Please check your internet connection and try again.',
        code: 'network-error',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (exception is FirebaseAuthException) {
      switch (exception.code) {
        case 'user-cancelled':
        case 'cancelled-popup-request':
        case 'popup-closed-by-user':
          return AppleSignInException(
            message: 'Sign-in was cancelled.',
            userMessage: 'Sign-in was cancelled.',
            code: 'user-cancelled',
            isRetryable: true,
            originalException: exception,
            stackTrace: st,
          );
        case 'operation-not-allowed':
          return AppleSignInException(
            message: 'Apple Sign-In is not enabled.',
            userMessage:
                'Apple sign-in is currently unavailable. Please try another sign-in method.',
            code: 'operation-not-allowed',
            originalException: exception,
            stackTrace: st,
          );
        case 'invalid-credential':
          return AppleSignInException(
            message: 'Invalid Apple credentials.',
            userMessage:
                'Authentication credentials could not be verified. Please try again.',
            code: 'invalid-credential',
            isRetryable: true,
            originalException: exception,
            stackTrace: st,
          );
      }
    }

    return AppleSignInException(
      message: 'Apple sign-in failed.',
      userMessage: 'Unable to sign in with Apple. Please try again.',
      code: 'apple-signin-failed',
      isRetryable: true,
      originalException: exception,
      stackTrace: st,
    );
  }
}
