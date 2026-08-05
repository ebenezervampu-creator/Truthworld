import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/base/base_controller.dart';

class TestViewController extends BaseController {
  void updateState(ViewState newState) {
    setViewState(newState);
  }
}

void main() {
  group('ViewState Transitions Tests', () {
    late TestViewController controller;

    setUp(() {
      controller = TestViewController();
    });

    test('initial state is idle', () {
      expect(controller.state, equals(ViewState.idle));
    });

    test('idle -> loading -> success transition', () {
      controller.updateState(ViewState.loading);
      expect(controller.isLoading, isTrue);
      expect(controller.state, equals(ViewState.loading));

      controller.updateState(ViewState.success);
      expect(controller.isSuccess, isTrue);
      expect(controller.state, equals(ViewState.success));
    });

    test('idle -> loading -> error transition', () {
      controller.updateState(ViewState.loading);
      expect(controller.isLoading, isTrue);

      controller.setError('Something went wrong');
      expect(controller.isError, isTrue);
      expect(controller.state, equals(ViewState.error));
      expect(controller.errorMessage, equals('Something went wrong'));
    });

    test('idle -> loading -> empty transition', () {
      controller.updateState(ViewState.loading);
      expect(controller.isLoading, isTrue);

      controller.updateState(ViewState.empty);
      expect(controller.isEmpty, isTrue);
      expect(controller.state, equals(ViewState.empty));
    });
  });
}
