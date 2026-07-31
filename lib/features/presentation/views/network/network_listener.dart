import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:universal_html/html.dart' as html;

class NetworkStatusController extends GetxController {
  NetworkStatusController({
    this.debounceDuration = const Duration(milliseconds: 500),
  });
  final RxBool isOnline = (html.window.navigator.onLine ?? true).obs;
  final RxBool showBanner = false.obs;
  final RxString lastRoute = '/'.obs; // Store last online route

  final Duration debounceDuration;
  Timer? _debounceTimer;
  StreamSubscription<html.Event>? _onlineSub;
  StreamSubscription<html.Event>? _offlineSub;

  @override
  void onInit() {
    super.onInit();
    _onlineSub = html.window.onOnline.listen((_) => _updateStatus(true));
    _offlineSub = html.window.onOffline.listen((_) => _updateStatus(false));
  }

  void _updateStatus(bool online) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      if (online != isOnline.value) {
        isOnline.value = online;
        showBanner.value = true;

        if (online) {
          // Auto-hide banner after 3 seconds when back online
          Future.delayed(const Duration(seconds: 3), () {
            if (isOnline.value) showBanner.value = false;
          });

          // Return to last route or home
          final routeToGo = lastRoute.value.isNotEmpty ? lastRoute.value : '/';
          if (Get.currentRoute == '/downloads') {
            Get.offAllNamed(routeToGo);
          }
        } else {
          // Save current route before going offline
          if (Get.currentRoute != '/downloads') {
            lastRoute.value = Get.currentRoute;
          }

          // Navigate to downloads page
          Get.offAllNamed('/downloads');
        }
      }
    });
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    super.onClose();
  }
}

/// Network Status Banner
/// ---------------------------
class NetworkStatusListener extends StatelessWidget {
  const NetworkStatusListener({
    required this.child,
    super.key,
    this.onlineMessage,
    this.offlineMessage,
    this.onlineColor,
    this.offlineColor,
  });
  final Widget child;
  final String? onlineMessage;
  final String? offlineMessage;
  final Color? onlineColor;
  final Color? offlineColor;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NetworkStatusController());

    return Stack(
      children: [
        child,
        Obx(() {
          final isOnline = controller.isOnline.value;
          final show = controller.showBanner.value;
          final color = isOnline
              ? (onlineColor ?? AppColors.success)
              : (offlineColor ?? AppColors.error);
          final message = isOnline
              ? (onlineMessage ?? '✅ You are online')
              : (offlineMessage ?? '⚠️ You are offline');

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: show ? 0 : -80,
            left: 0,
            right: 0,
            child: Material(
              elevation: 6,
              color: color,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
