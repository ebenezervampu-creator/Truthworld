import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Mixin providing administrative audit logging to `admin_actions_log`.
mixin AdminAuditLogMixin on GetxController {
  Future<void> logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final payload = <String, dynamic>{
        'adminId': user?.uid ?? 'admin',
        'adminEmail': user?.email ?? 'hello@truthworld.in',
        'action': action,
        'reason': reason ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'targetId': targetId,
        'userId': userId,
        ...?extra,
      };
      await FirebaseFirestore.instance
          .collection('admin_actions_log')
          .add(payload);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminAuditLogMixin.logAdminAction',
      );
    }
  }
}
