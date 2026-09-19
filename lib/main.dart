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
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/utils/color_blind_matrices.dart';
import 'package:truthworld/core/utils/error_handler_utils.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

        // Optimize visibility_detector update interval to prevent per-frame recalculations on scroll
        VisibilityDetectorController.instance.updateInterval =
            const Duration(milliseconds: 100);

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
            (() async {
              try {
                if (Firebase.apps.isEmpty) {
                  await Firebase.initializeApp(
                    options: DefaultFirebaseOptions.currentPlatform,
                  );
                }
              } catch (e) {
                // If app already exists (e.g. during Web hot restart), ignore duplicate app error
                if (e is! FirebaseException || e.code != 'duplicate-app') {
                  rethrow;
                }
              }
              logger.info('Firebase initialized successfully', tag: 'Startup');
              FirebaseFirestore.instance.settings = const Settings(
                persistenceEnabled: true,
                cacheSizeBytes: 100 * 1024 * 1024,
              );
            })(),
            GetStorage.init().catchError((e) {
              logger.warning('GetStorage error: $e');
              return false;
            }),
          ]);

          // Non-blocking Firebase AppCheck
          unawaited(
            (() async {
              try {
                await FirebaseAppCheck.instance.activate(
                  webProvider: ReCaptchaEnterpriseProvider(
                    '6LdsItgsAAAAADh75ccO7IQFSv77Hf4DYc-5G01G',
                  ),
                  androidProvider: kDebugMode
                      ? AndroidProvider.debug
                      : AndroidProvider.playIntegrity,
                  appleProvider: kDebugMode
                      ? AppleProvider.debug
                      : AppleProvider.deviceCheck,
                );
                if (!kIsWeb) {
                  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
                } else {
                  // On web, test token retrieval once with a timeout. If web domain is not yet
                  // registered in Google Cloud ReCaptcha Enterprise console, disable auto-refresh
                  // to prevent repeated 403 token exchange network thrashing.
                  try {
                    final token = await FirebaseAppCheck.instance
                        .getToken()
                        .timeout(const Duration(seconds: 4));
                    if (token != null && token.isNotEmpty) {
                      await FirebaseAppCheck.instance
                          .setTokenAutoRefreshEnabled(true);
                    } else {
                      await FirebaseAppCheck.instance
                          .setTokenAutoRefreshEnabled(false);
                    }
                  } catch (tokenErr) {
                    logger.warning(
                      'Web AppCheck token exchange unavailable (skipping auto-refresh): $tokenErr',
                      tag: 'Startup',
                    );
                    await FirebaseAppCheck.instance
                        .setTokenAutoRefreshEnabled(false);
                  }
                }
              } catch (e) {
                logger.warning(
                  'Firebase App Check error: $e',
                  tag: 'Startup',
                );
              }
            })(),
          );

          final authService = Get.put(AuthService(), permanent: true);
          Get.put(AppService(), permanent: true);
          Get.put(ConnectivityService(), permanent: true);
          Get.put(PushNotificationService(), permanent: true);
          Get.put(UserPreferencesService(), permanent: true);
          final currencyService =
              Get.put(CurrencyLocalizationService(), permanent: true);

          // Non-blocking asynchronous Auth session & provider initialization
          final authInit = authService.init();

          // Set Crashlytics collection & user identifier on supported mobile platforms
          final isMobile = !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS);
          if (isMobile) {
            unawaited(
              FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
                !kDebugMode,
              ).then((_) {
                FirebaseCrashlytics.instance.setCustomKey(
                  'platform',
                  defaultTargetPlatform.name,
                );
              }),
            );
            unawaited(
              authInit.then((_) {
                final uid = authService.user?.uid;
                if (uid != null) {
                  FirebaseCrashlytics.instance.setUserIdentifier(uid);
                }
              }),
            );
          }

          // Run the app immediately so first frame / splash paints in zero-wait time
          runApp(const Truthworld());

          // Non-critical service init in background
          unawaited(
            Future.wait([
              Get.find<AppService>().init(),
              Get.find<ConnectivityService>().init(),
              Get.find<PushNotificationService>().init(),
              DeepLinkService.instance.initAppLinks(),
              currencyService.fetchRealtimeRate(),
            ]).then((_) {
              logger.info('All background services initialized', tag: 'Startup');
            }),
          );
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
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.white,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Application Error',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Truthworld was unable to complete startup. Please check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: main,
                        child: Text('Retry'),
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
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'Main.notifyAppError',
    );
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
      final path = Uri.base.path;
      final query = Uri.base.hasQuery ? '?${Uri.base.query}' : '';
      if (path.isNotEmpty && path != '/') {
        return '$path$query';
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

        final content = MediaQuery(
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

        return _AccessibilityColorFilterWrapper(child: content);
      },
    );
  }
}

/// Granular wrapper that isolates reactivity for color-blind filter matrix updates,
/// completely eliminating full-app root widget tree rebuilds.
class _AccessibilityColorFilterWrapper extends StatelessWidget {
  final Widget child;
  const _AccessibilityColorFilterWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<UserSettingsController>()) {
      return child;
    }
    return Obx(() {
      final colorBlindMode =
          UserSettingsController.to.accessibility.value.colorBlindSupport;
      final matrix = ColorBlindMatrices.getMatrix(colorBlindMode);
      if (matrix != null) {
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: child,
        );
      }
      return child;
    });
  }
}
