import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/base/base_controller.dart';

class TestController extends BaseController {
  bool onCloseCalled = false;

  void triggerError(String msg) {
    setError(msg);
  }

  void triggerState(ViewState s) {
    setViewState(s);
  }

  @override
  void onClose() {
    onCloseCalled = true;
    super.onClose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BaseController Tests', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('initial state is idle', () {
      expect(controller.state, equals(ViewState.idle));
      expect(controller.isLoading, isFalse);
      expect(controller.isError, isFalse);
    });

    test('setViewState updates state correctly', () {
      controller.triggerState(ViewState.loading);
      expect(controller.state, equals(ViewState.loading));
      expect(controller.isLoading, isTrue);

      controller.triggerState(ViewState.success);
      expect(controller.state, equals(ViewState.success));
      expect(controller.isSuccess, isTrue);
    });

    test('setError sets error state and message', () {
      controller.triggerError('Network failure');
      expect(controller.state, equals(ViewState.error));
      expect(controller.isError, isTrue);
      expect(controller.errorMessage, equals('Network failure'));
    });

    test('resource tracking disposes resources on onClose', () {
      final sub = StreamController<int>().stream.listen((_) {});
      final timer = Timer(const Duration(seconds: 10), () {});
      final textCtrl = TextEditingController();
      final scrollCtrl = ScrollController();

      controller.trackSubscription(sub);
      controller.trackTimer(timer);
      controller.trackTextController(textCtrl);
      controller.trackScrollController(scrollCtrl);

      controller.onClose();

      expect(controller.onCloseCalled, isTrue);
    });

    test('pagination helpers work correctly', () {
      expect(controller.page, equals(1));
      expect(controller.hasMore, isTrue);

      controller.updatePagination(['item1', 'item2'], pageSize: 2);
      expect(controller.items.length, equals(2));
      expect(controller.page, equals(2));

      controller.resetPagination();
      expect(controller.page, equals(1));
      expect(controller.items, isEmpty);
      expect(controller.hasMore, isTrue);
    });
  });
}
