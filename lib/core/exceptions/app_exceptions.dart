import 'package:cloud_firestore/cloud_firestore.dart';

/// Base class for all application-specific exceptions
abstract class AppException implements Exception {

  const AppException(this.message, [this.originalException]);
  final String message;
  final dynamic originalException;

  @override
  String toString() => '$runtimeType: $message';
}

/// TimeoutException custom wrapper for async cancellation
class TimeoutException extends AppException {
  const TimeoutException({required String message, dynamic originalException})
      : super(message, originalException);
}

/// Custom Exception wrapper for cloud Firestore errors
class FirestoreException extends AppException {
  const FirestoreException({required String message, dynamic originalException})
      : super(message, originalException);

  /// Factory function to parse from basic FirebaseException instances
  factory FirestoreException.fromFirebase(FirebaseException e) {
    return FirestoreException(
      message: e.message ?? 'An unknown Firestore error occurred [${e.code}]',
      originalException: e,
    );
  }
}

/// Custom Exception wrapper for validation errors
class ValidationException extends AppException {
  const ValidationException({required String message, dynamic originalException})
      : super(message, originalException);
}

/// Custom Exception wrapper for network errors
class NetworkException extends AppException {
  const NetworkException({required String message, dynamic originalException})
      : super(message, originalException);
}

/// Custom Exception wrapper for generic errors
class GenericAppException extends AppException {
  const GenericAppException({required String message, dynamic originalException})
      : super(message, originalException);
}

/// Custom Exception wrapper for authentication errors
class AuthException extends AppException {

  const AuthException({
    required String message,
    dynamic originalException,
    this.code = 'auth-error',
    this.isRetryable = false,
  }) : super(message, originalException);
  final String code;
  final bool isRetryable;

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
  const GoogleSignInUserCancelledException([
    this.message = 'User cancelled sign-in',
  ]);
  final String message;
  @override
  String toString() => 'GoogleSignInUserCancelledException: $message';
}

/// Thrown when Google Sign-In fails due to technical reasons.
class GoogleSignInFailedException implements Exception {
  const GoogleSignInFailedException([this.message]);
  final String? message;
  @override
  String toString() =>
      'GoogleSignInFailedException: ${message ?? "Unknown error"}';
}

/// Thrown when an asynchronous operation is cancelled by the user or system.
class OperationCancelledException extends AppException {
  const OperationCancelledException([super.message = 'Operation was cancelled']);
}

/// Custom Exception wrapper for user profile errors
class UserProfileException extends AppException {

  const UserProfileException({
    required String message,
    dynamic originalException,
    this.userId,
  }) : super(message, originalException);
  final String? userId;
}

class FriendlyErrorTranslator {
  static String getFriendlyMessage(Object error, {String? defaultActionMessage}) {
    final action = defaultActionMessage != null ? ' to $defaultActionMessage' : '';
    if (error is AuthException) {
      return error.getDisplayMessage();
    } else if (error is FirestoreException) {
      return 'Database error: ${error.message}';
    } else if (error is ValidationException) {
      return error.message;
    } else {
      return 'Failed$action. Please check your network and try again.';
    }
  }
}
