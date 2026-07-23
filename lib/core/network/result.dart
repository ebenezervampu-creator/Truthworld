import 'package:truthworld/core/exceptions/app_exceptions.dart';

/// Strongly typed result model representing either a successful result with data [T]
/// or a failure containing an [AppException].
/// Prevents raw exception throwing across architectural layers.
abstract class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(AppException exception) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  AppException? get exceptionOrNull => isFailure ? (this as Failure<T>).exception : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else {
      return failure((this as Failure<T>).exception);
    }
  }

  R fold<R>(
    R Function(AppException exception) onFailure,
    R Function(T data) onSuccess,
  ) {
    if (this is Success<T>) {
      return onSuccess((this as Success<T>).data);
    } else {
      return onFailure((this as Failure<T>).exception);
    }
  }
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

class Failure<T> extends Result<T> {
  const Failure(this.exception);
  final AppException exception;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          exception == other.exception;

  @override
  int get hashCode => exception.hashCode;
}
