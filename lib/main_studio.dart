import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/push_notification_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/main.dart';

void main() {
  runZonedGuarded(
    () async {
      setPathUrlStrategy();
      WidgetsFlutterBinding.ensureInitialized();

      logger.init(
        minLogLevel: kDebugMode ? 2 : 4,
      );

      try {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: 100 * 1024 * 1024,
          );
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
          } catch (e) {
            logger.error('Firebase App Check initialization error: $e', tag: 'Startup');
          }
        } on FirebaseException catch (e) {
          logger.error('Firebase initialization error: ${e.code}', tag: 'Firebase', error: e);
          rethrow;
        }

        if (!kIsWeb) {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
          FirebaseCrashlytics.instance.setCustomKey('platform', defaultTargetPlatform.name);
          await FirebasePerformance.instance.setPerformanceCollectionEnabled(!kDebugMode);
        }

        await GetStorage.init().catchError((e) {
          logger.warning('GetStorage error: $e');
          return false;
        });

        final authService = Get.put(AuthService(), permanent: true);
        Get.put(AppService(), permanent: true);
        Get.put(ConnectivityService(), permanent: true);
        Get.put(PushNotificationService(), permanent: true);
        Get.put(UserPreferencesService(), permanent: true);

        await authService.init();

        if (!kIsWeb) {
          final uid = authService.user?.uid;
          if (uid != null) {
            FirebaseCrashlytics.instance.setUserIdentifier(uid);
          }
        }

        runApp(const Truthworld(
          overrideInitialRoute: '/studio',
          title: 'Truthworld Studio',
        ));

        Future.wait([
          Get.find<AppService>().init(),
          Get.find<ConnectivityService>().init(),
          Get.find<PushNotificationService>().init(),
        ]).then((_) {
          logger.info('All Studio background services initialized', tag: 'Startup');
        });
      } catch (error, stackTrace) {
        logger.wtf(
          'Fatal error during Studio startup',
          error: error,
          stackTrace: stackTrace,
          tag: 'Startup',
        );
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Studio Initialization Error: $error'),
              ),
            ),
          ),
        );
      }
    },
    (error, stackTrace) {
      debugPrint('Zone error caught in Studio: $error');
    },
  );
}
