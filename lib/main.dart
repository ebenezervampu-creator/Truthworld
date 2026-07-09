import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/bindings/initial_binding.dart';

import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';

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
  // Catch errors outside of Flutter's error handling
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
        enableCrashlytics: !kDebugMode,
        minLogLevel: kDebugMode ? 2 : 4, // Verbose in debug, Info in production
      );

      FlutterError.onError = _handleFlutterError;

      try {
        // Initialize Firebase with error handling
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          logger.info('Firebase initialized successfully', tag: 'Startup');

          // Enable Firestore offline cache/persistence with unlimited size
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
          // Initialize App Check with reCAPTCHA Enterprise and Web Debug Provider support
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
            logger.info('Firebase App Check initialized successfully', tag: 'Startup');
          } catch (e) {
            logger.error('Firebase App Check initialization error: $e', tag: 'Startup');
          }


        } on FirebaseException catch (e) {
          logger.error(
            'Firebase initialization error: ${e.code} - ${e.message}',
            tag: 'Firebase',
            error: e,
          );
          rethrow;
        } catch (e) {
          logger.error(
            'Firebase initialization unknown error',
            tag: 'Firebase',
            error: e,
          );
          rethrow;
        }

        // Run the app ASAP after Firebase is ready
        runApp(const Truthworld());

        // Initialize local storage and services in parallel in the background
        Future.wait([
          GetStorage.init().catchError((e) {
            logger.warning('GetStorage error: $e');
            return false;
          }),
          Get.put(AuthService(), permanent: true).init(),
          Get.put(AppService(), permanent: true).init(),
          Get.put(ConnectivityService(), permanent: true).init(),
          Get.put(PushNotificationService(), permanent: true).init(),
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
                      color: Colors.red,
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
                      'Failed to initialize: ${error.toString()}',
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
  const Truthworld({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Truthworld',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      defaultTransition: kIsWeb ? Transition.noTransition : Transition.native,
      transitionDuration: kIsWeb ? Duration.zero : const Duration(milliseconds: 250),
      initialRoute: AppPages.routes.first.name,
      initialBinding: InitialBinding(),
      getPages: AppPages.routes,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: Stack(
            children: [
              child!,
              const MiniplayerOverlayManager(),
            ],
          ),
        );
      },
    );
  }
}




