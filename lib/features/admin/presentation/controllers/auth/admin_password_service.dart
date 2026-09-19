import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Service managing administrator password changes, credentials synchronization,
/// and the initial setup password dialog.
class AdminPasswordService {
  const AdminPasswordService._();

  /// Changes the password for the current logged-in administrator
  static Future<bool> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required RxList<String> currentAdminRoles,
    required List<String> authorizedOwnerEmails,
    required RxBool rxIsLoading,
  }) async {
    final email = currentAdminEmail.value.isNotEmpty
        ? currentAdminEmail.value
        : (FirebaseAuth.instance.currentUser?.email ??
            'ebenezervampu@towervsp.com');

    final cleanNewPassword = newPassword.trim();
    final cleanCurrentPassword = currentPassword.trim();

    if (cleanNewPassword.isEmpty) {
      AppSnackbar.warning(
        'New password cannot be empty.',
        title: 'Password Required',
      );
      return false;
    }

    if (cleanNewPassword.length < 6) {
      AppSnackbar.warning(
        'New password must be at least 6 characters long.',
        title: 'Password Too Short',
      );
      return false;
    }

    rxIsLoading.value = true;
    try {
      final cleanEmail = email.trim().toLowerCase();
      final isOwner = authorizedOwnerEmails.contains(cleanEmail);
      final storage = GetStorage();

      // Check current password from local credentials store first
      final creds = Map<String, dynamic>.from(
        storage.read<Map<String, dynamic>>('truthworld_admin_credentials') ??
            {},
      );
      final localStoredPass = creds[cleanEmail]?.toString() ?? '';

      final docRef = FirebaseFirestore.instance
          .collection('admin_members')
          .doc(cleanEmail);
      DocumentSnapshot<Map<String, dynamic>>? snap;
      try {
        snap = await docRef.get();
      } catch (fsErr, s) {
        ErrorHandler.log(
          fsErr,
          stackTrace: s,
          tag: 'AdminPasswordService.readAdminMembersDoc',
        );
      }

      var verified = false;
      if (snap != null && snap.exists && snap.data() != null) {
        final storedPass = snap.data()?['password']?.toString() ?? '';
        if (storedPass.isNotEmpty && storedPass == cleanCurrentPassword) {
          verified = true;
        }
      }

      if (!verified &&
          localStoredPass.isNotEmpty &&
          localStoredPass == cleanCurrentPassword) {
        verified = true;
      }

      // Default bootstrap credential verification for authorized owners
      if (!verified && isOwner && cleanCurrentPassword == '12345') {
        verified = true;
      }

      // If current user is already logged in with Firebase Auth and password matches
      if (!verified && FirebaseAuth.instance.currentUser != null) {
        try {
          final authCred = EmailAuthProvider.credential(
            email: cleanEmail,
            password: cleanCurrentPassword,
          );
          await FirebaseAuth.instance.currentUser!
              .reauthenticateWithCredential(authCred);
          verified = true;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AdminPasswordService.reauthenticateWithCredential',
          );
        }
      }

      if (!verified) {
        AppSnackbar.error(
          'The current password you entered is incorrect.',
          title: 'Verification Notice',
        );
        rxIsLoading.value = false;
        return false;
      }

      // 1. Synchronize / Update with Firebase Auth so client has active auth token
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.currentUser!
              .updatePassword(cleanNewPassword);
        } else {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: cleanEmail,
              password: cleanCurrentPassword,
            );
            if (FirebaseAuth.instance.currentUser != null) {
              await FirebaseAuth.instance.currentUser!
                  .updatePassword(cleanNewPassword);
            }
          } on FirebaseAuthException catch (authErr) {
            if (authErr.code == 'user-not-found' ||
                authErr.code == 'invalid-credential') {
              try {
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: cleanEmail,
                  password: cleanNewPassword,
                );
              } catch (createErr, s) {
                ErrorHandler.log(
                  createErr,
                  stackTrace: s,
                  tag: 'AdminPasswordService.createUserAuth',
                );
              }
            } else if (authErr.code == 'email-already-in-use') {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: cleanEmail,
                  password: cleanNewPassword,
                );
              } catch (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'AdminPasswordService.signInUpdatedUser',
                );
              }
            }
          }
        }
      } catch (authErr, s) {
        ErrorHandler.log(
          authErr,
          stackTrace: s,
          tag: 'AdminPasswordService.syncAuthCredentials',
        );
      }

      // 2. Persist updated password to local GetStorage credentials store
      try {
        creds[cleanEmail] = cleanNewPassword;
        storage.write('truthworld_admin_credentials', creds);

        final session = Map<String, dynamic>.from(
          storage.read<Map<String, dynamic>>('truthworld_admin_session') ?? {},
        );
        session['updatedPasswordAt'] = DateTime.now().millisecondsSinceEpoch;
        storage.write('truthworld_admin_session', session);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'AdminPasswordService.persistAdminCredentials',
        );
      }

      // 3. Update password in Firestore admin_members
      try {
        await docRef.set({
          'email': cleanEmail,
          'password': cleanNewPassword,
          'role': currentAdminRole.value.isNotEmpty
              ? currentAdminRole.value
              : (isOwner ? 'Super Admin' : 'Admin'),
          'roles': currentAdminRoles.isNotEmpty
              ? currentAdminRoles.toList()
              : ['Super Admin'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (fsWriteErr, s) {
        ErrorHandler.log(
          fsWriteErr,
          stackTrace: s,
          tag: 'AdminPasswordService.writeAdminMembersDoc',
        );
      }

      AppSnackbar.success(
        'Administrator password successfully updated! Use your new password on next login.',
        title: 'Password Changed',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to change password. Please try again.',
      );
      return false;
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Checks if the owner account needs initial admin password setup
  static Future<void> checkPasswordSetupStatus({
    required RxBool needsPasswordSetup,
    required RxString currentAdminEmail,
  }) async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('owner_config')
          .get();

      if (!ownerDoc.exists || ownerDoc.data()?['isPasswordSet'] != true) {
        needsPasswordSetup.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showSetPasswordDialog(
            needsPasswordSetup: needsPasswordSetup,
            currentAdminEmail: currentAdminEmail,
          );
        });
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminPasswordService.checkPasswordSetupStatus',
      );
    }
  }

  /// Prompts a modal dialog to set the admin password for ebenezervampu4@gmail.com
  static void showSetPasswordDialog({
    required RxBool needsPasswordSetup,
    required RxString currentAdminEmail,
  }) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isSaving = false.obs;
    final dialogError = ''.obs;

    unawaited(
      Get.dialog<void>(
        Dialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set Admin Password',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a secure password for ebenezervampu4@gmail.com to sign in directly to the Admin Portal.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New Admin Password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textPrimary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Confirm Admin Password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textPrimary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                Obx(
                  () => dialogError.value.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            dialogError.value,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 28),
                Obx(
                  () => ElevatedButton(
                    onPressed: isSaving.value
                        ? null
                        : () async {
                            final pass = newPassCtrl.text.trim();
                            final confirm = confirmPassCtrl.text.trim();
                            if (pass.length < 6) {
                              dialogError.value =
                                  'Password must be at least 6 characters.';
                              return;
                            }
                            if (pass != confirm) {
                              dialogError.value = 'Passwords do not match.';
                              return;
                            }
                            dialogError.value = '';
                            isSaving.value = true;

                            try {
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              final targetEmail = (currentUser?.email ??
                                      currentAdminEmail.value)
                                  .trim()
                                  .toLowerCase();

                              if (currentUser != null) {
                                await currentUser.updatePassword(pass);
                              }

                              // Cache in local credentials store
                              try {
                                final storage = GetStorage();
                                final creds = Map<String, dynamic>.from(
                                  storage.read<Map<String, dynamic>>(
                                        'truthworld_admin_credentials',
                                      ) ??
                                      {},
                                );
                                if (targetEmail.isNotEmpty) {
                                  creds[targetEmail] = pass;
                                  storage.write(
                                    'truthworld_admin_credentials',
                                    creds,
                                  );
                                }
                              } catch (e, s) {
                                ErrorHandler.log(
                                  e,
                                  stackTrace: s,
                                  tag:
                                      'AdminPasswordService.cacheAdminCredentials',
                                );
                              }

                              // Update Firestore admin_members
                              if (targetEmail.isNotEmpty) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('admin_members')
                                      .doc(targetEmail)
                                      .set({
                                    'email': targetEmail,
                                    'password': pass,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                } catch (e, s) {
                                  ErrorHandler.log(
                                    e,
                                    stackTrace: s,
                                    tag:
                                        'AdminPasswordService.updateAdminMemberPassword',
                                  );
                                }
                              }

                              try {
                                await FirebaseFirestore.instance
                                    .collection('admin_settings')
                                    .doc('owner_config')
                                    .set({
                                  'ownerEmail': targetEmail,
                                  'isPasswordSet': true,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                              } catch (e, s) {
                                ErrorHandler.log(
                                  e,
                                  stackTrace: s,
                                  tag:
                                      'AdminPasswordService.updateOwnerConfig',
                                );
                              }
                              needsPasswordSetup.value = false;
                              Get.back<void>();
                              AppSnackbar.success(
                                'Admin password set successfully! You can now log in with your email and password.',
                                title: 'Password Saved',
                              );
                            } catch (e, s) {
                              ErrorHandler.log(
                                e,
                                stackTrace: s,
                                tag:
                                    'AdminPasswordService.showSetPasswordDialog',
                              );
                              dialogError.value =
                                  'Failed to set admin password. Please try again.';
                            } finally {
                              isSaving.value = false;
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.black),
                            ),
                          )
                        : const Text(
                            'Save Admin Password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      ),
    );
  }
}
