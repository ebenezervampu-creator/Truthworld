import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy_stub.dart'
    if (dart.library.js_util) 'package:truthworld/core/utils/url_strategy/url_strategy_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/bindings/initial_binding.dart';

import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/fcm_notification_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:web/web.dart' as web;

/// Global error handler for production
void _handleFlutterError(FlutterErrorDetails details) {
  // Log to console in debug
  if (kDebugMode) {
    FlutterError.dumpErrorToConsole(details);
    logger.error(
      'Flutter Error',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'FlutterFramework',
    );
  } else {
    // In production, log to Firebase Crashlytics or your error tracking service
    logger.wtf(
      'Flutter Framework Error',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'FlutterFramework',
    );
  }
}

/// Initialize and run the application with proper error handling
void main() {
  // 1. 🚀 CRITICAL: Set URL strategy before ANY other operation on Web
  // This must happen at the very entry point to prevent routing issues.
  if (kIsWeb) {
    try {
      setPathUrlStrategy();
    } catch (e) {
      // Ignore if already set (common during hot restart)
      debugPrint('URL strategy note: $e');
    }
  }

  // 2. 🔥 Catch errors outside of Flutter's synchronous error handling
  runZonedGuarded(
    () async {
      // Step A: Engine Initialization
      WidgetsFlutterBinding.ensureInitialized();

      // Enable accessibility semantics for high Lighthouse scores on Web
      if (kIsWeb) {
        SemanticsBinding.instance.ensureSemantics();
      }

      // Step B: Core Infrastructure (Logger)
      logger.init(
        enableCrashlytics: !kDebugMode,
        minLogLevel: kDebugMode ? 2 : 4,
      );
      FlutterError.onError = _handleFlutterError;
      logger.info('❅ Startup Sequence Initiated', tag: 'Startup');

      try {
        // Step C: Parallel High-Priority Inits
        // We start storage and Firebase in parallel to minimize blocking time
        final storageInit = GetStorage.init();

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        logger.info('✓ Firebase Ready', tag: 'Startup');

        // Step D: Unified Service Registration
        // Using putAsync ensures dependencies are resolved in order
        await Get.putAsync(() => AuthService().init(), permanent: true);
        await Get.putAsync(() => AppService().init(), permanent: true);
        await Get.putAsync(() => ConnectivityService().init(), permanent: true);
        await Get.putAsync(() => FcmNotificationService().init(), permanent: true);

        // Wait for storage as well
        await storageInit;
        logger.info('✓ Core Services Online', tag: 'Startup');

        // Step E: Launch Application
        runApp(const Truthworld());
        logger.info('🚀 Application Launched', tag: 'Startup');
      } catch (error, stackTrace) {
        logger.wtf(
          'FATAL STARTUP ERROR',
          error: error,
          stackTrace: stackTrace,
          tag: 'Startup',
        );
        _notifyAppError('Init failed: $error');
        runApp(AppErrorWidget(error: error.toString()));
      }
    },
    (error, stackTrace) {
      debugPrint('💥 Unhandled Global Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _notifyAppError('Global fault: $error');
    },
  );
}

/// Notify JavaScript about app errors
void _notifyAppError(String message) {
  try {
    // For web platform, communicate with JavaScript
    if (kIsWeb) {
      debugPrint('App error notification: $message');
    }
  } catch (e) {
    debugPrint('Could not notify app error: $e');
  }
}

/// Premium Error UI Widget
class AppErrorWidget extends StatelessWidget {
  final String error;
  const AppErrorWidget({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 80,
                  color: Color(0xFFDC143C),
                ).animate().shake(duration: 500.ms).fadeIn(),
                const SizedBox(height: 24),
                const Text(
                  'SYSTEM FAULT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ).animate().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'monospace',
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 48),
                SizedBox(
                  width: 220,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (kIsWeb) {
                        web.window.location.reload();
                      } else {
                        // Re-run the entire initialization sequence
                        main();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC143C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                      shadowColor: const Color(
                        0xFFDC143C,
                      ).withValues(alpha: 0.5),
                    ),
                    child: const Text(
                      'REBOOT SYSTEM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ).animate().scale(delay: 400.ms, curve: Curves.elasticOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main application widget
class Truthworld extends StatelessWidget {
  const Truthworld({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Truthworld',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      initialRoute: AppPages.routes.first.name,
      initialBinding: InitialBinding(),
      getPages: AppPages.routes,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: Stack(
            children: [
              child!,
              Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => const MiniplayerOverlayManager(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
