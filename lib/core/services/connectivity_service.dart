import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Service to monitor network connectivity across the entire application.
/// Essential for high-scale apps to handle offline states and retry logic.
class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final Rx<ConnectivityResult> _connectionStatus = ConnectivityResult.none.obs;

  ConnectivityResult get connectionStatus => _connectionStatus.value;
  bool get isConnected => _connectionStatus.value != ConnectivityResult.none;
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivity.onConnectivityChanged;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  Future<ConnectivityService> init() async {
    final results = await _connectivity.checkConnectivity();
    _connectionStatus.value = _getFirstResult(results);

    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = _getFirstResult(results);
      _connectionStatus.value = result;
      _handleStatusChange(result);
    });

    return this;
  }

  ConnectivityResult _getFirstResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    return results.first;
  }

  void _handleStatusChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      Get.snackbar(
        'Offline',
        'You are currently offline. Some features may be unavailable.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
        duration: const Duration(seconds: 5),
      );
    } else {
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
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }
}





