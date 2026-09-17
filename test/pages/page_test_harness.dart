import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Standard page testing harness to reliably pump and test Truthworld pages
Future<void> pumpPageInHarness(
  WidgetTester tester,
  Widget page, {
  Size physicalSize = const Size(1280, 1000),
  double devicePixelRatio = 1.0,
  VoidCallback? onBeforePump,
}) async {
  Get.reset();
  Get.testMode = true;

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;

  if (!Get.isRegistered<AuthService>()) {
    Get.put<AuthService>(AuthService());
  }

  if (!Get.isRegistered<ConnectivityService>()) {
    Get.put<ConnectivityService>(ConnectivityService());
  }

  if (onBeforePump != null) {
    onBeforePump();
  }

  await tester.pumpWidget(
    GetMaterialApp(
      theme: buildAppTheme(),
      home: page,
    ),
  );

  // Pump at least once to allow animations and frame callbacks to start
  await tester.pump();
  // Advance virtual time to complete pending staggered animations and transient timers
  await tester.pump(const Duration(seconds: 1));
}
