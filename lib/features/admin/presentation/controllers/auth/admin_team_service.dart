import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Service managing administrator team membership, roles sync, credentials sharing,
/// and default administrator seeding.
class AdminTeamService {
  const AdminTeamService._();

  /// Starts listening to the admin_members Firestore collection in real-time
  static StreamSubscription<QuerySnapshot> listenToAdminMembers({
    required RxList<Map<String, dynamic>> adminMembers,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required RxList<String> currentAdminRoles,
    required RxBool isAdmin,
    required List<String> authorizedOwnerEmails,
  }) {
    return FirebaseFirestore.instance
        .collection('admin_members')
        .snapshots()
        .listen(
      (snapshot) {
        final list =
            snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        adminMembers.assignAll(list);

        // Real-time synchronization of current administrator's assigned roles
        final targetEmail = currentAdminEmail.value.isNotEmpty
            ? currentAdminEmail.value.toLowerCase()
            : FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

        if (targetEmail.isNotEmpty) {
          final isOwner = authorizedOwnerEmails.contains(targetEmail);
          final me = list.firstWhereOrNull(
            (m) =>
                (m['email'] ?? '').toString().toLowerCase() == targetEmail,
          );
          if (isOwner || me != null) {
            final isSuspended = me != null &&
                (me['status'] ?? 'active').toString().toLowerCase() ==
                    'suspended';
            if (!isSuspended) {
              isAdmin.value = true;
              if (currentAdminEmail.value.isEmpty) {
                currentAdminEmail.value = targetEmail;
              }
              if (isOwner && currentAdminRoles.isEmpty) {
                currentAdminRole.value = 'Super Admin';
                currentAdminRoles.assignAll(['Super Admin']);
              }
              if (me != null) {
                final roleStr = (me['role'] ?? '').toString();
                if (roleStr.isNotEmpty) currentAdminRole.value = roleStr;
                final rawRoles = me['roles'];
                if (rawRoles is List && rawRoles.isNotEmpty) {
                  currentAdminRoles
                      .assignAll(rawRoles.map((e) => e.toString()).toList());
                } else if (roleStr.isNotEmpty) {
                  currentAdminRoles.assignAll(
                    roleStr
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  );
                }
              }
            }
          }
        }
      },
      onError: (err, stackTrace) {
        ErrorHandler.log(
          err,
          stackTrace: stackTrace,
          tag: 'AdminTeamService.adminMembersStream',
        );
      },
    );
  }

  /// Ensures initial default administrator accounts exist in Firestore
  static Future<void> ensureDefaultAdminSeeded({
    required List<String> authorizedOwnerEmails,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final defaultAdmins = [
        {'email': 'hello@truthworld.in', 'name': 'Ebenezer Vampu'},
        {'email': 'ebenezervampu4@gmail.com', 'name': 'Ebenezer Vampu'},
      ];
      for (final admin in defaultAdmins) {
        final docRef = FirebaseFirestore.instance
            .collection('admin_members')
            .doc(admin['email']);
        final snap = await docRef.get();
        if (!snap.exists) {
          await docRef.set({
            'email': admin['email'],
            'name': admin['name'],
            'role': 'Owner / Super Admin',
            'roles': ['Super Admin'],
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'permissions': ['all'],
          }, SetOptions(merge: true));
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminTeamService.ensureDefaultAdminSeeded',
      );
    }
  }

  /// Adds a new team member with email, password, and assigned roles
  static Future<bool> addTeamMember({
    required String email,
    required String password,
    required String currentAdminEmail,
    String role = 'Content Moderator',
    List<String>? roles,
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      AppSnackbar.warning(
        'Please enter both member email and password.',
      );
      return false;
    }

    final finalRoles = (roles != null && roles.isNotEmpty)
        ? roles
        : (role.isNotEmpty
            ? role
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : ['Content Moderator']);

    final finalRole = finalRoles.contains('Super Admin')
        ? 'Super Admin'
        : (finalRoles.isNotEmpty ? finalRoles.join(', ') : role);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('admin_members')
          .doc(cleanEmail);
      await docRef.set({
        'email': cleanEmail,
        'password': cleanPassword,
        'role': finalRole,
        'roles': finalRoles,
        'name': (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : cleanEmail.split('@').first,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminEmail.isNotEmpty
            ? currentAdminEmail
            : 'Super Admin',
      }, SetOptions(merge: true));

      AppSnackbar.success(
        'Successfully added $cleanEmail with ${finalRoles.length} assigned role(s).',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to add team member. Please try again.',
      );
      return false;
    }
  }

  /// Updates an existing team member's role, roles list, password, or status
  static Future<bool> updateTeamMember({
    required String email,
    required Map<String, dynamic> updates,
    List<String>? roles,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final dataToUpdate = Map<String, dynamic>.from(updates);
      if (roles != null && roles.isNotEmpty) {
        dataToUpdate['roles'] = roles;
        dataToUpdate['role'] = roles.contains('Super Admin')
            ? 'Super Admin'
            : roles.join(', ');
      }
      await FirebaseFirestore.instance
          .collection('admin_members')
          .doc(cleanEmail)
          .set({
        ...dataToUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppSnackbar.success(
        'Details for $cleanEmail have been updated.',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update member. Please try again.',
      );
      return false;
    }
  }

  /// Removes a team member's admin access
  static Future<bool> deleteTeamMember({
    required String email,
    required List<String> authorizedOwnerEmails,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (authorizedOwnerEmails.contains(cleanEmail)) {
      AppSnackbar.warning(
        'Primary Owner account cannot be removed.',
      );
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('admin_members')
          .doc(cleanEmail)
          .delete();

      AppSnackbar.success(
        '$cleanEmail has been removed from the Admin Team.',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to remove member. Please try again.',
      );
      return false;
    }
  }

  /// Formats member credentials and copies to clipboard for sharing
  static void copyMemberCredentials({
    required String email,
    required String password,
    String? role,
  }) {
    final text = '''
TruthWorld Admin Portal Credentials
-----------------------------------
Email: $email
Password: $password
Role: ${role ?? 'Admin / Moderator'}
Portal URL: https://truthworld.in/admin
-----------------------------------
Keep these credentials secure. Change password after initial sign in.
''';
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success(
      'Email and password copied to clipboard. Ready to share with team member!',
      title: 'Credentials Copied',
    );
  }
}
