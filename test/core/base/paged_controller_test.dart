import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/base/paged_controller.dart';
import 'package:truthworld/core/network/result.dart';

class TestItem {
  final String id;
  final String title;
  TestItem({required this.id, required this.title});
}

class TestPagedController extends PagedController<TestItem> {
  TestPagedController({super.pageSize = 5});

  List<TestItem> mockData = [];

  @override
  Future<Result<List<TestItem>>> fetchPageData(int page) async {
    final start = (page - 1) * pageSize;
    if (start >= mockData.length) return Result.success([]);
    final end = (start + pageSize) > mockData.length
        ? mockData.length
        : start + pageSize;
    return Result.success(mockData.sublist(start, end));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedController Tests', () {
    late TestPagedController controller;

    setUp(() {
      controller = TestPagedController();
      controller.mockData = List.generate(
        12,
        (i) => TestItem(id: '$i', title: 'Item $i'),
      );
    });

    tearDown(() {
      controller.onClose();
    });

    test('initial state and page 1 load', () async {
      expect(controller.state, equals(ViewState.idle));
      expect(controller.itemList, isEmpty);

      await controller.loadInitialData();

      expect(controller.state, equals(ViewState.success));
      expect(controller.itemList.length, equals(5));
      expect(controller.hasMoreData, isTrue);
      expect(controller.currentPage, equals(1));
    });

    test('fetchNextPage loads second page', () async {
      await controller.loadInitialData();
      await controller.fetchNextPage();

      expect(controller.itemList.length, equals(10));
      expect(controller.hasMoreData, isTrue);
      expect(controller.currentPage, equals(2));
    });

    test('fetchNextPage reaches end of pagination', () async {
      await controller.loadInitialData(); // 5 items
      await controller.fetchNextPage();    // 10 items
      await controller.fetchNextPage();    // 12 items (last page has 2 items < pageSize 5)

      expect(controller.itemList.length, equals(12));
      expect(controller.hasMoreData, isFalse);
    });

    test('refreshData resets pagination correctly', () async {
      await controller.loadInitialData();
      await controller.fetchNextPage();
      expect(controller.itemList.length, equals(10));

      await controller.refreshData();

      expect(controller.itemList.length, equals(5));
      expect(controller.currentPage, equals(1));
      expect(controller.hasMoreData, isTrue);
    });
  });
}
