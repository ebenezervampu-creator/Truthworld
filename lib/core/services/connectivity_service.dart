import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Service to monitor network connectivity across the entire application.
/// Essential for high-scale apps to handle offline states and retry logic.
class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find<ConnectivityService>();

  final Connectivity _connectivity = Connectivity();
  final Rx<ConnectivityResult> _connectionStatus = ConnectivityResult.none.obs;
  bool _isInitial = true;

  ConnectivityResult get connectionStatus => _connectionStatus.value;
  bool get isConnected => _connectionStatus.value != ConnectivityResult.none;
  bool get isWifi => _connectionStatus.value == ConnectivityResult.wifi;
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  Future<ConnectivityService> init() async {
    final results = await _connectivity.checkConnectivity();
    final initialResult = _getFirstResult(results);
    _connectionStatus.value = initialResult;

    // If we start offline, we want to know so the next 'online' event shows the snackbar
    _isInitial = initialResult != ConnectivityResult.none;

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final result = _getFirstResult(results);
        final previousStatus = _connectionStatus.value;
        _connectionStatus.value = result;

        _handleStatusChange(result, previousStatus);
      },
      onError: (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ConnectivityService.onConnectivityChanged');
      },
    );

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
      AppSnackbar.warning(
        'You are currently offline. Some features may be unavailable.',
        title: 'Offline',
        duration: const Duration(seconds: 5),
      );
    } else if (previousStatus == ConnectivityResult.none && !_isInitial) {
      AppSnackbar.success(
        'Your connection has been restored.',
        title: 'Online',
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
