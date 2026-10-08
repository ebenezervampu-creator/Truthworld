import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class PushNotificationService extends GetxService {
  static PushNotificationService get to {
    if (!Get.isRegistered<PushNotificationService>()) {
      Get.put(PushNotificationService(), permanent: true);
    }
    return Get.find<PushNotificationService>();
  }

  StreamSubscription? _onMessageSubscription;
  StreamSubscription? _onMessageOpenedAppSubscription;
  StreamSubscription? _onTokenRefreshSubscription;
  bool _initialized = false;
  Future<void>? _activeRegistrationFuture;
  String? _registeredUserId;
  String? _registeredToken;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Safe async initialization of FCM configuration and deep-link click handlers
  Future<PushNotificationService> init() async {
    if (!_isSupportedPlatform) return this;
    if (_initialized) return this;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // Enable foreground banners, badge count updates, and sound alerts on mobile
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 1. Deep-linking when app is launched from a terminated/cold state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }

      // 2. Deep-linking when app is resumed from background state
      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen(
            _handleNotificationClick,
            onError: (e, stackTrace) => logger.error(
              'Error in onMessageOpenedApp: $e',
              tag: 'PUSH_NOTIFICATIONS',
            ),
          );

      // 3. Listen to notifications received while the app is in the foreground
      _onMessageSubscription = FirebaseMessaging.onMessage.listen(
        (message) {
          logger.info(
            'Received push notification in foreground: ${message.notification?.title}',
            tag: 'PUSH_NOTIFICATIONS',
          );
          _showForegroundInAppNotification(message);
        },
        onError: (e, stackTrace) => logger.error(
          'Error in foreground onMessage: $e',
          tag: 'PUSH_NOTIFICATIONS',
        ),
      );

      logger.info(
        'PushNotificationService initialized successfully',
        tag: 'PUSH_NOTIFICATIONS',
      );
    } catch (e) {
      logger.error(
        'Failed to initialize PushNotificationService: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }

    return this;
  }

  /// Request iOS/Android user permissions and register current device token to Firestore.
  /// Deduplicates concurrent registration attempts and caches the registered state per user session.
  Future<void> registerToken(String userId, {bool force = false}) async {
    if (!_isSupportedPlatform || userId.isEmpty || userId == 'guest_user') {
      return;
    }

    // Deduplicate concurrent in-flight registrations by joining the active Future
    if (_activeRegistrationFuture != null) {
      logger.info(
        'Push token registration already in progress for user $userId. Awaiting in-flight registration.',
        tag: 'PUSH_NOTIFICATIONS',
      );
      await _activeRegistrationFuture;
      return;
    }

    // Skip redundant registration if the token is already registered for this user in this session
    if (!force && _registeredUserId == userId && _registeredToken != null) {
      return;
    }

    final completer = Completer<void>();
    _activeRegistrationFuture = completer.future;

    try {
      final messaging = FirebaseMessaging.instance;

      // Prompt user for notification authorization safely
      NotificationSettings settings;
      try {
        settings = await messaging.requestPermission();
      } catch (permError) {
        // Gracefully handle platform concurrency errors (e.g. system dialog already open)
        logger.warning(
          'Push notification permission request deferred or already running: $permError',
          tag: 'PUSH_NOTIFICATIONS',
        );
        settings = await messaging.getNotificationSettings();
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _saveTokenToFirestore(userId, token);
          _registeredUserId = userId;
          _registeredToken = token;
        }

        // Keep tokens up-to-date across lifecycle events without leaking duplicate listeners
        await _onTokenRefreshSubscription?.cancel();
        _onTokenRefreshSubscription = messaging.onTokenRefresh.listen(
          (newToken) async {
            await _saveTokenToFirestore(userId, newToken);
            _registeredUserId = userId;
            _registeredToken = newToken;
          },
          onError: (e, stackTrace) => logger.error(
            'Error in onTokenRefresh: $e',
            tag: 'PUSH_NOTIFICATIONS',
          ),
        );
      } else {
        logger.warning(
          'User denied or restricted push notification permissions',
          tag: 'PUSH_NOTIFICATIONS',
        );
      }
    } catch (e) {
      logger.error(
        'Error registering push notification token: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    } finally {
      _activeRegistrationFuture = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Clean up target device token from user document (usually on sign out)
  Future<void> unregisterToken(String userId) async {
    _registeredUserId = null;
    _registeredToken = null;
    if (!_isSupportedPlatform || userId.isEmpty || userId == 'guest_user') {
      return;
    }

    try {
      final box = GetStorage();
      final deviceId = box.read('device_id') as String? ?? '';
      if (deviceId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(userId)
            .update(
              {
                'fcmTokens.$deviceId': FieldValue.delete(),
              },
            );
        logger.info(
          'FCM token unregistered for device: $deviceId',
          tag: 'PUSH_NOTIFICATIONS',
        );
      }
    } catch (e) {
      logger.error(
        'Error unregistering FCM token: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
  }

  /// Persist the unique device token pairing inside Firestore, purging any duplicate token entries
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      final box = GetStorage();
      var deviceId = box.read('device_id') as String? ?? '';
      if (deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        box.write('device_id', deviceId);
      }

      final userDocRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId);

      // Check existing tokens to prune any redundant keys holding this identical token
      final updates = <String, dynamic>{};
      try {
        final snap = await userDocRef.get();
        if (snap.exists) {
          final data = snap.data();
          final existingMap = data?['fcmTokens'];
          if (existingMap is Map<String, dynamic>) {
            for (final entry in existingMap.entries) {
              final k = entry.key;
              final v = entry.value;
              var existingTokenStr = '';
              if (v is String) {
                existingTokenStr = v.trim();
              } else if (v is Map && v['token'] is String) {
                existingTokenStr = (v['token'] as String).trim();
              }

              // Prune old device entry holding the identical token
              if (k != deviceId && existingTokenStr == token.trim()) {
                updates['fcmTokens.$k'] = FieldValue.delete();
              }
            }
          }
        }
      } catch (checkErr) {
        logger.warning(
          'Unable to pre-check existing FCM tokens for duplicates: $checkErr',
          tag: 'PUSH_NOTIFICATIONS',
        );
      }

      final platformStr = GetPlatform.isWeb
          ? 'web'
          : (GetPlatform.isAndroid ? 'android' : 'ios');

      updates['fcmTokens.$deviceId'] = {
        'token': token.trim(),
        'platform': platformStr,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updates.length > 1) {
        // We have pruning updates + the new token write
        await userDocRef.update(updates).catchError((_) async {
          await userDocRef.set({
            'fcmTokens': {
              deviceId: {
                'token': token.trim(),
                'platform': platformStr,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            },
          }, SetOptions(merge: true));
        });
      } else {
        await userDocRef.set({
          'fcmTokens': {
            deviceId: {
              'token': token.trim(),
              'platform': platformStr,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
        }, SetOptions(merge: true));
      }

      logger.info(
        'FCM token successfully registered to Firestore for device $deviceId (deduplicated)',
        tag: 'PUSH_NOTIFICATIONS',
      );
    } catch (e) {
      logger.error(
        'Failed to sync FCM token to Firestore: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
  }

  /// Resolve deep-linking routing paths upon notification tap
  void _handleNotificationClick(RemoteMessage message) {
    try {
      logger.info(
        'Handling push notification click for: ${message.notification?.title ?? message.data['title']}',
        tag: 'PUSH_NOTIFICATIONS',
      );
      NotificationNavigationHandler.navigateToRemoteMessage(message);
    } catch (e, stackTrace) {
      logger.error(
        'Failed to navigate using notification payload: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'PushNotificationService._handleNotificationClick',
      );
    }
  }

  /// Display a styled in-app banner for notifications received while using the app
  void _showForegroundInAppNotification(RemoteMessage message) {
    if (Get.isRegistered<UserSettingsController>() &&
        !UserSettingsController.to.pushNotificationsEnabled.value) {
      logger.info(
        'Push notifications disabled in User Settings - suppressing foreground banner',
        tag: 'PUSH_NOTIFICATIONS',
      );
      return;
    }

    if (Get.isRegistered<DigitalWellbeingService>() &&
        DigitalWellbeingService.to.shouldMuteNotificationsDuringBedtime()) {
      logger.info(
        'Bedtime schedule active - suppressing foreground notification banner',
        tag: 'PUSH_NOTIFICATIONS',
      );
      return;
    }

    final title =
        message.notification?.title ??
        message.data['title'] as String? ??
        'Notification';
    final body =
        message.notification?.body ?? message.data['message'] as String? ?? '';

    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final context = Get.context;
    final textTheme = context != null ? Theme.of(context).textTheme : null;

    final customIconUrl = message.notification?.android?.imageUrl ??
        message.data['userAvatar'] as String? ??
        message.data['avatarUrl'] as String? ??
        message.data['thumbnailUrl'] as String? ??
        '';

    Widget leadingWidget;
    if (customIconUrl.isNotEmpty) {
      leadingWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: customIconUrl,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          placeholder: (context, url) => const AppLogo(size: 36, borderRadius: 8),
          errorWidget: (context, url, error) => const AppLogo(size: 36, borderRadius: 8),
        ),
      );
    } else {
      leadingWidget = const AppLogo(size: 36, borderRadius: 8);
    }

    Get.rawSnackbar(
      titleText: Text(
        title,
        style:
            textTheme?.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ) ??
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
      ),
      messageText: Text(
        body,
        style:
            textTheme?.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ) ??
            const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
      ),
      icon: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: leadingWidget,
      ),
      backgroundColor: AppColors.bgSurface,
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 4),
      onTap: (_) => _handleNotificationClick(message),
    );
  }

  @override
  void onClose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _onTokenRefreshSubscription?.cancel();
    _activeRegistrationFuture = null;
    _registeredUserId = null;
    _registeredToken = null;
    super.onClose();
  }
}
