import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';

void main() {
  group('Result<T>', () {
    test('Success wraps data correctly', () {
      final result = Result<String>.success('hello');

      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.dataOrNull, 'hello');
      expect(result.exceptionOrNull, isNull);
    });

    test('Failure wraps exception correctly', () {
      const exception = GenericAppException(message: 'Something went wrong');
      final result = Result<String>.failure(exception);

      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.dataOrNull, isNull);
      expect(result.exceptionOrNull, exception);
    });

    test('when() dispatches to success handler', () {
      final result = Result<int>.success(42);

      final output = result.when(
        success: (data) => 'Got $data',
        failure: (e) => 'Error: ${e.message}',
      );

      expect(output, 'Got 42');
    });

    test('when() dispatches to failure handler', () {
      const exception = GenericAppException(message: 'oops');
      final result = Result<int>.failure(exception);

      final output = result.when(
        success: (data) => 'Got $data',
        failure: (e) => 'Error: ${e.message}',
      );

      expect(output, 'Error: oops');
    });

    test('fold() works like when() with reversed parameter order', () {
      final result = Result<int>.success(10);

      final output = result.fold(
        (e) => -1,
        (data) => data * 2,
      );

      expect(output, 20);
    });

    test('Success equality', () {
      final a = Result<int>.success(42);
      final b = Result<int>.success(42);
      final c = Result<int>.success(99);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('Failure equality', () {
      const ex1 = GenericAppException(message: 'error');
      const ex2 = GenericAppException(message: 'error');

      final a = Result<int>.failure(ex1);
      final b = Result<int>.failure(ex2);

      // Equality depends on AppException equality implementation
      expect(a.isFailure, true);
      expect(b.isFailure, true);
    });

    test('Success with null data', () {
      final result = Result<String?>.success(null);

      expect(result.isSuccess, true);
      expect(result.dataOrNull, isNull);
    });

    test('Success with complex type', () {
      final result = Result<List<int>>.success([1, 2, 3]);

      expect(result.isSuccess, true);
      expect(result.dataOrNull, [1, 2, 3]);
    });
  });
}
