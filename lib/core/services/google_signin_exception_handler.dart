import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart'
    show
        GoogleSignInException,
        GoogleSignInFailedException,
        GoogleSignInUserCancelledException;

/// A utility class that converts raw Firebase and Platform exceptions
/// into structured [GoogleSignInException] instances with consistent codes,
/// messages, and retry recommendations.
///
/// Example:
/// ```dart
/// try {
///   await signInWithGoogle();
/// } catch (e, st) {
///   final mapped = GoogleSignInExceptionHandler.from(e);
///   GoogleSignInExceptionHandler.log(mapped, stackTrace: st);
///   throw mapped;
/// }
/// ```
final class GoogleSignInExceptionHandler {
  const GoogleSignInExceptionHandler._();

  /// Maps [exception] to a [GoogleSignInException].
  /// Handles FirebaseAuthException, GoogleSignInUserCancelledException,
  /// GoogleSignInFailedException, and generic errors.
  static GoogleSignInException from(
    dynamic exception,
  ) {
    final str = exception.toString().toLowerCase();
    if (str.contains('canceled') ||
        str.contains('cancelled') ||
        str.contains('popup_closed_by_user') ||
        str.contains('popup has been closed') ||
        str.contains('account reauth failed')) {
      return const GoogleSignInException(
        message: 'Sign-in was cancelled.',
        code: 'user-cancelled',
        isRetryable: true,
      );
    }

    return switch (exception) {
      final FirebaseAuthException e => _fromFirebaseAuth(e),
      final PlatformException e => _fromPlatformException(e),
      final GoogleSignInUserCancelledException e => _fromUserCancelled(e),
      final GoogleSignInFailedException e => _fromGoogleSignInFailed(e),
      _ => GoogleSignInException(
        message: 'An unexpected error occurred: $exception',
        code: 'unknown',
        isRetryable: true,
        originalException: exception,
      ),
    };
  }

  /// Logs the [exception] with an optional [stackTrace].
  static void log(GoogleSignInException exception, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (exception.code == 'user-cancelled') {
        debugPrint('ℹ️ [GoogleSignIn/user-cancelled] ${exception.message}');
      } else {
        debugPrint('❌ [GoogleSignIn/${exception.code}] ${exception.message}');
        if (stackTrace != null) {
          debugPrint(stackTrace.toString());
        }
      }
    }
  }

  static GoogleSignInException _fromFirebaseAuth(FirebaseAuthException e) {
    return switch (e.code) {
      'popup-closed-by-user' ||
      'cancelled-popup-request' => const GoogleSignInException(
        message: 'Sign-in was cancelled.',
        code: 'user-cancelled',
        isRetryable: true,
      ),
      'account-exists-with-different-credential' => GoogleSignInException(
        message:
            'This email is already associated with another sign-in method.',
        code: e.code,
        originalException: e,
      ),
      'internal-error' => GoogleSignInException(
        message:
            'Internal Firebase error. Please verify that Google Sign-In is enabled in your Firebase Console and your SHA-1/SHA-256 fingerprints are correctly configured.',
        code: e.code,
        isRetryable: true,
        originalException: e,
      ),
      'invalid-credential' => GoogleSignInException(
        message: 'The Google credential is no longer valid.',
        code: e.code,
        isRetryable: true,
        originalException: e,
      ),
      'operation-not-allowed' => GoogleSignInException(
        message: 'Google Sign-In is not enabled for this project.',
        code: e.code,
        originalException: e,
      ),
      'user-disabled' => GoogleSignInException(
        message: 'This user account has been disabled.',
        code: e.code,
        originalException: e,
      ),
      'invalid-email' => GoogleSignInException(
        message: 'The email address is invalid.',
        code: e.code,
        originalException: e,
      ),
      'too-many-requests' => GoogleSignInException(
        message: 'Too many requests. Please try again later.',
        code: e.code,
        originalException: e,
      ),
      'network-request-failed' => GoogleSignInException(
        message: 'Network error. Please check your connection.',
        code: e.code,
        isRetryable: true,
        originalException: e,
      ),
      _ => GoogleSignInException(
        message: e.message ?? 'Authentication failed [${e.code}]',
        code: e.code,
        isRetryable: true,
        originalException: e,
      ),
    };
  }

  static GoogleSignInException _fromUserCancelled(
    GoogleSignInUserCancelledException e,
  ) {
    return GoogleSignInException(
      message: 'Sign-in was cancelled.',
      code: 'user-cancelled',
      isRetryable: true,
      originalException: e,
    );
  }

  static GoogleSignInException _fromGoogleSignInFailed(
    GoogleSignInFailedException e,
  ) {
    final message = e.message?.toLowerCase() ?? '';

    if (message.contains('network')) {
      return GoogleSignInException(
        message: 'Network error during Google Sign-In.',
        code: 'network-error',
        isRetryable: true,
        originalException: e,
      );
    }

    if (message.contains('popup_closed_by_user')) {
      return GoogleSignInException(
        message: 'Sign-in popup was closed before completion.',
        code: 'popup-closed',
        isRetryable: true,
        originalException: e,
      );
    }

    return GoogleSignInException(
      message: e.message ?? 'Google Sign-In failed.',
      code: 'sign-in-failed',
      isRetryable: true,
      originalException: e,
    );
  }

  static GoogleSignInException _fromPlatformException(PlatformException e) {
    if (e.code == 'CANCELED' || e.code == 'sign_in_canceled') {
      return GoogleSignInException(
        message: 'Sign-in was cancelled by the user.',
        code: 'user-cancelled',
        isRetryable: true,
        originalException: e,
      );
    }

    if (e.code == 'NETWORK_ERROR') {
      return GoogleSignInException(
        message: 'Network error during sign-in. Please check your connection.',
        code: 'network-error',
        isRetryable: true,
        originalException: e,
      );
    }

    return GoogleSignInException(
      message: e.message ?? 'Google Sign-In failed [${e.code}]',
      code: e.code,
      isRetryable: true,
      originalException: e,
    );
  }
}
