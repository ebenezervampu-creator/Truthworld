import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';

class FcmNotificationService extends GetxService {
  static FcmNotificationService get to => Get.find();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxString permissionStatus =
      'default'.obs; // 'default', 'granted', 'denied'
  final RxString fcmToken = ''.obs;
  final RxBool isInitializing = false.obs;

  // Standard Web VAPID Push Key configuration
  static const String webVapidKey =
      'BDa8TlS51mqtayMF7Ckf3X8ni9ALdQxuzhSnrlDdCG1teCZ4boYrD4dg99aVeD_zAaAXFueEC9dsK3qKH6_A9wg';

  Future<FcmNotificationService> init() async {
    if (kIsWeb) {
      // Skip FCM Push configuration on Web since we only want in-app notifications
      permissionStatus.value = 'default';
      return this;
    }
    await updatePermissionStatus();
    _listenToAuthChanges();
    _setupForegroundListener();
    return this;
  }

  void _listenToAuthChanges() {
    if (kIsWeb) return;
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        if (permissionStatus.value == 'granted') {
          registerFcmToken();
        }
      } else {
        fcmToken.value = '';
      }
    });
  }

  Future<void> updatePermissionStatus() async {
    if (kIsWeb) {
      permissionStatus.value = 'default';
      return;
    }
    permissionStatus.value = 'default';
  }

  Future<bool> requestPushPermission(BuildContext context) async {
    if (kIsWeb) {
      // In-app notifications only on Web, no external push requests
      return false;
    }
    isInitializing.value = true;
    try {
      bool confirm = await _showInAppPrompt(context);
      if (!confirm) {
        isInitializing.value = false;
        return false;
      }

      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        permissionStatus.value = 'granted';
        await registerFcmToken();
        isInitializing.value = false;
        return true;
      } else {
        permissionStatus.value = 'denied';
        isInitializing.value = false;
        return false;
      }
    } catch (e) {
      logger.error('Failed requesting notification permission: $e', tag: 'FCM');
      isInitializing.value = false;
      return false;
    }
  }

  Future<void> registerFcmToken() async {
    if (kIsWeb) return;
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      String? token;
      token = await _messaging.getToken();

      if (token != null && token.isNotEmpty) {
        fcmToken.value = token;

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('fcm_tokens')
            .doc(token)
            .set({
              'token': token,
              'platform': kIsWeb
                  ? 'web'
                  : defaultTargetPlatform.name.toLowerCase(),
              'updatedAt': FieldValue.serverTimestamp(),
              'deviceInfo': kIsWeb ? 'Browser Web client' : 'Mobile client',
            }, SetOptions(merge: true));

        debugPrint('FCM Token successfully synced: $token');
      }
    } catch (e) {
      if (e.toString().contains('applicationServerKey') ||
          e.toString().contains('InvalidAccessError')) {
        debugPrint(
          '⚠️ [FCM] Failed to sync FCM Token: The provided Web VAPID key is invalid or FCM is not configured for this domain.',
        );
      } else {
        logger.error('Failed to sync FCM Token: $e', tag: 'FCM');
      }
    }
  }

  Future<void> removeFcmToken() async {
    final user = _auth.currentUser;
    final token = fcmToken.value;
    if (user == null || token.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens')
          .doc(token)
          .delete();

      fcmToken.value = '';
      permissionStatus.value = 'default';
      debugPrint('FCM Token removed from Firestore');
    } catch (e) {
      logger.error('Failed to delete FCM Token: $e', tag: 'FCM');
    }
  }

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground FCM message received: ${message.messageId}');

      final notification = message.notification;
      if (notification != null) {
        _showForegroundToast(
          title: notification.title ?? 'New Notification',
          body: notification.body ?? '',
        );
      }
    });
  }

  Future<bool> _showInAppPrompt(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color(0xFF1E1B4B),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F0F1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF6366F1),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enable Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Receive instant alerts when dynamic video resolution processing is done, copyright updates occur, or your community posts comments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'No, Thanks',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                              shadowColor: const Color(
                                0xFF6366F1,
                              ).withOpacity(0.4),
                            ),
                            child: const Text(
                              'Authorize',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  void _showForegroundToast({required String title, required String body}) {
    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.95),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      borderColor: const Color(0xFF8B5CF6).withOpacity(0.3),
      borderWidth: 1.5,
      icon: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_active_rounded,
          color: Color(0xFF8B5CF6),
          size: 20,
        ),
      ),
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          Get.toNamed('/notifications');
        },
        child: const Text(
          'VIEW',
          style: TextStyle(
            color: Color(0xFF8B5CF6),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
      ),
      messageText: Text(
        body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
