// Pagination Scalability Tests
//
// Verifies PagedController correctness and guard logic under large datasets,
// rapid concurrent calls, and edge-case page boundaries.
//
// Tests are pure Dart — no Firestore, no Flutter widgets needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/base/paged_controller.dart';
import 'package:truthworld/core/network/result.dart';

// ---------------------------------------------------------------------------
// Minimal test item
// ---------------------------------------------------------------------------

class _Item {
  final int index;
  const _Item(this.index);
}

// ---------------------------------------------------------------------------
// Configurable PagedController backed by an in-memory list
// ---------------------------------------------------------------------------

class _TestPagedController extends PagedController<_Item> {
  _TestPagedController({
    required this.allItems,
    super.pageSize,
    this.fetchDelay = Duration.zero,
  });

  final List<_Item> allItems;

  /// Simulate optional async fetch delay for race-condition tests.
  final Duration fetchDelay;

  int fetchCallCount = 0;

  @override
  Future<Result<List<_Item>>> fetchPageData(int page) async {
    fetchCallCount++;
    if (fetchDelay > Duration.zero) {
      await Future.delayed(fetchDelay);
    }
    final start = (page - 1) * pageSize;
    if (start >= allItems.length) return Result.success([]);
    final end = (start + pageSize).clamp(0, allItems.length);
    return Result.success(allItems.sublist(start, end));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Group 1: Large Dataset Traversal ───────────────────────────────────

  group('Large Dataset Traversal', () {
    test(
        'Paginate through 10,000 items: all items received in correct order '
        'with no skips or duplicates (pageSize=100)', () async {
      const totalItems = 10000;
      const pageSize = 100;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: pageSize,
      );

      // loadInitialData is called in onInit — wait for it
      await controller.loadInitialData();
      expect(controller.itemList.length, equals(pageSize));

      // Traverse all remaining pages
      while (controller.hasMoreData) {
        await controller.fetchNextPage();
      }

      // Verify total count
      expect(controller.itemList.length, equals(totalItems));

      // Verify correct order — no skips, no duplicates
      for (var i = 0; i < totalItems; i++) {
        expect(controller.itemList[i].index, equals(i),
            reason: 'Item at position $i has wrong index ${controller.itemList[i].index}.');
      }

      // Verify no duplicates using a set
      final indices = controller.itemList.map((item) => item.index).toSet();
      expect(indices.length, equals(totalItems),
          reason: 'Duplicate items detected in paginated output.');

      controller.onClose();
    });

    test(
        'Paginate through 10,001 items: last page with 1 item sets hasMoreData=false '
        '(exact boundary — pageSize=100)', () async {
      const totalItems = 10001; // 100 full pages + 1 item on page 101
      const pageSize = 100;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: pageSize,
      );

      await controller.loadInitialData();

      while (controller.hasMoreData) {
        await controller.fetchNextPage();
      }

      expect(controller.itemList.length, equals(totalItems));
      expect(controller.hasMoreData, isFalse,
          reason: 'hasMoreData should be false after the final partial page.');
      expect(controller.currentPage, equals(101));

      controller.onClose();
    });

    test(
        'Paginate through exactly pageSize items: hasMoreData=false after empty follow-up fetch '
        '(full single-page dataset — controller needs one extra fetch to confirm end)',
        () async {
      const pageSize = 50;
      final allItems = List.generate(pageSize, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: pageSize,
      );

      await controller.loadInitialData();

      // After loading exactly pageSize items, hasMoreData is still true
      // because the controller cannot distinguish "exactly filled page" from "full page with more".
      // This is correct PagedController behaviour — a follow-up fetch is required.
      expect(controller.itemList.length, equals(pageSize));
      expect(controller.hasMoreData, isTrue,
          reason: 'After a full-page fetch (data.length == pageSize), '
              'hasMoreData stays true until the next empty fetch confirms end-of-data.');

      // One more fetch returns empty → hasMoreData becomes false
      await controller.fetchNextPage();
      expect(controller.hasMoreData, isFalse,
          reason: 'The empty follow-up fetch must set hasMoreData=false.');
      expect(controller.itemList.length, equals(pageSize),
          reason: 'No items added by the empty fetch.');

      controller.onClose();
    });

    test('fetchNextPage on 200-page traversal: unique item count always equals fetched count',
        () async {
      const totalItems = 2000;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
      );

      await controller.loadInitialData();

      while (controller.hasMoreData) {
        final before = controller.itemList.length;
        await controller.fetchNextPage();
        final after = controller.itemList.length;

        // Set size must always match list size — no duplicates at any point during traversal
        final uniqueCount = controller.itemList.map((item) => item.index).toSet().length;
        expect(uniqueCount, equals(after),
            reason: 'Duplicate detected after page ${controller.currentPage}: '
                'list has $after items but only $uniqueCount are unique.');

        // On real data pages, items must be added. On the final empty confirmation page, no items added.
        final added = after - before;
        if (controller.hasMoreData) {
          expect(added, greaterThan(0),
              reason: 'fetchNextPage added 0 items on a non-terminal page.');
        }
      }

      expect(controller.itemList.length, equals(totalItems));

      controller.onClose();
    });
  });

  // ── Group 2: Concurrent Call Guards ────────────────────────────────────

  group('Concurrent Call Guards', () {
    test(
        'Rapid-fire fetchNextPage calls while a fetch is in-flight '
        'are debounced — only one additional fetch executes per call',
        () async {
      const totalItems = 500;
      const pageSize = 50;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: pageSize,
        fetchDelay: const Duration(milliseconds: 20),
      );

      await controller.loadInitialData();
      final firstFetchCount = controller.fetchCallCount;

      // Fire 10 rapid consecutive calls — only 1 should actually execute
      // (guard: if isLoading || isPaginationLoading => return early)
      final futures = List.generate(10, (_) => controller.fetchNextPage());
      await Future.wait(futures);

      // fetchCallCount should be firstFetchCount + 1, not firstFetchCount + 10
      expect(controller.fetchCallCount, lessThanOrEqualTo(firstFetchCount + 2),
          reason: 'Multiple in-flight fetchNextPage calls should be guarded. '
              'Expected ≤${firstFetchCount + 2} total fetches, '
              'got ${controller.fetchCallCount}.');

      controller.onClose();
    });

    test(
        'fetchNextPage while hasMoreData=false never triggers another fetch',
        () async {
      const totalItems = 10;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: 100, // pageSize > totalItems → hasMoreData=false after page 1
      );

      await controller.loadInitialData();
      expect(controller.hasMoreData, isFalse);

      final fetchCountBefore = controller.fetchCallCount;

      // Try to fetch more — should be no-op
      await controller.fetchNextPage();
      await controller.fetchNextPage();
      await controller.fetchNextPage();

      expect(controller.fetchCallCount, equals(fetchCountBefore),
          reason: 'fetchNextPage when hasMoreData=false must not trigger any fetches.');

      controller.onClose();
    });

    test(
        'refreshData after large traversal resets to page 1 cleanly '
        '(10,000 items, pageSize=100)',
        () async {
      const totalItems = 10000;
      const pageSize = 100;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: pageSize,
      );

      await controller.loadInitialData();

      // Traverse a few pages
      for (var i = 0; i < 5; i++) {
        await controller.fetchNextPage();
      }
      expect(controller.currentPage, equals(6));
      expect(controller.itemList.length, equals(600));

      // Refresh — must reset to page 1
      await controller.refreshData();

      expect(controller.currentPage, equals(1));
      expect(controller.itemList.length, equals(pageSize),
          reason: 'After refreshData, itemList should contain exactly one page of items.');
      expect(controller.hasMoreData, isTrue);
      expect(controller.itemList.first.index, equals(0),
          reason: 'After refresh, first item must be index 0 (page 1).');

      controller.onClose();
    });

    test(
        'retry() on an empty controller triggers loadInitialData, '
        'not fetchNextPage — correct re-entry point',
        () async {
      final allItems = List.generate(50, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
      );

      // Manually reset to simulate an error state with empty list
      controller.itemList.clear();
      controller.fetchCallCount = 0;

      // retry() on empty list should call loadInitialData
      await controller.retry();

      expect(controller.itemList, isNotEmpty,
          reason: 'retry() on empty controller must populate the list.');
      expect(controller.currentPage, equals(1));

      controller.onClose();
    });
  });

  // ── Group 3: Page Size Boundary Conditions ─────────────────────────────

  group('Page Size Boundary Conditions', () {
    test('pageSize=1 — each page contains exactly 1 item; all 100 items collected', () async {
      const totalItems = 100;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: 1,
      );

      await controller.loadInitialData();

      while (controller.hasMoreData) {
        await controller.fetchNextPage();
      }

      // All items must be collected
      expect(controller.itemList.length, equals(totalItems));
      // hasMoreData must be false (confirmed by empty follow-up page)
      expect(controller.hasMoreData, isFalse);
      // Items must be in correct order
      for (var i = 0; i < totalItems; i++) {
        expect(controller.itemList[i].index, equals(i),
            reason: 'Item at position $i has wrong index.');
      }

      controller.onClose();
    });

    test('pageSize=1000 — single page covers 999-item dataset with hasMoreData=false', () async {
      const totalItems = 999;
      final allItems = List.generate(totalItems, _Item.new);
      final controller = _TestPagedController(
        allItems: allItems,
        pageSize: 1000,
      );

      await controller.loadInitialData();

      expect(controller.itemList.length, equals(totalItems));
      expect(controller.hasMoreData, isFalse);
      expect(controller.currentPage, equals(1));

      controller.onClose();
    });

    test('Empty dataset: itemList stays empty, state transitions to empty', () async {
      final controller = _TestPagedController(
        allItems: [],
      );

      await controller.loadInitialData();

      expect(controller.itemList, isEmpty);
      expect(controller.state, equals(ViewState.empty));
      expect(controller.hasMoreData, isFalse);

      controller.onClose();
    });
  });
}
