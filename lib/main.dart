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
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/security/biometric_security_service.dart';
import 'package:truthworld/core/security/rasp_security_service.dart';
import 'package:truthworld/core/security/screen_security_service.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/download_notification_service.dart';
import 'package:truthworld/core/services/guest_playback_limit_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/utils/color_blind_matrices.dart';
import 'package:truthworld/core/utils/error_handler_utils.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/pip_dedicated_view.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Default consumer-app entry point.
void main() => bootstrap();

/// Shared bootstrap function invoked by all flavor entry points.
///
/// [flavor] controls the initial route on **native** mobile builds.
/// On web the initial route is always resolved from the URL host.
void bootstrap({AppFlavor? flavor}) {
  final resolvedFlavor = flavor ?? AppFlavor.active;
  AppFlavor.current = resolvedFlavor;
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

        // Tune image cache capacity to prevent RAM bloat and GC frame drops
        PaintingBinding.instance.imageCache
          ..maximumSize = 350
          ..maximumSizeBytes = 64 * 1024 * 1024; // 64 MB

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
                    options: DefaultFirebaseOptions.forFlavor(resolvedFlavor),
                  );
                }
              } catch (e) {
                // If app already exists (e.g. during Web hot restart), ignore duplicate app error
                if (e is! FirebaseException || e.code != 'duplicate-app') {
                  rethrow;
                }
              }
              logger.info('Firebase initialized successfully', tag: 'Startup');
              StorageUtils.configureRetryLimits();
              try {
                FirebaseFirestore.instance.settings = const Settings(
                  persistenceEnabled: true,
                  cacheSizeBytes: 100 * 1024 * 1024,
                );
              } catch (settingsErr) {
                logger.info('Firestore settings notice: $settingsErr', tag: 'Startup');
              }
            })(),
            GetStorage.init().catchError((e) {
              logger.warning('GetStorage error: $e');
              return false;
            }),
          ]);

          // Synchronous Firebase App Check activation before AuthService instantiation.
          // In Identity Platform / Firebase Auth, App Check is strictly enforced on OAuth endpoints.
          // The App Check component must be registered with the Firebase App before FirebaseAuth.instance
          // is initialized, so Auth can attach the '#fac=<token>' parameter to the Google Sign-In popup URL.
          try {
            final isLocalDev = kDebugMode ||
                (kIsWeb &&
                    (() {
                      try {
                        final host = Uri.base.host.toLowerCase();
                        return host == 'localhost' ||
                            host == '127.0.0.1' ||
                            host == '0.0.0.0' ||
                            host == '[::1]' ||
                            host.endsWith('.local') ||
                            host.startsWith('192.168.') ||
                            host.startsWith('10.') ||
                            host.startsWith('172.');
                      } catch (_) {
                        return false;
                      }
                    })());

            await FirebaseAppCheck.instance
                .activate(
                  providerWeb: isLocalDev
                      ? WebDebugProvider(
                          debugToken: 'aeb2d92a-1f8d-4014-819d-b24f3ffefec3',
                        )
                      : ReCaptchaEnterpriseProvider(
                          '6LdsItgsAAAAADh75ccO7IQFSv77Hf4DYc-5G01G',
                        ),
                  providerAndroid: kDebugMode
                      ? const AndroidDebugProvider(
                          debugToken: 'aeb2d92a-1f8d-4014-819d-b24f3ffefec3',
                        )
                      : const AndroidPlayIntegrityProvider(),
                  providerApple: kDebugMode
                      ? const AppleDebugProvider(
                          debugToken: 'aeb2d92a-1f8d-4014-819d-b24f3ffefec3',
                        )
                      : const AppleDeviceCheckProvider(),
                )
                .timeout(const Duration(seconds: 10));

            await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

            // Prime and cache the initial token
            try {
              final token = await FirebaseAppCheck.instance
                  .getToken()
                  .timeout(const Duration(seconds: 8));
              if (token != null && token.isNotEmpty) {
                StorageUtils.updateAppCheckToken(token);
                logger.info(
                  'Firebase App Check active & token acquired',
                  tag: 'Startup',
                );
              }

              // Continuously sync token updates into StorageUtils for media player requests
              FirebaseAppCheck.instance.onTokenChange.listen((newToken) {
                if (newToken != null && newToken.isNotEmpty) {
                  StorageUtils.updateAppCheckToken(newToken);
                }
              });
            } catch (tokenErr) {
              logger.info(
                'AppCheck initial token acquisition skipped: $tokenErr',
                tag: 'Startup',
              );
            }
          } catch (e) {
            logger.warning(
              'Firebase App Check activation error: $e',
              tag: 'Startup',
            );
          }

          Get.put(RaspSecurityService(), permanent: true);
          Get.put(ScreenSecurityService(), permanent: true);
          Get.put(BiometricSecurityService(), permanent: true);
          final authService = Get.put(AuthService(), permanent: true);
          Get.put<AppFlavor>(resolvedFlavor, permanent: true);
          Get.put(AppService(), permanent: true);
          Get.put(ConnectivityService(), permanent: true);
          Get.put(PushNotificationService(), permanent: true);
          Get.put(DownloadNotificationService(), permanent: true);
          Get.put(UserPreferencesService(), permanent: true);
          final currencyService =
              Get.put(CurrencyLocalizationService(), permanent: true);
          Get.put(GuestPlaybackLimitService(), permanent: true);

          // Low-latency asynchronous Auth session & provider initialization
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

          // If returning from a web auth redirect (e.g. WASM Google Sign-In) or restoring active session,
          // wait briefly for auth hydration before Frame 1 so the app mounts authenticated.
          if (kIsWeb) {
            try {
              final box = GetStorage();
              final isPendingRedirect =
                  box.read<bool>('auth_pending_redirect') ?? false;
              final hasActiveSession =
                  box.read<bool>('auth_has_active_session') ?? false;

              if (isPendingRedirect) {
                await authInit.timeout(
                  const Duration(seconds: 6),
                  onTimeout: () => authService,
                );
              } else if (hasActiveSession) {
                // Give IndexedDB up to 1200ms to resolve live Firebase User before Frame 1
                await authInit.timeout(
                  const Duration(milliseconds: 1200),
                  onTimeout: () => authService,
                );
              }
            } catch (_) {}
          }

          // Run the app immediately so first frame / splash paints in zero-wait time
          runApp(Truthworld(
            title: resolvedFlavor.appTitle,
            // On web the Truthworld widget resolves initial route from the URL
            // host, so we only pass an override for native mobile builds.
            overrideInitialRoute: kIsWeb ? null : resolvedFlavor.initialRoute,
          ));

          // Frame 1 post-paint callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Initialize deep link listeners immediately on Frame 1 so cold-launched URLs
            // (e.g. from WhatsApp, SMS, external browsers) are captured with zero wait-time.
            unawaited(DeepLinkService.instance.initAppLinks());

            // Non-critical background services deferred until after Frame 1 paints smoothly
            // to eliminate main-thread contention and Choreographer skipped frames on mobile.
            Future.delayed(const Duration(milliseconds: 200), () {
              unawaited(
                Future.wait([
                  Get.find<AppService>().init(),
                  Get.find<ConnectivityService>().init(),
                  Get.find<PushNotificationService>().init(),
                  Get.find<DownloadNotificationService>().init(),
                  currencyService.fetchRealtimeRate(),
                ]).then((_) {
                  logger.info('All background services initialized', tag: 'Startup');
                }),
              );
            });
          });
        } catch (error, stackTrace) {
          logger.wtf(
            'Fatal error during initialization',
            error: error,
            stackTrace: stackTrace,
            tag: 'Startup',
          );
          _notifyAppError('App initialization failed. Please restart the application.');

          // Show error UI
          runApp(
            MaterialApp(
              themeMode: ThemeMode.dark,
              theme: buildAppTheme(),
              darkTheme: buildAppTheme(),
              home: Scaffold(
                backgroundColor: AppColors.bgPage,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Truthworld was unable to complete startup. Please check your internet connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: main,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
      (error, stackTrace) {
        final errStr = error.toString().toLowerCase();
        if (errStr.contains('user-cancelled') ||
            errStr.contains('sign-in was cancelled') ||
            errStr.contains('cancelled') ||
            errStr.contains('canceled') ||
            errStr.contains('redirecting') ||
            errStr.contains('popup_closed_by_user')) {
          // Normal user cancellation or redirect of authentication flow — not an unexpected runtime crash
          return;
        }
        // Catch ALL errors outside of Flutter's zone
        if (kDebugMode || kIsWeb) {
          debugPrint('Zone error caught: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        _notifyAppError('An unexpected error occurred. Please restart the application.');
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
    if (AppFlavor.isStudio) {
      return '/studio';
    }
    if (AppFlavor.isAdmin) {
      return '/admin/login';
    }
    if (AppFlavor.isAdvertiser) {
      return '/advertiser';
    }
    if (AppFlavor.isDubbing) {
      return '/dubbing';
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
      if (host.startsWith('dubbing') ||
          host.contains('dubbing') ||
          uriStr.contains('dubbing') ||
          Uri.base.queryParameters.containsKey('dubbing')) {
        if (host.startsWith('dubbing') || host.contains('dubbing.truthworld.in')) {
          final path = Uri.base.path.toLowerCase();
          if (path == '/dubbing' || path == '/dubbing/' || path == '/' || path.isEmpty) {
            return '/';
          }
          return path;
        }
        return '/dubbing';
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

        final mainView = Obx(() {
          final isInPip = PipService.to.isPiP.value;
          // When entering or restoring from Android Picture-in-Picture mode, the window
          // dimensions can be temporarily in a compact PiP aspect ratio (< 280px width & height)
          // while the platform window animates between PiP and full screen.
          final isCompactPipWindow = !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              mediaQueryData.size.width < 280 &&
              mediaQueryData.size.height < 280;
          final isPipActive = isInPip || isCompactPipWindow;
          final safeChild = child ?? const SizedBox.shrink();

          return Stack(
            children: [
              Offstage(
                offstage: isPipActive,
                child: TickerMode(
                  enabled: !isPipActive,
                  child: isPipActive
                      ? OverflowBox(
                          minWidth: 360,
                          maxWidth: 360,
                          minHeight: 640,
                          maxHeight: 640,
                          alignment: Alignment.topLeft,
                          child: safeChild,
                        )
                      : safeChild,
                ),
              ),
              if (!isPipActive)
                const Positioned.fill(child: MiniplayerOverlayManager()),
              if (isPipActive)
                const Positioned.fill(child: PipDedicatedView()),
            ],
          );
        });

        final content = MediaQuery(
          data: mediaQueryData.copyWith(textScaler: clampedTextScaler),
          child: kIsWeb ? mainView : TruthworldSplashScreen(child: mainView),
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
