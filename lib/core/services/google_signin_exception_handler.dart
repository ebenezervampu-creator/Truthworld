import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:truthworld/core/errors/error_handler.dart';
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
    if (exception is gsi.GoogleSignInException) {
      switch (exception.code) {
        case gsi.GoogleSignInExceptionCode.canceled:
          return const GoogleSignInException(
            message: 'Sign-in was cancelled.',
            code: 'user-cancelled',
            isRetryable: true,
          );
        case gsi.GoogleSignInExceptionCode.clientConfigurationError:
        case gsi.GoogleSignInExceptionCode.providerConfigurationError:
          return GoogleSignInException(
            message:
                'Google Sign-In configuration error. Please verify the SHA-1 fingerprint and package configuration in Firebase Console.',
            code: 'configuration-error',
            originalException: exception,
          );
        case gsi.GoogleSignInExceptionCode.uiUnavailable:
          return GoogleSignInException(
            message: 'Google Sign-In screen could not be displayed. Please try again.',
            code: 'ui-unavailable',
            isRetryable: true,
            originalException: exception,
          );
        case gsi.GoogleSignInExceptionCode.interrupted:
          return GoogleSignInException(
            message: 'Google Sign-In was interrupted. Please try again.',
            code: 'interrupted',
            isRetryable: true,
            originalException: exception,
          );
        default:
          return GoogleSignInException(
            message: exception.description?.isNotEmpty == true
                ? exception.description!
                : 'Google Sign-In encountered an error. Please try again.',
            code: 'sign-in-failed',
            isRetryable: true,
            originalException: exception,
          );
      }
    }

    final str = exception.toString().toLowerCase();
    if (str.contains('redirecting')) {
      return const GoogleSignInException(
        message: 'Redirecting to Google Sign-In...',
        code: 'redirecting',
      );
    }

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

    if (str.contains('app check') ||
        str.contains('appcheck') ||
        str.contains('app-check') ||
        str.contains('app attestation')) {
      return GoogleSignInException(
        message:
            'Device security verification failed. Please check your connection and try again.',
        code: 'app-check-failed',
        isRetryable: true,
        originalException: exception,
      );
    }

    return switch (exception) {
      final FirebaseAuthException e => _fromFirebaseAuth(e),
      final PlatformException e => _fromPlatformException(e),
      final GoogleSignInUserCancelledException e => _fromUserCancelled(e),
      final GoogleSignInFailedException e => _fromGoogleSignInFailed(e),
      _ => () {
            ErrorHandler.log(exception, context: 'GoogleSignInExceptionHandler.fromUnknown');
            return GoogleSignInException(
              message: 'An unexpected error occurred during sign-in. Please try again.',
              code: 'unknown',
              isRetryable: true,
              originalException: exception,
            );
          }(),
    };
  }

  /// Logs the [exception] with an optional [stackTrace].
  static void log(GoogleSignInException exception, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (exception.code == 'user-cancelled' || exception.code == 'redirecting') {
        debugPrint('ℹ️ [GoogleSignIn/${exception.code}] ${exception.message}');
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
      'popup-blocked' => const GoogleSignInException(
        message: 'Popup was blocked by your browser. Please allow popups for this site.',
        code: 'popup-blocked',
        isRetryable: true,
      ),
      'unauthorized-domain' => GoogleSignInException(
        message:
            'This domain is not authorized for Google Sign-In. Please add your domain to Firebase Console -> Authentication -> Authorized domains.',
        code: e.code,
        originalException: e,
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
        userMessage:
            'Unable to connect to Google authentication services. Please check your connection and try again.',
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
      _ => _mapFallbackAuthException(e),
    };
  }

  static GoogleSignInException _mapFallbackAuthException(
    FirebaseAuthException e,
  ) {
    final rawMsg = e.message ?? '';
    final lower = rawMsg.toLowerCase();

    if (lower.contains('app check') ||
        lower.contains('appcheck') ||
        lower.contains('app-check') ||
        lower.contains('app attestation')) {
      return GoogleSignInException(
        message:
            'Device security verification failed. Please check your connection and try again.',
        code: 'app-check-failed',
        isRetryable: true,
        originalException: e,
      );
    }

    if (lower.contains('internal error') || e.code == 'unknown') {
      return GoogleSignInException(
        message:
            'An unexpected authentication error occurred. Please try again.',
        code: e.code,
        isRetryable: true,
        originalException: e,
      );
    }

    return GoogleSignInException(
      message:
          rawMsg.isNotEmpty ? rawMsg : 'Authentication failed. Please try again.',
      code: e.code,
      isRetryable: true,
      originalException: e,
    );
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
    final message = e.message.toLowerCase();

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
      message: e.message,
      code: 'sign-in-failed',
      isRetryable: true,
      originalException: e,
    );
  }

  static GoogleSignInException _fromPlatformException(PlatformException e) {
    final code = e.code.toUpperCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'CANCELED' ||
        code == 'SIGN_IN_CANCELED' ||
        code == '12501' ||
        code == '16' ||
        message.contains('cancel')) {
      return GoogleSignInException(
        message: 'Sign-in was cancelled by the user.',
        userMessage: 'Sign-in was cancelled.',
        code: 'user-cancelled',
        isRetryable: true,
        originalException: e,
      );
    }

    if (code == 'NETWORK_ERROR' || code == '7' || message.contains('network')) {
      return GoogleSignInException(
        message: 'Network error during sign-in: ${e.message}',
        userMessage:
            'Network error during sign-in. Please check your internet connection and try again.',
        code: 'network-error',
        isRetryable: true,
        originalException: e,
      );
    }

    if (code == '10' ||
        code == 'DEVELOPER_ERROR' ||
        message.contains('developer_error')) {
      return GoogleSignInException(
        message: 'Google Sign-In configuration mismatch (code 10): ${e.message}',
        userMessage:
            'Google Sign-In is temporarily unavailable on this device. Please try another sign-in method.',
        code: 'developer-error',
        originalException: e,
      );
    }

    if (code == '12500' ||
        code == 'SIGN_IN_FAILED' ||
        message.contains('sign_in_failed')) {
      return GoogleSignInException(
        message: 'Google Sign-In failed (code 12500): ${e.message}',
        userMessage:
            'Unable to complete Google sign-in. Please ensure Google Play Services is updated and try again.',
        code: 'sign-in-failed',
        isRetryable: true,
        originalException: e,
      );
    }

    return GoogleSignInException(
      message: e.message ?? 'Google Sign-In failed [${e.code}]',
      userMessage: 'Unable to complete Google sign-in. Please try again.',
      code: e.code,
      isRetryable: true,
      originalException: e,
    );
  }
}
