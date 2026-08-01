import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Service to monitor network connectivity across the entire application.
/// Essential for high-scale apps to handle offline states and retry logic.
class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final Rx<ConnectivityResult> _connectionStatus = ConnectivityResult.none.obs;
  bool _isInitial = true;

  ConnectivityResult get connectionStatus => _connectionStatus.value;
  bool get isConnected => _connectionStatus.value != ConnectivityResult.none;
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  Future<ConnectivityService> init() async {
    final results = await _connectivity.checkConnectivity();
    final initialResult = _getFirstResult(results);
    _connectionStatus.value = initialResult;

    // If we start offline, we want to know so the next 'online' event shows the snackbar
    _isInitial = initialResult != ConnectivityResult.none;

    _subscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final result = _getFirstResult(results);
      final previousStatus = _connectionStatus.value;
      _connectionStatus.value = result;

      _handleStatusChange(result, previousStatus);
    });

    return this;
  }

  ConnectivityResult _getFirstResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    return results.first;
  }

  void _handleStatusChange(
    ConnectivityResult result,
    ConnectivityResult previousStatus,
  ) {
    if (result == ConnectivityResult.none) {
      Get.snackbar(
        'Offline',
        'You are currently offline. Some features may be unavailable.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
        duration: const Duration(seconds: 5),
      );
    } else if (previousStatus == ConnectivityResult.none && !_isInitial) {
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar(
        'Online',
        'Your connection has been restored.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.primaryContainer,
        colorText: Get.theme.colorScheme.onPrimaryContainer,
        duration: const Duration(seconds: 2),
      );
    }

    // After first check/event, we are no longer in initial state
    _isInitial = false;
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }
}
