import 'dart:async' as async;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';

void main() {
  group('UserFeedbackSanitizer - Title Sanitization', () {
    test('returns null for forbidden and aggressive titles', () {
      expect(UserFeedbackSanitizer.sanitizeTitle('Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('ERROR'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('errors'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Developer Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Input Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Validation Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Submission Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('System Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Runtime Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Server Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Fatal Error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Failure'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Failed'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('Exception'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('internal'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('INTERNAL'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('internal error'), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('unavailable'), isNull);
    });

    test('returns null for null, empty, or whitespace titles', () {
      expect(UserFeedbackSanitizer.sanitizeTitle(null), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle(''), isNull);
      expect(UserFeedbackSanitizer.sanitizeTitle('   '), isNull);
    });

    test('strips trailing " Error" from titles', () {
      expect(
        UserFeedbackSanitizer.sanitizeTitle('Membership Error'),
        equals('Membership'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeTitle('Upload error'),
        equals('Upload'),
      );
    });

    test('strips leading "Error:" from titles', () {
      expect(
        UserFeedbackSanitizer.sanitizeTitle('Error: Verification'),
        equals('Verification'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeTitle('error: Account Setup'),
        equals('Account Setup'),
      );
    });

    test('preserves clean and friendly titles', () {
      expect(
        UserFeedbackSanitizer.sanitizeTitle('Action Required'),
        equals('Action Required'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeTitle('Notice'),
        equals('Notice'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeTitle('Connection Issue'),
        equals('Connection Issue'),
      );
    });
  });

  group('UserFeedbackSanitizer - Message Sanitization', () {
    test('handles null input with default friendly message', () {
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(null);
      expect(sanitized, equals('An unexpected issue occurred. Please try again.'));
    });

    test('strips raw Firebase error codes and converts to friendly messages', () {
      const input = 'Failed to load comments: [cloud_firestore/permission-denied] Missing or insufficient permissions.';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(input);
      expect(sanitized, equals('You do not have permission to complete this action.'));
    });

    test('handles network and socket technical exceptions cleanly', () {
      const input = 'Failed to load feed: SocketException: Failed host lookup: truthworld.app';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(input);
      expect(
        sanitized,
        equals('You appear to be offline. Please check your internet connection and try again.'),
      );
    });

    test('handles timeout exceptions cleanly', () {
      const input = 'Failed to publish video: TimeoutException: Request timed out after 30s';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(input);
      expect(
        sanitized,
        equals('The operation took too long. Please check your connection and try again.'),
      );
    });

    test('converts blunt "Failed to X" phrasing into polite standard English', () {
      const input = 'Failed to delete playlist.';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(input);
      expect(sanitized, equals('Unable to delete playlist. Please try again.'));
    });

    test('converts blunt "Could not X" phrasing into polite standard English', () {
      const input = 'Could not load channel statistics';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(input);
      expect(sanitized, equals('Unable to load channel statistics. Please try again.'));
    });

    test('sanitizes payment gateway errors', () {
      const input = 'PaymentLink_checkout_error: authentication failed';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(input);
      expect(
        sanitized,
        equals('Payment service is temporarily unavailable. Please try again in a few moments or contact support.'),
      );
    });

    test('sanitizes raw "internal" and "unavailable" errors into friendly messages', () {
      expect(
        UserFeedbackSanitizer.sanitizeMessage('internal'),
        equals('The service is temporarily unavailable. Please try again shortly.'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeMessage('internal', defaultActionContext: 'process payment'),
        equals('Unable to process payment right now. Please try again in a few moments.'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeMessage('INTERNAL', defaultActionContext: 'process payment'),
        equals('Unable to process payment right now. Please try again in a few moments.'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeMessage('unavailable', defaultActionContext: 'process payment'),
        equals('Unable to process payment right now. Please try again in a few moments.'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeMessage(
          'com.truthworld.app is not enabled or approved. Please whitelist your domain or app package name in Cashfree Merchant Dashboard',
        ),
        equals('Unable to process payment right now. Please try again shortly or contact support.'),
      );
      expect(
        UserFeedbackSanitizer.sanitizeMessage('profile_inactive'),
        equals('Payment service is temporarily unavailable. Please try again in a few moments or contact support.'),
      );
    });

    test('uses defaultActionContext when raw technical error lacks action context', () {
      const input = 'RangeError (index): Invalid value: Valid value range is empty: 0';
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(
        input,
        defaultActionContext: 'load community posts',
      );
      expect(sanitized, equals('Unable to load community posts. Please try again.'));
    });

    test('directly honors AppException displayMessage', () {
      const exception = NetworkException(
        message: 'Raw socket closed',
        userMessage: 'Custom user friendly offline notification',
      );
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(exception);
      expect(sanitized, equals('Custom user friendly offline notification'));
    });

    test('sanitizes AppException with raw internal message', () {
      const exception = ServerException(message: 'internal');
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(
        exception,
        defaultActionContext: 'join membership tier',
      );
      expect(
        sanitized,
        equals('Unable to join membership tier right now. Please try again in a few moments.'),
      );
    });

    test('sanitizes native Exception via AppException.from', () {
      const nativeException = FormatException('Unexpected character at line 1');
      final sanitized = UserFeedbackSanitizer.sanitizeMessage(nativeException);
      expect(
        sanitized,
        equals('Unable to process data due to an invalid format.'),
      );
    });
  });

  group('AppException.from Factory Mapping', () {
    test('maps SocketException to NetworkException', () {
      final exception = AppException.from(
        const SocketException('Failed host lookup'),
      );
      expect(exception, isA<NetworkException>());
      expect(exception.code, equals('NETWORK_OFFLINE'));
      expect(exception.isRetryable, isTrue);
      expect(
        exception.displayMessage,
        equals('You appear to be offline. Please check your internet connection and try again.'),
      );
    });

    test('maps TimeoutException to NetworkException', () {
      final exception = AppException.from(
        async.TimeoutException('Connection timed out'),
      );
      expect(exception, isA<NetworkException>());
      expect(exception.code, equals('NETWORK_TIMEOUT'));
      expect(exception.isRetryable, isTrue);
    });

    test('maps FormatException to ValidationException', () {
      final exception = AppException.from(
        const FormatException('Malformed JSON response'),
      );
      expect(exception, isA<ValidationException>());
      expect(exception.code, equals('DATA_FORMAT_ERROR'));
    });

    test('maps FirebaseException codes accurately', () {
      // Permission denied
      final permEx = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      expect(permEx, isA<PermissionException>());
      expect(permEx.displayMessage, equals('You do not have permission to perform this action.'));

      // Not found
      final notFoundEx = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      );
      expect(notFoundEx, isA<NotFoundException>());
      expect(notFoundEx.code, equals('RESOURCE_NOT_FOUND'));

      // Service unavailable
      final unavailEx = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      expect(unavailEx, isA<NetworkException>());
      expect(unavailEx.code, equals('SERVICE_UNAVAILABLE'));

      // Already exists
      final existsEx = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'already-exists'),
      );
      expect(existsEx, isA<ValidationException>());
      expect(existsEx.code, equals('RESOURCE_ALREADY_EXISTS'));

      // Quota exceeded
      final quotaEx = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'quota-exceeded'),
      );
      expect(quotaEx, isA<ServerException>());
      expect(quotaEx.code, equals('QUOTA_EXHAUSTED'));

      // Unauthenticated
      final unauthEx = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
      );
      expect(unauthEx, isA<AuthException>());
      expect(unauthEx.code, equals('UNAUTHENTICATED'));

      // Firebase Storage plugin
      final storageEx = AppException.from(
        FirebaseException(plugin: 'firebase_storage', code: 'object-not-found'),
      );
      expect(storageEx, isA<StorageException>());
      expect(storageEx.code, equals('STORAGE_OBJECT-NOT-FOUND'));

      // Internal / Cloud Functions plugin
      final internalEx = AppException.from(
        FirebaseException(plugin: 'cloud_functions', code: 'internal'),
      );
      expect(internalEx, isA<ServerException>());
      expect(internalEx.displayMessage, equals('The service is temporarily unavailable. Please try again in a moment.'));
    });

    test('preserves existing AppException instances without re-wrapping', () {
      const original = NotFoundException(message: 'Video not found');
      final mapped = AppException.from(original);
      expect(identical(mapped, original), isTrue);
    });

    test('maps PlatformException with ActivityNotFoundException to PlatformBridgeException', () {
      final platformEx = PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
        message: 'ActivityNotFoundException: No Activity found to handle Intent',
      );
      final mapped = AppException.from(platformEx);
      expect(mapped, isA<PlatformBridgeException>());
    });

    test('uses fallbackMessage when mapping generic unknown exceptions', () {
      final generic = Exception('Some internal runtime failure');
      final mapped = AppException.from(
        generic,
        null,
        'Could not complete video transcoding.',
      );
      expect(mapped, isA<GenericAppException>());
      expect(mapped.displayMessage, equals('Could not complete video transcoding.'));
    });
  });

  group('ErrorHandler Utilities', () {
    test('ErrorHandler.handle processes errors and returns typed AppException', () {
      final handled = ErrorHandler.handle(
        const SocketException('OS Error: Connection reset by peer'),
        showFeedback: false,
      );
      expect(handled, isA<NetworkException>());
      expect(
        handled.displayMessage,
        equals('You appear to be offline. Please check your internet connection and try again.'),
      );
    });

    test('ErrorHandler.log executes safely without throwing', () {
      expect(
        () => ErrorHandler.log(
          'Diagnostic log test',
          tag: 'UnitTest',
        ),
        returnsNormally,
      );

      expect(
        () => ErrorHandler.log(
          const SocketException('Simulated network failure'),
          stackTrace: StackTrace.current,
          tag: 'UnitTest.network',
        ),
        returnsNormally,
      );

      expect(
        () => ErrorHandler.log(null),
        returnsNormally,
      );
    });
  });
}
