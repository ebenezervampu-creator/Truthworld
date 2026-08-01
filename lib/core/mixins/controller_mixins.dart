import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Mixin for controllers that need pagination
mixin PaginationMixin on GetxController {
  final RxInt currentPage = 1.obs;
  final RxInt itemsPerPage = 20.obs;
  final RxBool hasMoreItems = true.obs;
  final RxBool isLoadingMore = false.obs;

  /// Go to next page
  void nextPage() {
    if (hasMoreItems.value && !isLoadingMore.value) {
      currentPage.value++;
      loadMore();
    }
  }

  /// Go to previous page
  void previousPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
    }
  }

  /// Reset pagination
  void resetPagination() {
    currentPage.value = 1;
    hasMoreItems.value = true;
    isLoadingMore.value = false;
  }

  /// Load more items (to be implemented by subclass)
  Future<void> loadMore() async {}

  /// Calculate skip value
  int get skip => (currentPage.value - 1) * itemsPerPage.value;
}

/// Mixin for controllers that need search functionality
mixin SearchMixin on GetxController {
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxList<dynamic> searchResults = <dynamic>[].obs;

  /// Perform search
  Future<void> search(String query) async {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    isSearching.value = true;
    try {
      await performSearch(query);
    } finally {
      isSearching.value = false;
    }
  }

  /// Clear search (to be implemented by subclass)
  void clearSearch() {
    searchQuery.value = '';
    searchResults.clear();
  }

  /// Perform search logic (to be implemented by subclass)
  Future<void> performSearch(String query) async {}
}

/// Mixin for controllers that need filter functionality
mixin FilterMixin on GetxController {
  final RxMap<String, dynamic> selectedFilters = <String, dynamic>{}.obs;
  final RxBool isFiltering = false.obs;

  /// Apply filter
  void applyFilter(String key, dynamic value) {
    selectedFilters[key] = value;
  }

  /// Remove filter
  void removeFilter(String key) {
    selectedFilters.remove(key);
  }

  /// Clear all filters
  void clearFilters() {
    selectedFilters.clear();
  }

  /// Check if any filters applied
  bool get hasFilters => selectedFilters.isNotEmpty;
}

/// Mixin for controllers that manage loading states
mixin LoadingMixin on GetxController {
  final Rx<LoadingState> loadingState = LoadingState.idle.obs;

  bool get isLoading => loadingState.value == LoadingState.loading;
  bool get isError => loadingState.value == LoadingState.error;
  bool get isSuccess => loadingState.value == LoadingState.success;
  bool get isIdle => loadingState.value == LoadingState.idle;
  bool get isCancelled => loadingState.value == LoadingState.cancelled;

  void setLoading() => loadingState.value = LoadingState.loading;
  void setSuccess() => loadingState.value = LoadingState.success;
  void setError() => loadingState.value = LoadingState.error;
  void setIdle() => loadingState.value = LoadingState.idle;
  void setCancelled() => loadingState.value = LoadingState.cancelled;
}

/// Enum for loading states
enum LoadingState { idle, loading, success, error, cancelled }

/// Mixin for controllers that manage selection state
mixin SelectionMixin on GetxController {
  final RxList<String> selectedItems = <String>[].obs;
  final RxBool isMultiSelectMode = false.obs;

  /// Toggle item selection
  void toggleSelection(String itemId) {
    if (selectedItems.contains(itemId)) {
      selectedItems.remove(itemId);
    } else {
      selectedItems.add(itemId);
    }
  }

  /// Select item
  void selectItem(String itemId) {
    if (!selectedItems.contains(itemId)) {
      selectedItems.add(itemId);
    }
  }

  /// Deselect item
  void deselectItem(String itemId) {
    selectedItems.remove(itemId);
  }

  /// Clear selection
  void clearSelection() {
    selectedItems.clear();
  }

  /// Select all
  void selectAll(List<String> itemIds) {
    selectedItems.clear();
    selectedItems.addAll(itemIds);
  }

  /// Check if item is selected
  bool isItemSelected(String itemId) => selectedItems.contains(itemId);
}

/// Mixin for controllers that manage stream subscriptions and timers.
/// Automatically disposes all tracked resources in onClose().
///
/// **Deprecated**: [BaseController] now includes built-in resource tracking
/// via [trackSubscription], [trackTimer], [trackTextController], and
/// [trackScrollController]. Use those methods instead of mixing in this mixin
/// for any controller that extends [BaseController].
@Deprecated('Use BaseController.trackSubscription/trackTimer/etc. instead')
mixin DisposableMixin on GetxController {
  final List<StreamSubscription> _managedSubscriptions = [];
  final List<Timer> _managedTimers = [];
  final List<TextEditingController> _managedTextControllers = [];
  final List<ScrollController> _managedScrollControllers = [];

  void trackSubscription(StreamSubscription sub) =>
      _managedSubscriptions.add(sub);
  void trackTimer(Timer timer) => _managedTimers.add(timer);
  void trackTextController(TextEditingController ctrl) =>
      _managedTextControllers.add(ctrl);
  void trackScrollController(ScrollController ctrl) =>
      _managedScrollControllers.add(ctrl);

  @override
  void onClose() {
    for (final sub in _managedSubscriptions) {
      sub.cancel();
    }
    for (final timer in _managedTimers) {
      timer.cancel();
    }
    for (final ctrl in _managedTextControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _managedScrollControllers) {
      ctrl.dispose();
    }
    _managedSubscriptions.clear();
    _managedTimers.clear();
    _managedTextControllers.clear();
    _managedScrollControllers.clear();
    super.onClose();
  }
}
