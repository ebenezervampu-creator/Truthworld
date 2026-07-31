import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/network/result.dart';

/// Generic base controller for all paginated lists, feeds, comments, and search results.
/// Eliminates duplicate pagination logic across features.
abstract class PagedController<T> extends BaseController {
  PagedController({this.pageSize = 10});
  final RxList<T> itemList = <T>[].obs;

  @override
  bool get isItemsEmpty => itemList.isEmpty;

  final _currentPage = 1.obs;
  int get currentPage => _currentPage.value;

  final _hasMoreData = true.obs;
  bool get hasMoreData => _hasMoreData.value;

  final int pageSize;

  /// Abstract method implemented by feature controllers to fetch data for a given [page]
  Future<Result<List<T>>> fetchPageData(int page);

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  /// Initial page fetch
  Future<void> loadInitialData() async {
    _currentPage.value = 1;
    _hasMoreData.value = true;
    setViewState(ViewState.loading);

    logPagination(1);
    final result = await fetchPageData(1);
    result.when(
      success: (data) {
        itemList.assignAll(data);
        if (data.length < pageSize) {
          _hasMoreData.value = false;
        }
        if (itemList.isEmpty) {
          setViewState(ViewState.empty);
        } else {
          setViewState(ViewState.success);
        }
      },
      failure: (exception) {
        handleError(exception);
      },
    );
  }

  /// Fetch next page for infinite scrolling
  Future<void> fetchNextPage() async {
    if (!hasMoreData || isLoading || isPaginationLoading || isRefreshing)
      return;

    setViewState(ViewState.paginationLoading);
    final nextPage = _currentPage.value + 1;
    logPagination(nextPage);

    final result = await fetchPageData(nextPage);
    result.when(
      success: (newData) {
        if (newData.isEmpty || newData.length < pageSize) {
          _hasMoreData.value = false;
        }
        itemList.addAll(newData);
        _currentPage.value = nextPage;
        setViewState(ViewState.success);
      },
      failure: (exception) {
        // Keep existing items on pagination failure
        showError('Failed to load more items: ${exception.message}');
        setViewState(ViewState.success);
      },
    );
  }

  /// Pull-to-refresh
  Future<void> refreshData() async {
    setViewState(ViewState.refreshing);
    _currentPage.value = 1;
    _hasMoreData.value = true;

    final result = await fetchPageData(1);
    result.when(
      success: (freshData) {
        itemList.assignAll(freshData);
        if (freshData.length < pageSize) {
          _hasMoreData.value = false;
        }
        setViewState(itemList.isEmpty ? ViewState.empty : ViewState.success);
      },
      failure: (exception) {
        handleError(exception);
      },
    );
  }

  /// Retry on failure
  Future<void> retry() async {
    if (itemList.isEmpty) {
      await loadInitialData();
    } else {
      await fetchNextPage();
    }
  }
}
