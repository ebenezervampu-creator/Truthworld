import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';

enum ViewState {
  idle,
  loading,
  refreshing,
  paginationLoading,
  success,
  empty,
  error,
  offline,
  cancelled,
}

/// Base controller for all feature controllers to standardize state management,
/// worker lifecycle disposal, cancellation support, and low-latency UI updates.
abstract class BaseController extends GetxController {
  final Rx<ViewState> rxState = ViewState.idle.obs;
  ViewState get state => rxState.value;

  final RxString _errorMessage = ''.obs;
  String get errorMessage => _errorMessage.value;

  bool get isLoading => state == ViewState.loading;
  bool get isRefreshing => state == ViewState.refreshing;
  bool get isPaginationLoading => state == ViewState.paginationLoading;
  bool get isError => state == ViewState.error;
  bool get isEmpty => state == ViewState.empty;
  bool get isSuccess => state == ViewState.success;
  bool get isOffline => state == ViewState.offline;
  bool get isCancelled => state == ViewState.cancelled;

  /// Workers registered with this controller that will be automatically disposed on [onClose].
  final List<Worker> workers = <Worker>[];

  /// Register a worker (ever, once, debounce, interval) for automatic cleanup.
  void addWorker(Worker worker) {
    workers.add(worker);
  }

  /// Alias for [addWorker]
  void registerWorker(Worker worker) => addWorker(worker);

  // =========================================================================
  // RESOURCE TRACKING — Auto-dispose subscriptions, timers, and controllers
  // =========================================================================

  final List<StreamSubscription> _trackedSubscriptions = <StreamSubscription>[];
  final List<Timer> _trackedTimers = <Timer>[];
  final List<TextEditingController> _trackedTextControllers = <TextEditingController>[];
  final List<ScrollController> _trackedScrollControllers = <ScrollController>[];

  /// Track a [StreamSubscription] for automatic cancellation in [onClose].
  void trackSubscription(StreamSubscription sub) =>
      _trackedSubscriptions.add(sub);

  /// Track a [Timer] for automatic cancellation in [onClose].
  void trackTimer(Timer timer) => _trackedTimers.add(timer);

  /// Track a [TextEditingController] for automatic disposal in [onClose].
  void trackTextController(TextEditingController ctrl) =>
      _trackedTextControllers.add(ctrl);

  /// Track a [ScrollController] for automatic disposal in [onClose].
  void trackScrollController(ScrollController ctrl) =>
      _trackedScrollControllers.add(ctrl);

  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    logInit();
  }

  @override
  @mustCallSuper
  void onClose() {
    logDispose();
    for (final worker in workers) {
      worker.dispose();
    }
    workers.clear();
    for (final sub in _trackedSubscriptions) {
      sub.cancel();
    }
    _trackedSubscriptions.clear();
    for (final timer in _trackedTimers) {
      timer.cancel();
    }
    _trackedTimers.clear();
    for (final ctrl in _trackedTextControllers) {
      ctrl.dispose();
    }
    _trackedTextControllers.clear();
    for (final ctrl in _trackedScrollControllers) {
      ctrl.dispose();
    }
    _trackedScrollControllers.clear();
    super.onClose();
  }

  void logInit() {
    debugPrint('🟢 [Controller Init] $runtimeType initialized');
  }

  void logDispose() {
    final resourceCount = _trackedSubscriptions.length +
        _trackedTimers.length +
        _trackedTextControllers.length +
        _trackedScrollControllers.length;
    debugPrint(
      '⚫ [Controller Dispose] $runtimeType disposed '
      '(${workers.length} workers, $resourceCount tracked resources cleaned)',
    );
  }

  void logApi(String endpoint) {
    debugPrint('🟡 [API Request] $runtimeType -> $endpoint');
  }

  void logCacheHit(String key) {
    debugPrint('🔵 [Cache Hit] $runtimeType -> $key');
  }

  void logPagination(int page) {
    debugPrint('🟠 [Pagination] $runtimeType -> page $page');
  }

  void logException(dynamic error) {
    debugPrint('🔴 [Exception] $runtimeType -> $error');
  }

  void setViewState(ViewState state) {
    if (rxState.value != state) {
      debugPrint(
        '🔄 [ViewState Transition] $runtimeType: ${rxState.value.name} -> ${state.name}',
      );
      rxState.value = state;
    }
  }

  void setError(String message) {
    logException(message);
    _errorMessage.value = message;
    setViewState(ViewState.error);
  }

  /// Pagination support
  final RxInt _page = 1.obs;
  int get page => _page.value;

  final RxBool _hasMore = true.obs;
  bool get hasMore => _hasMore.value;

  final RxList<dynamic> items = <dynamic>[].obs;
  bool get isItemsEmpty => items.isEmpty;

  void resetPagination() {
    _page.value = 1;
    _hasMore.value = true;
    items.clear();
  }

  void updatePagination(List<dynamic> newItems, {int pageSize = 10}) {
    if (newItems.length < pageSize) {
      _hasMore.value = false;
    }
    items.addAll(newItems);
    _page.value++;
  }

  void clearError() {
    _errorMessage.value = '';
    if (state == ViewState.error) setViewState(ViewState.idle);
  }

  void _presentSnackbar(
    String title,
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (Get.context == null) return;
    try {
      final theme = Get.theme;
      final bg = isError
          ? theme.colorScheme.errorContainer
          : isWarning
          ? theme.colorScheme.tertiaryContainer
          : theme.colorScheme.primaryContainer;
      final fg = isError
          ? theme.colorScheme.onErrorContainer
          : isWarning
          ? theme.colorScheme.onTertiaryContainer
          : theme.colorScheme.onPrimaryContainer;

      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: bg,
        colorText: fg,
      );
    } catch (e) {
      debugPrint(
        '⚠️ [BaseController] Suppressed snackbar in non-UI context: $e',
      );
    }
  }

  void handleError(dynamic error) {
    var message = error.toString();
    if (error is AppException) {
      message = error.message;
    }
    setError(message);
    _presentSnackbar('Error', message, isError: true);
  }

  void showSuccess(String message) {
    _presentSnackbar('Success', message);
  }

  void showError(String message) {
    _presentSnackbar('Error', message, isError: true);
  }

  void showWarning(String message) {
    _presentSnackbar('Warning', message, isWarning: true);
  }

  /// Execute an async function returning a `Result<T>` with automatic UI state transitions
  Future<Result<T>> safeExecuteResult<T>(
    Future<Result<T>> Function() task, {
    bool showLoading = true,
  }) async {
    try {
      if (showLoading && isItemsEmpty) setViewState(ViewState.loading);
      final result = await task();
      result.when(
        success: (data) {
          if (state == ViewState.loading || state == ViewState.refreshing) {
            setViewState(ViewState.success);
          }
        },
        failure: (exception) {
          handleError(exception);
        },
      );
      return result;
    } on OperationCancelledException catch (e) {
      debugPrint('ℹ️ [Task Cancelled] $runtimeType: ${e.message}');
      setViewState(ViewState.cancelled);
      return Result.failure(e);
    } catch (e) {
      handleError(e);
      return Result.failure(
        GenericAppException(message: e.toString(), originalException: e),
      );
    }
  }

  /// Legacy safeExecute helper wrapper for void async tasks
  Future<void> safeExecute(
    Future<void> Function() task, {
    bool showLoading = true,
    String? loadingMessage,
  }) async {
    try {
      if (showLoading && isItemsEmpty) setViewState(ViewState.loading);
      await task();
      if (isItemsEmpty &&
          state != ViewState.error &&
          state != ViewState.cancelled) {
        setViewState(ViewState.empty);
      } else if (state == ViewState.loading) {
        setViewState(ViewState.success);
      }
    } on OperationCancelledException catch (e) {
      debugPrint('ℹ️ [Task Cancelled] $runtimeType: ${e.message}');
      setViewState(ViewState.cancelled);
    } catch (e) {
      handleError(e);
    }
  }

  Future<void> runTask(
    Future<void> Function() task, {
    bool showLoading = true,
    String? loadingMessage,
  }) async {
    await safeExecute(
      task,
      showLoading: showLoading,
      loadingMessage: loadingMessage,
    );
  }
}
