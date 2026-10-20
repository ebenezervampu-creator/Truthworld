import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';

/// Base repository providing standardized execution, retry policies, offline checks,
/// defensive Firestore operations (`safeSet`, `safeUpdate`, `safeDelete`),
/// and safe `Result<T>` mapping for all data layer implementations.
abstract class BaseRepository {
  final bool isTestMode;
  BaseRepository({bool? isTestMode})
      : isTestMode = isTestMode ?? _defaultIsTestMode;

  static bool get _defaultIsTestMode {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {
      // Platform.environment might throw on unsupported platforms
    }
    return false;
  }

  /// Execute an async data fetch task safely, transforming any thrown exceptions into a `Failure<T>`
  Future<Result<T>> safeFetch<T>(
    Future<T> Function() fetchTask, {
    int maxRetries = 0,
    Duration retryDelay = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final effectiveTimeout =
        isTestMode ? const Duration(milliseconds: 100) : timeout;
    var attempts = 0;
    while (true) {
      attempts++;
      try {
        final data = await fetchTask().timeout(
          effectiveTimeout,
          onTimeout: () => throw AppTimeoutException(
            code: 'timeout',
            message:
                'Operation timed out after ${effectiveTimeout.inSeconds} seconds',
          ),
        );
        return Result.success(data);
      } catch (e, stackTrace) {
        final appException = AppException.from(e, stackTrace);
        if (attempts <= maxRetries && appException.isRetryable) {
          debugPrint(
            '🟡 [Repository Retry] Attempt $attempts/$maxRetries for [${appException.code}]',
          );
          // Exponential backoff with randomized jitter to prevent thundering herd
          final baseBackoffMs = retryDelay.inMilliseconds * (1 << min(attempts - 1, 6));
          final cappedBackoffMs = min(baseBackoffMs, 10000); // 10s max cap
          final jitterMs = Random().nextInt(max(1, (cappedBackoffMs * 0.25).toInt()));
          final delayDuration = Duration(milliseconds: cappedBackoffMs + jitterMs);
          await Future.delayed(delayDuration);
          continue;
        }
        debugPrint(
          '🔴 [Repository Exception] [${appException.code}]: ${appException.message}',
        );
        return Result.failure(appException);
      }
    }
  }

  /// Defensive set operation merging fields by default to prevent non-existent document errors
  Future<Result<void>> safeSet(
    DocumentReference ref,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    return safeFetch(() async {
      await ref.set(data, SetOptions(merge: merge));
    });
  }

  /// Alias for [safeSet] to handle safe document creation/saving
  Future<Result<void>> safeSave(
    DocumentReference ref,
    Map<String, dynamic> data, {
    bool merge = true,
  }) =>
      safeSet(ref, data, merge: merge);

  /// Defensive update operation wrapped in exception handling
  Future<Result<void>> safeUpdate(
    DocumentReference ref,
    Map<String, dynamic> data,
  ) async {
    return safeFetch(() async {
      try {
        await ref.update(data);
      } on FirebaseException catch (e) {
        if (e.code == 'not-found') {
          // Automatic fallback to set with merge if document was not found
          await ref.set(data, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }
    });
  }

  /// Defensive document delete operation
  Future<Result<void>> safeDelete(DocumentReference ref) async {
    return safeFetch(() async {
      await ref.delete();
    });
  }

  /// Safe transaction execution with automatic exception mapping
  Future<Result<T>> safeTransaction<T>(
    Future<T> Function(Transaction tx) transactionHandler,
  ) async {
    return safeFetch(() async {
      return FirebaseFirestore.instance.runTransaction(transactionHandler);
    });
  }

  bool _isRetryable(AppException exception) {
    if (exception is NetworkException) return true;
    if (exception is TimeoutException) return true;
    if (exception is AuthException) return exception.isRetryable;
    return false;
  }
}
