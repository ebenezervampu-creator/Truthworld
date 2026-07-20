import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';

enum ViewState { idle, loading, success, error, empty, cancelled }

/// Base controller for all feature controllers to standardize state management
/// and ensure scalability by handling common UI states.
abstract class BaseController extends GetxController {
  final rxState = ViewState.idle.obs;
  ViewState get state => rxState.value;

  final _errorMessage = ''.obs;
  String get errorMessage => _errorMessage.value;

  bool get isLoading => state == ViewState.loading;
  bool get isError => state == ViewState.error;
  bool get isEmpty => state == ViewState.empty;
  bool get isSuccess => state == ViewState.success;
  bool get isCancelled => state == ViewState.cancelled;

  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    debugPrint('⚙️ [Controller Init] ${runtimeType.toString()} initialized');
  }

  @override
  @mustCallSuper
  void onClose() {
    debugPrint('🗑️ [Controller Close] ${runtimeType.toString()} disposed');
    super.onClose();
  }

  void setViewState(ViewState state) {
    debugPrint('🔄 [ViewState Transition] ${runtimeType.toString()}: ${rxState.value.name} -> ${state.name}');
    rxState.value = state;
  }

  void setError(String message) {
    debugPrint('❌ [Controller Error] ${runtimeType.toString()}: $message');
    _errorMessage.value = message;
    setViewState(ViewState.error);
  }

  /// Pagination support
  final _page = 1.obs;
  int get page => _page.value;

  final _hasMore = true.obs;
  bool get hasMore => _hasMore.value;

  final RxList<dynamic> items = <dynamic>[].obs;

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

  void handleError(dynamic error) {
    String message = error.toString();
    // Special handling for specific exception types if needed
    setError(message);
    
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.errorContainer,
      colorText: Get.theme.colorScheme.onErrorContainer,
    );
  }

  void showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.primaryContainer,
      colorText: Get.theme.colorScheme.onPrimaryContainer,
    );
  }

  void showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.errorContainer,
      colorText: Get.theme.colorScheme.onErrorContainer,
    );
  }

  void showWarning(String message) {
    Get.snackbar(
      'Warning',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.tertiaryContainer,
      colorText: Get.theme.colorScheme.onTertiaryContainer,
    );
  }

  /// execute a task safely with automatic error handling, loading, and cancellation state
  Future<void> safeExecute(Future<void> Function() task, {bool showLoading = true, String? loadingMessage}) async {
    try {
      if (showLoading && items.isEmpty) setViewState(ViewState.loading);
      // We could use the loadingMessage here to show a specific snackbar/overlay if needed
      await task();
      if (state == ViewState.loading) setViewState(ViewState.success);
      if (items.isEmpty && state != ViewState.error && state != ViewState.cancelled) {
        setViewState(ViewState.empty);
      }
    } on OperationCancelledException catch (e) {
      debugPrint('ℹ️ [Task Cancelled] ${runtimeType.toString()}: ${e.message}');
      setViewState(ViewState.cancelled);
    } catch (e) {
      handleError(e);
    }
  }

  /// Helper to wrap async calls with state management
  Future<void> runTask(Future<void> Function() task, {bool showLoading = true, String? loadingMessage}) async {
    await safeExecute(task, showLoading: showLoading, loadingMessage: loadingMessage);
  }
}





