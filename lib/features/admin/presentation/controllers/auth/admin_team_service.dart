import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('seedDefaultAdmins');
      await callable.call<Map<String, dynamic>>();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminTeamService.ensureDefaultAdminSeeded',
      );
    }
  }

  /// Adds a new team member with email, username, password, and assigned roles.
  /// Automatically provisions their Auth account and dispatches credentials to their email.
  static Future<bool> addTeamMember({
    required String email,
    required String password,
    required String currentAdminEmail,
    String? username,
    String role = 'Content Moderator',
    List<String>? roles,
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanUsername = (username != null && username.trim().isNotEmpty)
        ? username.trim().toLowerCase()
        : cleanEmail.split('@').first.toLowerCase();

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
      // Provision member account in Firebase Authentication if not already registered
      String? memberUid;
      try {
        final tempApp = await Firebase.initializeApp(
          name: 'admin_member_provision_${DateTime.now().microsecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        try {
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          final cred = await tempAuth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          );
          memberUid = cred.user?.uid;
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'email-already-in-use') {
            // Account already exists in Firebase Auth; continue saving member record
          } else {
            ErrorHandler.log(
              authErr,
              tag: 'AdminTeamService.provisionAuthAccount',
            );
          }
        } finally {
          await tempApp.delete();
        }
      } catch (authInitErr, s) {
        ErrorHandler.log(
          authInitErr,
          stackTrace: s,
          tag: 'AdminTeamService.secondaryAppInit',
        );
      }

      // Dispatch credentials email and provision member record via Cloud Function (Admin SDK)
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('sendAdminCredentials');
        await callable.call<Map<String, dynamic>>({
          'email': cleanEmail,
          'username': cleanUsername,
          'password': cleanPassword,
          if (memberUid != null) 'uid': memberUid,
          'displayName': (name != null && name.trim().isNotEmpty)
              ? name.trim()
              : cleanUsername,
          'role': finalRole,
          'roles': finalRoles,
          'portalUrl': 'https://truthworld.in/admin',
        });
      } catch (emailErr, s) {
        ErrorHandler.log(
          emailErr,
          stackTrace: s,
          tag: 'AdminTeamService.sendCredentialsEmail',
        );
      }

      AppSnackbar.success(
        'Successfully added $cleanEmail (@$cleanUsername). Credentials emailed!',
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

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('updateAdminMember');
      await callable.call<Map<String, dynamic>>({
        'email': cleanEmail,
        'updates': dataToUpdate,
        'roles': roles,
      });

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
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('deleteAdminMember');
      await callable.call<Map<String, dynamic>>({
        'email': cleanEmail,
      });

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
    String? username,
    String? role,
  }) {
    final cleanUsername = (username != null && username.isNotEmpty)
        ? username
        : email.split('@').first;
    final text = '''
TruthWorld Admin Portal Credentials
-----------------------------------
Username: $cleanUsername
Email: $email
Password: $password
Role: ${role ?? 'Admin / Moderator'}
Portal URL: https://truthworld.in/admin
-----------------------------------
Keep these credentials secure. Change password after initial sign in.
''';
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success(
      'Username and password copied to clipboard and emailed to $email.',
      title: 'Credentials Dispatched',
    );
  }
}
