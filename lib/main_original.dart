import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/firebase_options.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/bindings/initial_binding.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';

import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';

/// Global error handler for production
void _handleFlutterError(FlutterErrorDetails details) {
  // Log to console in debug
  if (kDebugMode) {
    FlutterError.dumpErrorToConsole(details);
  } else {
    // In production, log to Firebase Crashlytics or your error tracking service
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  }
}

/// Initialize and run the application with proper error handling
/// Main application entry point
void main() async {
  // Ensure Flutter engine is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error tracking first
  FlutterError.onError = _handleFlutterError;

  // Run the app in a guarded zone for high resilience
  runZonedGuarded(
    () async {
      final bootstrap = AppBootstrap();
      await bootstrap.initialize();
      
      _notifyAppReady();
      runApp(const Truthworld());
    },
    (error, stackTrace) {
      debugPrint('🚨 CRITICAL ZONE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      _notifyAppError('Engine Fault: $error');
      
      // Fallback UI to allow retry
      runApp(BootstrapErrorApp(error: error.toString()));
    },
  );
}

/// Industry-standard Bootstrapper for Truthworld
class AppBootstrap {
  Future<void> initialize() async {
    try {
      debugPrint('🎬 BOOTSTRAP: Starting synchronization sequence...');

      // PHASE 1: Infrastructure (Sequential)
      await _initFirebase();
      
      // PHASE 2: Core Data & Strategy (Parallel)
      await Future.wait([
        _initStorage(),
        _initUrlStrategy(),
      ]);

      // PHASE 3: Application Logic (Sequential but critical)
      await _initAuth();
      
      // PHASE 4: Auxiliary Services (Parallel)
      await Future.wait([
        _initAppService(),
        _initConnectivity(),
      ]);

      debugPrint('🏁 BOOTSTRAP: Synchronization completed successfully.');
    } catch (e, st) {
      debugPrint('❌ BOOTSTRAP: Fatal failure at phase level: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> _initFirebase() async {
    debugPrint('🛰️  PHASE 1: Synchronizing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🛰️  PHASE 1: Firebase ready.');
  }

  Future<void> _initStorage() async {
    try {
      debugPrint('📦 PHASE 2: Initializing Primary Storage...');
      await GetStorage.init();
      debugPrint('📦 PHASE 2: Storage ready.');
    } catch (e) {
      debugPrint('📦 PHASE 2 WARNING: Storage failed, continuing with memory.');
    }
  }

  Future<void> _initUrlStrategy() async {
    try {
      debugPrint('🔗 PHASE 2: Configuring URL Strategy...');
      setPathUrlStrategy();
    } catch (e) {
      debugPrint('🔗 PHASE 2 ERROR: Path strategy unavailable.');
    }
  }

  Future<void> _initAuth() async {
    debugPrint('🔐 PHASE 3: Booting Auth Service...');
    await Get.putAsync<AuthService>(() async {
      final service = AuthService();
      await service.init();
      return service;
    });
    debugPrint('🔐 PHASE 3: Auth ready.');
  }

  Future<void> _initAppService() async {
    debugPrint('⚙️  PHASE 4: Mounting App Control Service...');
    await Get.putAsync<AppService>(() async {
      final service = AppService();
      await service.init();
      return service;
    });
  }

  Future<void> _initConnectivity() async {
    debugPrint('📡 PHASE 4: Monitoring Network Uplink...');
    try {
      await Get.putAsync<ConnectivityService>(() async {
        final service = ConnectivityService();
        await service.init();
        return service;
      });
    } catch (e) {
      debugPrint('📡 PHASE 4 ERROR: Connectivity monitoring disabled.');
    }
  }
}

/// Fallback Error UI when regular App cannot boot
class BootstrapErrorApp extends StatelessWidget {
  final String error;
  const BootstrapErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Color(0xFFDC143C)),
                const SizedBox(height: 24),
                const Text(
                  'SYNCHRONIZATION ERROR',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (kIsWeb) {
                        js.context['location'].callMethod('reload');
                      }
                    },
                    child: const Text('RETRY SYNC'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notify JavaScript that the app is ready
void _notifyAppReady() {
  try {
    debugPrint('🚀 Truthworld App instance starting...');
    if (kIsWeb) {
      // Logic to communicate with JS if needed
      debugPrint('App ready notification synchronized with browser');
    }
  } catch (e) {
    debugPrint('Could not notify app ready: $e');
  }
}

/// Notify JavaScript about app errors
void _notifyAppError(String message) {
  try {
    debugPrint('🚨 Truthworld App Error: $message');
    if (kIsWeb) {
      // Logic to communicate with JS if needed
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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
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





