import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/bindings/initial_binding.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/utils/error_handler_utils.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Initialize and run the application with proper error handling
void main() {
  // Catch errors outside of Flutter's error handling
  unawaited(
    runZonedGuarded(
      () async {
        // Use path strategy for clean URLs (removes # from URLs)
        setPathUrlStrategy();

        // CRITICAL: Initialize Flutter bindings first inside the zone!
        // This must be the very first line to avoid "Binding has not yet been initialized" on Web
        // and "Zone mismatch" error when using runZonedGuarded.
        WidgetsFlutterBinding.ensureInitialized();

        // Initialize logger first - before anything else
        logger.init(
          minLogLevel: kDebugMode
              ? 2
              : 4, // Verbose in debug, Info in production
        );

        setupGlobalErrorHandlers();

        try {
          // Low-latency parallel initialization of Firebase and Storage
          await Future.wait([
            Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            ).then((_) {
              logger.info('Firebase initialized successfully', tag: 'Startup');
              FirebaseFirestore.instance.settings = const Settings(
                persistenceEnabled: !kIsWeb,
                cacheSizeBytes: 100 * 1024 * 1024,
              );
            }),
            GetStorage.init().catchError((e) {
              logger.warning('GetStorage error: $e');
              return false;
            }),
          ]);

          // Non-blocking Firebase AppCheck
          unawaited(
            FirebaseAppCheck.instance.activate(
              webProvider: ReCaptchaEnterpriseProvider(
                '6LdsItgsAAAAADh75ccO7IQFSv77Hf4DYc-5G01G',
              ),
              androidProvider: AndroidProvider.debug,
              appleProvider: kDebugMode
                  ? AppleProvider.debug
                  : AppleProvider.deviceCheck,
            ).then((_) {
              FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
            }).catchError((e) {
              logger.error('Firebase App Check error: $e', tag: 'Startup');
            }),
          );

          final authService = Get.put(AuthService(), permanent: true);
          Get.put(AppService(), permanent: true);
          Get.put(ConnectivityService(), permanent: true);
          Get.put(PushNotificationService(), permanent: true);
          Get.put(UserPreferencesService(), permanent: true);
          Get.put(AdService(), permanent: true);

          // Auth MUST complete before app renders auth-dependent UI
          await authService.init();

          // Set Crashlytics user identifier after auth (non-PII)
          if (!kIsWeb) {
            final uid = authService.user?.uid;
            if (uid != null) {
              FirebaseCrashlytics.instance.setUserIdentifier(uid);
            }
          }

          // Run the app after critical services are ready
          runApp(const Truthworld());

          // Non-critical service init in background
          Future.wait([
            Get.find<AppService>().init(),
            Get.find<ConnectivityService>().init(),
            Get.find<PushNotificationService>().init(),
          ]).then((_) {
            logger.info('All background services initialized', tag: 'Startup');
          });
        } catch (error, stackTrace) {
          logger.wtf(
            'Fatal error during initialization',
            error: error,
            stackTrace: stackTrace,
            tag: 'Startup',
          );
          _notifyAppError('Initialization failed: $error');

          // Show error UI
          runApp(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Application Error',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to initialize: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          // Restart the app
                          runApp(const Truthworld());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
      (error, stackTrace) {
        // Catch ALL errors outside of Flutter's zone
        debugPrint('Zone error caught: $error');
        debugPrintStack(stackTrace: stackTrace);
        _notifyAppError('Unhandled error: $error');
      },
    ),
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

/// Main application widget
class Truthworld extends StatelessWidget {
  final String? overrideInitialRoute;
  final String title;

  const Truthworld({
    super.key,
    this.overrideInitialRoute,
    this.title = 'Truthworld',
  });

  String _getInitialRoute() {
    if (overrideInitialRoute != null) {
      return overrideInitialRoute!;
    }
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final uriStr = Uri.base.toString().toLowerCase();
      if (host.startsWith('admin') ||
          host.contains('admin') ||
          uriStr.contains('admin') ||
          Uri.base.queryParameters.containsKey('admin')) {
        if (host.startsWith('admin') || host.contains('admin.truthworld.in')) {
          final path = Uri.base.path.toLowerCase();
          if (path == '/admin' || path == '/admin/' || path == '/admin/login' || path == '/' || path.isEmpty) {
            return '/';
          }
          return path;
        }
        final path = Uri.base.path.toLowerCase();
        if (path.isNotEmpty && path != '/' && path != '/admin' && path != '/admin/') {
          return path;
        }
        return '/admin/login';
      }
      if (host.startsWith('studio') ||
          host.contains('studio') ||
          uriStr.contains('studio') ||
          Uri.base.queryParameters.containsKey('studio')) {
        if (host.startsWith('studio') || host.contains('studio.truthworld.in')) {
          final path = Uri.base.path.toLowerCase();
          if (path == '/studio' || path == '/studio/' || path == '/' || path.isEmpty) {
            return '/';
          }
          return path;
        }
        return '/studio';
      }
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      defaultTransition: kIsWeb ? Transition.noTransition : Transition.native,
      transitionDuration: kIsWeb
          ? Duration.zero
          : const Duration(milliseconds: 250),
      initialRoute: _getInitialRoute(),
      initialBinding: InitialBinding(),
      getPages: AppPages.routes,
      navigatorObservers: [RouteStackObserver()],
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final clampedTextScaler = mediaQueryData.textScaler.clamp(
          minScaleFactor: 1,
          maxScaleFactor: 1.4,
        );

        return MediaQuery(
          data: mediaQueryData.copyWith(textScaler: clampedTextScaler),
          child: TruthworldSplashScreen(
            child: Stack(
              children: [
                child!,
                const MiniplayerOverlayManager(),
              ],
            ),
          ),
        );
      },
    );
  }
}
