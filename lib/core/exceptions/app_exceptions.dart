import 'package:cloud_firestore/cloud_firestore.dart';

/// TimeoutException custom wrapper for async cancellation
class TimeoutException implements Exception {
  final String message;
  final dynamic originalException;

  const TimeoutException({required this.message, this.originalException});

  @override
  String toString() => 'TimeoutException: $message';
}

/// Custom Exception wrapper for cloud Firestore errors
class FirestoreException implements Exception {
  final String message;
  final dynamic originalException;

  const FirestoreException({required this.message, this.originalException});

  /// Factory function to parse from basic FirebaseException instances
  factory FirestoreException.fromFirebase(FirebaseException e) {
    return FirestoreException(
      message: e.message ?? 'An unknown Firestore error occurred [${e.code}]',
      originalException: e,
    );
  }

  @override
  String toString() => 'FirestoreException: $message';
}

/// Custom Exception wrapper for validation errors
class ValidationException implements Exception {
  final String message;
  final dynamic originalException;

  const ValidationException({required this.message, this.originalException});

  @override
  String toString() => 'ValidationException: $message';
}

/// Custom Exception wrapper for authentication errors
class AuthException implements Exception {
  final String message;
  final dynamic originalException;
  final String code;
  final bool isRetryable;

  const AuthException({
    required this.message,
    this.originalException,
    this.code = 'auth-error',
    this.isRetryable = false,
  });

  /// Get user-friendly display message
  String getDisplayMessage() {
    switch (code) {
      case 'network-error':
        return 'Network error. Please check your connection and try again.';
      case 'timeout':
        return 'Sign-in took too long. Please try again.';
      case 'user-cancelled':
        return 'Sign-in was cancelled. Please try again.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked. Please allow popups and try again.';
      case 'invalid-account':
        return 'This account is not valid. Please use a different account.';
      case 'account-exists-different-credential':
        return 'An account already exists with this email but different sign-in method.';
      case 'account-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'too-many-requests':
        return 'Too many sign-in attempts. Please try again later.';
      case 'firestore-error':
        return 'Failed to create user profile. Please try again.';
      default:
        return 'An error occurred during sign-in: $message';
    }
  }

  @override
  String toString() => 'AuthException [$code]: $message';
}

/// Custom Exception wrapper for Google Sign-In errors
class GoogleSignInException extends AuthException {
  const GoogleSignInException({
    required super.message,
    super.originalException,
    super.code = 'google-signin-error',
    super.isRetryable = false,
  });
}

/// Thrown when the user cancels the Google Sign-In flow.
class GoogleSignInUserCancelledException implements Exception {
  final String message;
  const GoogleSignInUserCancelledException([
    this.message = 'User cancelled sign-in',
  ]);
  @override
  String toString() => 'GoogleSignInUserCancelledException: $message';
}

/// Thrown when Google Sign-In fails due to technical reasons.
class GoogleSignInFailedException implements Exception {
  final String? message;
  const GoogleSignInFailedException([this.message]);
  @override
  String toString() =>
      'GoogleSignInFailedException: ${message ?? "Unknown error"}';
}


/// Custom Exception wrapper for user profile errors
class UserProfileException implements Exception {
  final String message;
  final dynamic originalException;
  final String? userId;

  const UserProfileException({
    required this.message,
    this.originalException,
    this.userId,
  });

  @override
  String toString() => 'UserProfileException: $message';
}





