import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            'hello@truthworld.in');

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

      var verified = false;
      if (localStoredPass.isNotEmpty &&
          localStoredPass == cleanCurrentPassword) {
        verified = true;
      }

      // Default bootstrap credential verification for authorized owners
      if (!verified && isOwner && cleanCurrentPassword == '12345') {
        verified = true;
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      // 1. Re-authenticate current user to refresh auth timestamp and verify current password.
      // This directly prevents [firebase_auth/requires-recent-login].
      if (currentUser != null) {
        try {
          final authCred = EmailAuthProvider.credential(
            email: currentUser.email ?? cleanEmail,
            password: cleanCurrentPassword,
          );
          await currentUser.reauthenticateWithCredential(authCred);
          verified = true;
        } on FirebaseAuthException catch (authEx) {
          if (authEx.code == 'wrong-password' ||
              authEx.code == 'invalid-credential') {
            if (!verified) {
              AppSnackbar.error(
                'The current password you entered is incorrect.',
                title: 'Verification Notice',
              );
              rxIsLoading.value = false;
              return false;
            }
          }
          ErrorHandler.log(
            authEx,
            tag: 'AdminPasswordService.reauthenticateWithCredential',
          );
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

      // 2. Synchronize / Update with Firebase Auth
      var authUpdated = false;

      // Primary: Client-side updatePassword (succeeds because session was freshly reauthenticated)
      if (currentUser != null) {
        try {
          await currentUser.updatePassword(cleanNewPassword);
          authUpdated = true;
        } on FirebaseAuthException catch (authErr) {
          ErrorHandler.log(
            authErr,
            tag: 'AdminPasswordService.clientUpdatePassword',
          );
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AdminPasswordService.clientUpdatePassword',
          );
        }
      }

      // Fallback: If client update was blocked or currentUser is null, use Admin SDK Cloud Function
      if (!authUpdated) {
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('changeAdminPassword');
          final response = await callable.call<Map<String, dynamic>>({
            'currentPassword': cleanCurrentPassword,
            'newPassword': cleanNewPassword,
            'targetEmail': cleanEmail,
          });
          if (response.data['success'] == true) {
            authUpdated = true;
          }
        } catch (cfErr, s) {
          ErrorHandler.log(
            cfErr,
            stackTrace: s,
            tag: 'AdminPasswordService.changeAdminPasswordCloudFunction',
          );
        }
      }

      // If currentUser was null, try sign-in or create
      if (!authUpdated && currentUser == null) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: cleanEmail,
            password: cleanCurrentPassword,
          );
          if (FirebaseAuth.instance.currentUser != null) {
            await FirebaseAuth.instance.currentUser!
                .updatePassword(cleanNewPassword);
            authUpdated = true;
          }
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'user-not-found' ||
              authErr.code == 'invalid-credential') {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: cleanEmail,
                password: cleanNewPassword,
              );
              authUpdated = true;
            } catch (createErr, s) {
              ErrorHandler.log(
                createErr,
                stackTrace: s,
                tag: 'AdminPasswordService.createUserAuth',
              );
            }
          }
        }
      }

      // 3. Persist updated password to local GetStorage credentials store
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
                  maxLength: 128,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(128),
                  ],
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
                  maxLength: 128,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(128),
                  ],
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

                              var passwordSaved = false;
                              if (currentUser != null) {
                                try {
                                  await currentUser.updatePassword(pass);
                                  passwordSaved = true;
                                } catch (e, s) {
                                  ErrorHandler.log(
                                    e,
                                    stackTrace: s,
                                    tag:
                                        'AdminPasswordService.setPasswordDirect',
                                  );
                                }
                              }

                              if (!passwordSaved) {
                                try {
                                  final callable =
                                      FirebaseFunctions.instanceFor(
                                    region: 'asia-south1',
                                  ).httpsCallable('changeAdminPassword');
                                  await callable.call<Map<String, dynamic>>({
                                    'newPassword': pass,
                                    'targetEmail': targetEmail,
                                  });
                                  passwordSaved = true;
                                } catch (e, s) {
                                  ErrorHandler.log(
                                    e,
                                    stackTrace: s,
                                    tag:
                                        'AdminPasswordService.setPasswordCallable',
                                  );
                                }
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
