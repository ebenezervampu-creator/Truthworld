import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// GetX Utility Extensions and Helpers
extension GetXExtensions on GetxController {
  /// Show a snackbar
  void showSnackbar({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackPosition position = SnackPosition.BOTTOM,
    Color backgroundColor = const Color.fromARGB(255, 48, 48, 48),
    Color? textColor,
  }) {
    Get.showSnackbar(
      GetSnackBar(
        title: title,
        message: message,
        duration: duration,
        snackPosition: position,
        backgroundColor: backgroundColor,
        titleText: Text(
          title,
          style: TextStyle(
            color: textColor ?? AppTheme.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        messageText: Text(
          message,
          style: TextStyle(color: textColor ?? AppTheme.colors.textPrimary),
        ),
      ),
    );
  }

  /// Show error snackbar
  void showError(String message, {String title = 'Error'}) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: AppTheme.colors.error,
    );
  }

  /// Show success snackbar
  void showSuccess(String message, {String title = 'Success'}) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: AppTheme.colors.success,
    );
  }

  /// Show info snackbar
  void showInfo(String message, {String title = 'Info'}) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: AppTheme.colors.info,
    );
  }

  /// Show warning snackbar
  void showWarning(String message, {String title = 'Warning'}) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: AppTheme.colors.warning,
    );
  }

  /// Check if controller is active
  bool get isActive => Get.isRegistered(tag: runtimeType.toString());

  /// Delay execution
  Future<void> delay(Duration duration) async {
    await Future.delayed(duration);
  }
}

/// Dialog Helpers
class GetXDialogs {
  /// Show dialog
  static Future<T?> show<T>({
    required String title,
    required Widget content,
    List<Widget>? actions,
    VoidCallback? onDismiss,
  }) async {
    return Get.dialog<T>(
      AlertDialog(title: Text(title), content: content, actions: actions),
      barrierDismissible: false,
    ).then((_) {
      onDismiss?.call();
      return null;
    });
  }

  /// Show confirm dialog
  static Future<bool> showConfirm({
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    return await Get.dialog<bool>(
          AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text(confirmText),
              ),
            ],
          ),
          barrierDismissible: false,
        ) ??
        false;
  }

  /// Show input dialog
  static Future<String?> showInput({
    required String title,
    String? hint,
    String submitText = 'Submit',
    String cancelText = 'Cancel',
  }) async {
    final controller = TextEditingController();
    return Get.dialog<String?>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text(cancelText)),
          TextButton(
            onPressed: () => Get.back(result: controller.text),
            child: Text(submitText),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show loading dialog
  static void showLoading({String message = 'Loading...'}) {
    Get.dialog(
      AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Close loading dialog
  static void closeLoading() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }
}

/// Navigation Helpers
class GetXNavigation {
  /// Navigate to named route with arguments
  static Future<dynamic>? to(
    String routeName, {
    Map<String, String>? parameters,
    dynamic arguments,
    bool preventDuplicates = true,
  }) {
    return Get.toNamed(
      routeName,
      parameters: parameters,
      arguments: arguments,
      preventDuplicates: preventDuplicates,
    );
  }

  /// Replace current route
  static Future<dynamic>? offTo(
    String routeName, {
    Map<String, String>? parameters,
    dynamic arguments,
  }) {
    return Get.offNamed(
      routeName,
      parameters: parameters,
      arguments: arguments,
    );
  }

  /// Replace all routes
  static Future<dynamic>? offAllTo(
    String routeName, {
    Map<String, String>? parameters,
    dynamic arguments,
  }) {
    return Get.offAllNamed(
      routeName,
      parameters: parameters,
      arguments: arguments,
    );
  }

  /// Go back
  static void back<T>({T? result}) {
    Get.back(result: result);
  }

  /// Close all dialogs and go back
  static void closeDialogsAndGoBack<T>({T? result}) {
    while ((Get.isDialogOpen ?? false) || (Get.isBottomSheetOpen ?? false)) {
      Get.back();
    }
    Get.back(result: result);
  }
}

/// Exception Handling Helper
class GetXErrorHandler {
  /// Handle generic exceptions
  static String getErrorMessage(dynamic exception) {
    if (exception is String) {
      return exception;
    } else if (exception is Exception) {
      return exception.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  /// Log error
  static void logError(String tag, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('Ã¢ÂÅ’ ERROR [$tag]: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

/// Observable List Helper
extension ObservableListExtensions<T> on RxList<T> {
  /// Add item if not already exists
  void addIfAbsent(T item) {
    if (!contains(item)) {
      add(item);
    }
  }

  /// Remove item safely
  void removeSafe(T item) {
    if (contains(item)) {
      remove(item);
    }
  }

  /// Update item at index
  void updateAt(int index, T item) {
    if (index >= 0 && index < length) {
      removeAt(index);
      insert(index, item);
    }
  }

  /// Clear and add multiple items
  void setAll(List<T> items) {
    clear();
    addAll(items);
  }
}

/// Observable Map Helper
extension ObservableMapExtensions<K, V> on RxMap<K, V> {
  /// Get value safely
  V? getSafe(K key) {
    return containsKey(key) ? this[key] : null;
  }

  /// Put if absent
  void putIfAbsent(K key, V value) {
    if (!containsKey(key)) {
      this[key] = value;
    }
  }
}





