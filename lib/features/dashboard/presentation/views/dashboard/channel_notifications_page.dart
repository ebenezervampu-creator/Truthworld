import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';

export 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';

/// Creator Studio Channel Notifications — can be embedded inside [DashboardViewRouter]
/// (tab 16) or pushed as a fully standalone page via `/studio/notifications`.
///
/// When opened standalone the channelId / creatorId are resolved from:
///   1. Constructor arguments (embedded Studio use-case).
///   2. GetX route arguments (`Get.arguments` map) — deep-link / notification tap.
///   3. Active Studio / User context (`DashboardController` or `AuthService`).
class ChannelNotificationsPage extends StatelessWidget {
  const ChannelNotificationsPage({
    this.channelId = '',
    this.creatorId = '',
    super.key,
  });

  final String channelId;
  final String creatorId;

  String get _resolvedChannelId {
    if (channelId.isNotEmpty) return channelId;
    final args = Get.arguments;
    if (args is Map) {
      final ch = args['channelId'] as String?;
      if (ch != null && ch.isNotEmpty) return ch;
    }
    if (Get.isRegistered<DashboardController>()) {
      final id = Get.find<DashboardController>().channelId;
      if (id.isNotEmpty) return id;
    }
    if (Get.isRegistered<AuthService>()) {
      final ch = AuthService.to.userChannel ?? AuthService.to.rxUserChannel.value;
      if (ch != null && ch.id.isNotEmpty) return ch.id;
    }
    return '';
  }

  String get _resolvedCreatorId {
    if (creatorId.isNotEmpty) return creatorId;
    final args = Get.arguments;
    if (args is Map) {
      final cr = args['creatorId'] as String?;
      if (cr != null && cr.isNotEmpty) return cr;
    }
    if (Get.isRegistered<AuthService>()) {
      final uid = AuthService.to.uid;
      if (uid.isNotEmpty) return uid;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return VideoFeedNotificationScreen(
      channelId: _resolvedChannelId,
      creatorId: _resolvedCreatorId,
    );
  }
}
