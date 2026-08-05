import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';

void main() {
  group('Result Class Tests', () {
    test('Result.success creation and properties', () {
      final result = Result.success('Hello World');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals('Hello World'));
      expect(result.exceptionOrNull, isNull);
    });

    test('Result.failure creation and properties', () {
      const exception = GenericAppException(message: 'Error');
      final result = Result<String>.failure(exception);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.exceptionOrNull, equals(exception));
    });

    test('when() dispatching for success', () {
      final result = Result.success(42);

      final value = result.when(
        success: (data) => data.toString(),
        failure: (exception) => 'Error',
      );

      expect(value, equals('42'));
    });

    test('when() dispatching for failure', () {
      const exception = GenericAppException(message: 'Failed');
      final result = Result<int>.failure(exception);

      final value = result.when(
        success: (data) => data.toString(),
        failure: (e) => e.message,
      );

      expect(value, equals('Failed'));
    });

    test('fold() equivalence for success', () {
      final result = Result.success(100);

      final value = result.fold(
        (e) => -1,
        (data) => data * 2,
      );

      expect(value, equals(200));
    });

    test('fold() equivalence for failure', () {
      const exception = GenericAppException(message: 'Failed');
      final result = Result<int>.failure(exception);

      final value = result.fold(
        (e) => -1,
        (data) => data * 2,
      );

      expect(value, equals(-1));
    });
  });
}
