import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/config/app_flavor.dart';
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

      // 4. Automatically subscribe to global broadcast topics so all installed devices receive platform broadcasts
      unawaited(subscribeToBroadcastTopics());

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
          unawaited(syncSubscribedChannelTopics(userId));
          unawaited(subscribeToBroadcastTopics());
        }

        // Keep tokens up-to-date across lifecycle events without leaking duplicate listeners
        await _onTokenRefreshSubscription?.cancel();
        _onTokenRefreshSubscription = messaging.onTokenRefresh.listen(
          (newToken) async {
            await _saveTokenToFirestore(userId, newToken);
            _registeredUserId = userId;
            _registeredToken = newToken;
            unawaited(subscribeToBroadcastTopics());
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
      final currentApp = AppFlavor.active.name;
      final deviceKey = 'device_id_$currentApp';
      var deviceId = box.read(deviceKey) as String? ?? '';
      if (deviceId.isEmpty) {
        deviceId = box.read('device_id') as String? ?? '';
      }
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
          'FCM token unregistered for device: $deviceId (app: $currentApp)',
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
      final currentApp = AppFlavor.active.name; // 'app', 'studio', 'admin', 'advertiser'
      final deviceKey = 'device_id_$currentApp';
      var deviceId = box.read(deviceKey) as String? ?? '';
      if (deviceId.isEmpty) {
        final legacyId = box.read('device_id') as String? ?? '';
        deviceId = legacyId.isNotEmpty
            ? '${currentApp}_$legacyId'
            : '${currentApp}_${const Uuid().v4()}';
        box.write(deviceKey, deviceId);
      }

      final userDocRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId);

      final platformStr = GetPlatform.isWeb
          ? 'web'
          : (GetPlatform.isAndroid ? 'android' : 'ios');

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
              var existingApp = '';
              var existingPlatform = '';

              if (v is String) {
                existingTokenStr = v.trim();
              } else if (v is Map) {
                if (v['token'] is String) {
                  existingTokenStr = (v['token'] as String).trim();
                }
                existingApp = (v['app'] as String? ?? v['appFlavor'] as String? ?? '').trim().toLowerCase();
                existingPlatform = (v['platform'] as String? ?? '').trim().toLowerCase();
              }

              if (existingApp.isEmpty) {
                if (k.startsWith('studio_')) {
                  existingApp = 'studio';
                } else if (k.startsWith('admin_')) {
                  existingApp = 'admin';
                } else if (k.startsWith('advertiser_')) {
                  existingApp = 'advertiser';
                } else if (k.startsWith('app_')) {
                  existingApp = 'app';
                }
              }

              // Prune old device entry holding identical token OR superseded same-flavor device token
              final isSameToken = existingTokenStr == token.trim();
              final isSupersededSameFlavorDevice = k != deviceId &&
                  existingApp == currentApp &&
                  (existingPlatform.isEmpty || existingPlatform == platformStr);

              if (k != deviceId && (isSameToken || isSupersededSameFlavorDevice)) {
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

      updates['fcmTokens.$deviceId'] = {
        'token': token.trim(),
        'platform': platformStr,
        'app': currentApp,
        'appFlavor': currentApp,
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
                'app': currentApp,
                'appFlavor': currentApp,
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
              'app': currentApp,
              'appFlavor': currentApp,
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
      final targetApp =
          (message.data['targetApp'] as String? ?? '').trim().toLowerCase();
      final currentApp = AppFlavor.active.name;
      if (targetApp.isNotEmpty && targetApp != 'all' && targetApp != currentApp) {
        logger.info(
          'Notification clicked in flavor "$currentApp" targeted at "$targetApp" - delegating to cross-app launcher.',
          tag: 'PUSH_NOTIFICATIONS',
        );
      }

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
    final targetApp =
        (message.data['targetApp'] as String? ?? '').trim().toLowerCase();
    final currentApp = AppFlavor.active.name;

    final isStudio = targetApp == 'studio' ||
        NotificationNavigationHandler.isStudioNotificationPayload(
          message.data,
          title: message.notification?.title,
          body: message.notification?.body,
          actionUrl: message.data['actionUrl'] as String?,
        );

    if (isStudio && !AppFlavor.isStudio) {
      logger.info(
        'Suppressing studio-related notification banner in consumer app flavor "$currentApp"',
        tag: 'PUSH_NOTIFICATIONS',
      );
      return;
    }

    if (targetApp.isNotEmpty && targetApp != 'all' && targetApp != currentApp) {
      logger.info(
        'Suppressing foreground banner meant for targetApp "$targetApp" in current flavor "$currentApp"',
        tag: 'PUSH_NOTIFICATIONS',
      );
      return;
    }

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

    final rawUrl = (message.data['thumbnailUrl'] as String? ??
            message.data['userAvatar'] as String? ??
            message.data['avatarUrl'] as String? ??
            message.notification?.android?.imageUrl ??
            '')
        .trim();
    // Exclude generic fallback icons or legacy icon filenames from network loading
    final isGenericIcon = rawUrl.contains('Icon-512.png') ||
        rawUrl.contains('Icon-192.png') ||
        rawUrl.contains('play_icon') ||
        rawUrl.contains('app_logo');
    final customIconUrl =
        (!isGenericIcon && rawUrl.startsWith('http')) ? rawUrl : '';

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

    final topPadding = context != null ? MediaQuery.of(context).padding.top : 0.0;

    Get.rawSnackbar(
      snackPosition: SnackPosition.TOP,
      dismissDirection: DismissDirection.up,
      margin: EdgeInsets.only(
        top: topPadding + 10,
        left: 16,
        right: 16,
      ),
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
      borderRadius: 14,
      borderColor: AppColors.bgDivider,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      duration: const Duration(seconds: 4),
      onTap: (_) => _handleNotificationClick(message),
    );
  }

  /// Subscribes the current device to an FCM channel broadcast topic.
  ///
  /// Industry Standard: Topics allow instantaneous, zero-cost push broadcasts to
  /// mega channels (100M+ subscribers) in a single backend call without transactional locks.
  Future<void> subscribeToChannelTopic(String channelId) async {
    if (!_isSupportedPlatform || channelId.trim().isEmpty) return;
    // FLAVOR ISOLATION:
    // Only the consumer video app ('app') should subscribe to channel upload broadcast topics.
    // Studio ('studio'), Admin, and Advertiser apps MUST NOT subscribe to consumer video channels.
    if (AppFlavor.active != AppFlavor.app) {
      logger.info(
        'Suppressed subscribeToChannelTopic for non-consumer flavor "${AppFlavor.active.name}"',
        tag: 'PUSH_NOTIFICATIONS',
      );
      return;
    }
    try {
      final sanitizedId = channelId.trim().replaceAll(RegExp('[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.subscribeToTopic('channel_$sanitizedId');
    } catch (e) {
      logger.warning(
        'Failed to subscribe to FCM topic for channel $channelId: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
  }

  /// Unsubscribes the current device from an FCM channel broadcast topic.
  Future<void> unsubscribeFromChannelTopic(String channelId) async {
    if (!_isSupportedPlatform || channelId.trim().isEmpty) return;
    try {
      final sanitizedId = channelId.trim().replaceAll(RegExp('[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.unsubscribeFromTopic('channel_$sanitizedId');
    } catch (e) {
      logger.warning(
        'Failed to unsubscribe from FCM topic for channel $channelId: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
  }

  /// Cleans up any leftover channel broadcast topic subscriptions on non-consumer app flavors (Studio, Admin, Advertiser)
  Future<void> unsubscribeFromAllChannelTopicsIfNonConsumer(String userId) async {
    if (!_isSupportedPlatform || AppFlavor.active == AppFlavor.app || userId.isEmpty || userId == 'guest_user') {
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.userSubscriptions(userId))
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final channelId = (data['channelId'] as String? ?? doc.id).trim();
        if (channelId.isNotEmpty) {
          final sanitizedId = channelId.replaceAll(RegExp('[^a-zA-Z0-9-_.~%]'), '_');
          await FirebaseMessaging.instance.unsubscribeFromTopic('channel_$sanitizedId');
        }
      }
      logger.info(
        'Cleaned up channel topic subscriptions for non-consumer flavor "${AppFlavor.active.name}"',
        tag: 'PUSH_NOTIFICATIONS',
      );
    } catch (e) {
      logger.warning(
        'Failed to clean up channel topics for non-consumer flavor: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
  }

  /// Synchronizes FCM broadcast topic subscriptions for all active channel subscriptions.
  /// Ensures device receives instant push notifications when subscribed creators post content.
  Future<void> syncSubscribedChannelTopics(String userId) async {
    if (!_isSupportedPlatform || userId.isEmpty || userId == 'guest_user') return;

    // FLAVOR ISOLATION:
    // Only the consumer video app ('app') should subscribe to channel upload broadcast topics.
    // Studio ('studio'), Admin, and Advertiser apps MUST NOT subscribe to consumer video channels.
    // If running in Studio/Admin/Advertiser, cleanly unsubscribe from any legacy channel topics.
    if (AppFlavor.active != AppFlavor.app) {
      logger.info(
        'Flavor "${AppFlavor.active.name}" is not consumer app - cleaning up channel topic subscriptions',
        tag: 'PUSH_NOTIFICATIONS',
      );
      unawaited(unsubscribeFromAllChannelTopicsIfNonConsumer(userId));
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.userSubscriptions(userId))
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final channelId = (data['channelId'] as String? ?? doc.id).trim();
        if (channelId.isEmpty) continue;

        final notifsEnabled = data['notificationsEnabled'] ?? true;
        final option = (data['notificationOption'] as String? ??
                data['notificationPreference'] as String? ??
                (notifsEnabled ? 'personalized' : 'none'))
            .toLowerCase();

        if (notifsEnabled && option != 'none') {
          await subscribeToChannelTopic(channelId);
        } else {
          await unsubscribeFromChannelTopic(channelId);
        }
      }
    } catch (e) {
      logger.warning(
        'Failed to sync subscribed channel topics for user $userId: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
  }

  /// Subscribes the current device to global broadcast push topics (`all_devices`, `flavor_$app`).
  /// Eliminates redundant overlapping platform topics to prevent duplicate broadcast delivery.
  Future<void> subscribeToBroadcastTopics() async {
    if (!_isSupportedPlatform) return;
    try {
      final messaging = FirebaseMessaging.instance;
      // 1. Universal broadcast topic across all installed devices (Android + iOS)
      await messaging.subscribeToTopic('all_devices');

      // Clean up legacy overlapping platform topics if previously subscribed
      unawaited(messaging.unsubscribeFromTopic('all_android').catchError((_) {}));
      unawaited(messaging.unsubscribeFromTopic('all_ios').catchError((_) {}));

      // 2. App flavor broadcast topic (e.g. flavor_app, flavor_studio)
      final flavor = AppFlavor.active.name;
      await messaging.subscribeToTopic('flavor_$flavor');

      logger.info(
        'Successfully subscribed device to broadcast topics: all_devices, flavor_$flavor',
        tag: 'PUSH_NOTIFICATIONS',
      );
    } catch (e) {
      logger.warning(
        'Failed to subscribe to broadcast topics: $e',
        tag: 'PUSH_NOTIFICATIONS',
      );
    }
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
