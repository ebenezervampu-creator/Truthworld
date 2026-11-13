import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/ui_event.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/core/state/reactive_property.dart';
import 'package:truthworld/core/state/view_state_contract.dart';
import 'package:truthworld/core/utils/safe_get.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';

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
/// worker lifecycle disposal, event-driven UI side-effects, cancellation support, and low-latency UI updates.
class BaseController extends GetxController implements IStateController {
  final Rx<ViewState> rxState = ViewState.idle.obs;
  @override
  ViewState get state => rxState.value;

  /// Abstract reactive property contract (decoupled from GetX Rx).
  @override
  late final IReactiveProperty<ViewState> rxViewState =
      RxReactiveProperty<ViewState>.fromRx(rxState);

  final RxString _errorMessage = ''.obs;
  @override
  String get errorMessage => _errorMessage.value;

  /// Abstract reactive property contract for errors.
  late final IReactiveProperty<String> rxErrorProperty =
      RxReactiveProperty<String>.fromRx(_errorMessage);

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed || isClosed;

  @override
  bool get isLoading => state == ViewState.loading;
  @override
  bool get isRefreshing => state == ViewState.refreshing;
  @override
  bool get isPaginationLoading => state == ViewState.paginationLoading;
  @override
  bool get isError => state == ViewState.error;
  @override
  bool get isEmpty => state == ViewState.empty;
  @override
  bool get isSuccess => state == ViewState.success;
  @override
  bool get isOffline => state == ViewState.offline;
  @override
  bool get isCancelled => state == ViewState.cancelled;

  /// Pure event stream for UI side-effects (snackbars, dialogs, navigation)
  final StreamController<UiEvent> _uiEventController =
      StreamController<UiEvent>.broadcast();
  @override
  Stream<UiEvent> get uiEvents => _uiEventController.stream;

  /// Emit an immutable [UiEvent] to listeners in presentation layer.
  @override
  void emitUiEvent(UiEvent event) {
    if (!_uiEventController.isClosed) {
      _uiEventController.add(event);
    }
  }

  /// Workers registered with this controller that will be automatically disposed on [onClose].
  final List<Worker> workers = <Worker>[];

  /// Register a worker (ever, once, debounce, interval) for automatic cleanup.
  void addWorker(Worker worker) {
    workers.add(worker);
  }

  /// Alias for [addWorker]
  void registerWorker(Worker worker) => addWorker(worker);

  /// Track a [Worker] for automatic disposal in [onClose]
  Worker trackWorker(Worker worker) {
    addWorker(worker);
    return worker;
  }

  /// Safely resolves dependency [T] or returns null without throwing.
  T? safeFind<T>({String? tag}) => SafeGet.findOrNull<T>(tag: tag);

  /// Resolves dependency [T], automatically initializing it via [create] if missing.
  T safeFindOrCreate<T>(
    T Function() create, {
    String? tag,
    bool permanent = false,
  }) =>
      SafeGet.findOrCreate<T>(create, tag: tag, permanent: permanent);

  // =========================================================================
  // RESOURCE TRACKING — Auto-dispose subscriptions, timers, and controllers
  // =========================================================================

  final List<StreamSubscription> _trackedSubscriptions = <StreamSubscription>[];
  final List<Timer> _trackedTimers = <Timer>[];
  final List<TextEditingController> _trackedTextControllers = <TextEditingController>[];
  final List<ScrollController> _trackedScrollControllers = <ScrollController>[];

  /// Track a [StreamSubscription] for automatic cancellation in [onClose].
  S trackSubscription<S extends StreamSubscription>(S sub) {
    _trackedSubscriptions.add(sub);
    return sub;
  }

  /// Track a [Timer] for automatic cancellation in [onClose].
  S trackTimer<S extends Timer>(S timer) {
    _trackedTimers.add(timer);
    return timer;
  }

  /// Track a [TextEditingController] for automatic disposal in [onClose].
  S trackTextController<S extends TextEditingController>(S ctrl) {
    _trackedTextControllers.add(ctrl);
    return ctrl;
  }

  /// Track a [ScrollController] for automatic disposal in [onClose].
  S trackScrollController<S extends ScrollController>(S ctrl) {
    _trackedScrollControllers.add(ctrl);
    return ctrl;
  }

  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    logInit();
  }

  @override
  @mustCallSuper
  void onClose() {
    _isDisposed = true;
    logDispose();
    _uiEventController.close();
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

  String get _controllerName => objectRuntimeType(this, 'BaseController');

  void logInit() {
    debugPrint('🟢 [Controller Init] $_controllerName initialized');
  }

  void logDispose() {
    final resourceCount = _trackedSubscriptions.length +
        _trackedTimers.length +
        _trackedTextControllers.length +
        _trackedScrollControllers.length;
    debugPrint(
      '⚫ [Controller Dispose] $_controllerName disposed '
      '(${workers.length} workers, $resourceCount tracked resources cleaned)',
    );
  }

  void logApi(String endpoint) {
    debugPrint('🟡 [API Request] $_controllerName -> $endpoint');
  }

  void logCacheHit(String key) {
    debugPrint('🔵 [Cache Hit] $_controllerName -> $key');
  }

  void logPagination(int page) {
    debugPrint('🟠 [Pagination] $_controllerName -> page $page');
  }

  void logException(dynamic error) {
    debugPrint('🔴 [Exception] $_controllerName -> $error');
  }

  @override
  void setViewState(ViewState state) {
    if (rxState.value != state) {
      debugPrint(
        '🔄 [ViewState Transition] $_controllerName: ${rxState.value.name} -> ${state.name}',
      );
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isDisposed && rxState.value != state) {
            rxState.value = state;
          }
        });
      } else {
        rxState.value = state;
      }
    }
  }

  /// Safely executes a state action callback, deferring via [addPostFrameCallback]
  /// if the framework is currently in the persistentCallbacks build/layout phase.
  void safeStateAction(VoidCallback action) {
    if (isDisposed) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isDisposed) action();
      });
    } else {
      action();
    }
  }

  @override
  void setError(String message) {
    logException(message);
    _errorMessage.value = message;
    setViewState(ViewState.error);
  }

  /// Generic pagination support
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

  @override
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
    emitUiEvent(
      UiEventShowSnackbar(
        title: title,
        message: message,
        isError: isError,
        isWarning: isWarning,
      ),
    );

    if (Get.context == null) return;
    try {
      if (isError) {
        AppToast.error(message, title: title);
      } else if (isWarning) {
        AppToast.warning(message, title: title);
      } else {
        AppToast.info(message, title: title);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'BaseController.suppressedSnackbar',
      );
    }
  }

  void handleError(dynamic error, {VoidCallback? onRetry}) {
    final appException = AppException.from(error);
    logException(appException.message);
    final cleanMessage = UserFeedbackSanitizer.sanitizeMessage(appException.displayMessage);
    _errorMessage.value = cleanMessage;

    if (appException is NetworkException) {
      setViewState(ViewState.offline);
    } else {
      setViewState(ViewState.error);
    }

    emitUiEvent(
      UiEventShowSnackbar(
        message: cleanMessage,
        isError: true,
        onAction: onRetry,
      ),
    );

    ErrorHandler.showSnackbar(appException, onRetry: onRetry);
  }

  void showSuccess(String message) {
    _presentSnackbar('Success', message);
  }

  void showError(String message) {
    final cleanMessage = UserFeedbackSanitizer.sanitizeMessage(message);
    emitUiEvent(
      UiEventShowSnackbar(message: cleanMessage, isError: true),
    );
    ErrorHandler.showSnackbar(
      GenericAppException(message: cleanMessage, userMessage: cleanMessage),
    );
  }

  void showWarning(String message) {
    _presentSnackbar('Warning', message, isWarning: true);
  }

  void showInfo(String message) {
    _presentSnackbar('Information', message);
  }

  /// Execute an async function returning a `Result<S>` with automatic UI state transitions
  Future<Result<S>> safeExecuteResult<S>(
    Future<Result<S>> Function() task, {
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
    } catch (e, stackTrace) {
      handleError(e);
      return Result.failure(AppException.from(e, stackTrace));
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
      if (state == ViewState.loading || state == ViewState.refreshing) {
        if (isItemsEmpty) {
          setViewState(ViewState.empty);
        } else {
          setViewState(ViewState.success);
        }
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

