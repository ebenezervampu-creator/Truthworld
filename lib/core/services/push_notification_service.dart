import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:truthworld/core/services/logger_service.dart';

class PushNotificationService extends GetxService {
  static PushNotificationService get to => Get.find<PushNotificationService>();

  /// Safe async initialization of FCM configuration and deep-link click handlers
  Future<PushNotificationService> init() async {
    if (kIsWeb) return this;

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
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationClick(message);
      });

      logger.info('PushNotificationService initialized successfully', tag: 'PUSH_NOTIFICATIONS');
    } catch (e) {
      logger.error('Failed to initialize PushNotificationService: $e', tag: 'PUSH_NOTIFICATIONS');
    }

    return this;
  }

  /// Request iOS/Android user permissions and register current device token to Firestore
  Future<void> registerToken(String userId) async {
    if (userId.isEmpty || userId == 'guest_user' || kIsWeb) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Prompt user for notification authorization
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(userId, token);
        }

        // Keep tokens up-to-date across lifecycle events
        messaging.onTokenRefresh.listen((newToken) async {
          await _saveTokenToFirestore(userId, newToken);
        });
      } else {
        logger.warning('User denied or restricted push notification permissions', tag: 'PUSH_NOTIFICATIONS');
      }
    } catch (e) {
      logger.error('Error registering push notification token: $e', tag: 'PUSH_NOTIFICATIONS');
    }
  }

  /// Clean up target device token from user document (usually on sign out)
  Future<void> unregisterToken(String userId) async {
    if (userId.isEmpty || userId == 'guest_user' || kIsWeb) return;

    try {
      final box = GetStorage();
      final deviceId = box.read('device_id') as String? ?? '';
      if (deviceId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmTokens.$deviceId': FieldValue.delete(),
        });
        logger.info('FCM token unregistered for device: $deviceId', tag: 'PUSH_NOTIFICATIONS');
      }
    } catch (e) {
      logger.error('Error unregistering FCM token: $e', tag: 'PUSH_NOTIFICATIONS');
    }
  }

  /// Persist the unique device token pairing inside Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      final box = GetStorage();
      var deviceId = box.read('device_id') as String? ?? '';
      if (deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        box.write('device_id', deviceId);
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmTokens.$deviceId': token,
      });
      logger.info('FCM token successfully registered to Firestore for device $deviceId', tag: 'PUSH_NOTIFICATIONS');
    } catch (e) {
      logger.error('Failed to sync FCM token to Firestore: $e', tag: 'PUSH_NOTIFICATIONS');
    }
  }

  /// Resolvedeep-linking routing paths upon notification tap
  void _handleNotificationClick(RemoteMessage message) {
    try {
      final data = message.data;
      final actionUrl = data['actionUrl'] as String?;
      if (actionUrl != null && actionUrl.isNotEmpty) {
        logger.info('Deep-linking user to page path: $actionUrl', tag: 'PUSH_NOTIFICATIONS');
        Get.toNamed(actionUrl);
      }
    } catch (e) {
      logger.error('Failed to navigate using actionUrl: $e', tag: 'PUSH_NOTIFICATIONS');
    }
  }
}
