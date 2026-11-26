import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

import 'package:truthworld/features/admin/presentation/controllers/auth/admin_team_service.dart';

/// Service executing administrator sign-in, Google sign-in, session restore,
/// sign-out, and claim checks.
class AdminAuthProtocolService {
  const AdminAuthProtocolService._();

  /// Restores cached administrator session from GetStorage
  static void restoreAdminSession({
    required RxBool isAdmin,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required RxList<String> currentAdminRoles,
    required VoidCallback onStartSubscriptions,
  }) {
    try {
      final storage = GetStorage();
      final session =
          storage.read<Map<dynamic, dynamic>>('truthworld_admin_session');
      if (session != null && session['email'] != null) {
        final email = session['email'].toString();
        final role = (session['role'] ?? 'Super Admin').toString();
        final rawRoles = session['roles'];
        var rolesList = <String>[];
        if (rawRoles is List) {
          rolesList = rawRoles.map((e) => e.toString()).toList();
        } else if (role.isNotEmpty) {
          rolesList = role
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        if (rolesList.isEmpty) rolesList = [role];

        isAdmin.value = true;
        currentAdminEmail.value = email;
        currentAdminRole.value = role;
        currentAdminRoles.assignAll(rolesList);
        onStartSubscriptions();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminAuthProtocolService.restoreAdminSession',
      );
    }
  }

  /// Navigates to dashboard if currently on the admin login screen
  static void navigateToDashboardIfOnLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = Get.currentRoute;
      if (route == '/admin' || route == '/admin/login' || route.isEmpty) {
        Get.offAllNamed('/admin/dashboard');
      }
    });
  }

  /// Step 1 of the 2-step Admin Portal login flow.
  /// Validates whether the provided username or email belongs to an active administrator.
  static Future<bool> verifyAdminUsername({
    required TextEditingController usernameController,
    required RxString loginUsername,
    required RxInt loginStep,
    required Rxn<Map<String, dynamic>> verifiedAdminUser,
    required RxBool isVerifyingUsername,
    required TextEditingController emailController,
    required RxString loginEmail,
    String? usernameInput,
  }) async {
    final rawInput = (usernameInput != null && usernameInput.trim().isNotEmpty)
        ? usernameInput
        : (usernameController.text.trim().isNotEmpty
            ? usernameController.text
            : loginUsername.value);
    final input = rawInput.trim().toLowerCase();

    if (input.isEmpty) {
      AppSnackbar.warning(
        'Please enter your administrator username.',
        title: 'Username Required',
      );
      return false;
    }

    isVerifyingUsername.value = true;
    try {
      // 1. Fast check for bootstrap accounts
      if (input == 'hello1' || input == 'hello@truthworld.in') {
        final userData = {
          'email': 'hello@truthworld.in',
          'username': 'hello1',
          'displayName': 'TruthWorld Director',
          'role': 'Owner / Super Admin',
          'status': 'active',
        };
        verifiedAdminUser.value = userData;
        emailController.text = 'hello@truthworld.in';
        loginEmail.value = 'hello@truthworld.in';
        loginStep.value = 2;
        return true;
      }

      if (input == 'ebenezer' || input == 'ebenezervampu4@gmail.com') {
        final userData = {
          'email': 'ebenezervampu4@gmail.com',
          'username': 'ebenezer',
          'displayName': 'Ebenezer Vampu',
          'role': 'Owner / Super Admin',
          'status': 'active',
        };
        verifiedAdminUser.value = userData;
        emailController.text = 'ebenezervampu4@gmail.com';
        loginEmail.value = 'ebenezervampu4@gmail.com';
        loginStep.value = 2;
        return true;
      }

      // 2. Call Cloud Function to verify username securely
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('verifyAdminUsername');
        final res = await callable.call<Map<String, dynamic>>({
          'username': input,
        });
        final data = Map<String, dynamic>.from(res.data);
        if (data['valid'] == true) {
          verifiedAdminUser.value = data;
          final resolvedEmail = (data['email'] ?? '').toString();
          emailController.text = resolvedEmail;
          loginEmail.value = resolvedEmail;
          loginStep.value = 2;
          return true;
        } else {
          final msg = data['message']?.toString() ??
              'Administrator username not found or inactive.';
          AppSnackbar.error(msg, title: 'Access Restricted');
          return false;
        }
      } catch (funcErr, s) {
        ErrorHandler.log(
          funcErr,
          stackTrace: s,
          tag: 'AdminAuthProtocolService.verifyAdminUsername.callable',
        );

        // Fallback: If network issue or offline, query Firestore if already authenticated or check direct document
        try {
          final doc = await FirebaseFirestore.instance
              .collection('admin_members')
              .doc(input)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['status'] == 'suspended') {
              AppSnackbar.error(
                'This administrator account has been suspended by the team.',
                title: 'Access Restricted',
              );
              return false;
            }
            final resolvedEmail = (data['email'] ?? input).toString();
            final userData = {
              'email': resolvedEmail,
              'username': (data['username'] ?? input).toString(),
              'displayName': (data['name'] ?? data['username'] ?? 'Administrator').toString(),
              'role': (data['role'] ?? 'Admin').toString(),
              'status': 'active',
            };
            verifiedAdminUser.value = userData;
            emailController.text = resolvedEmail;
            loginEmail.value = resolvedEmail;
            loginStep.value = 2;
            return true;
          }
        } catch (fsErr) {
          ErrorHandler.log(fsErr, tag: 'AdminAuthProtocolService.verifyAdminUsername.fallback');
        }

        AppSnackbar.error(
          'Administrator username not found. Please verify your credentials.',
          title: 'Sign In Notice',
        );
        return false;
      }
    } finally {
      isVerifyingUsername.value = false;
    }
  }

  /// Authenticates using the TruthWorld Admin Security Protocol
  static Future<void> signInWithAdminProtocol({
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required RxString loginEmail,
    required RxString loginPassword,
    required RxBool rxIsLoading,
    required RxBool isAdmin,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required RxList<String> currentAdminRoles,
    required List<String> authorizedOwnerEmails,
    required VoidCallback onStartSubscriptions,
    String? emailInput,
    String? passwordInput,
  }) async {
    final rawEmail = (emailInput != null && emailInput.trim().isNotEmpty)
        ? emailInput
        : (emailController.text.trim().isNotEmpty
            ? emailController.text
            : loginEmail.value);
    var email = rawEmail.trim().toLowerCase();
    if (email.contains('@') && !email.contains('.')) {
      email = '$email.com';
    }
    final rawPassword =
        (passwordInput != null && passwordInput.trim().isNotEmpty)
            ? passwordInput
            : (passwordController.text.trim().isNotEmpty
                ? passwordController.text
                : loginPassword.value);
    final password = rawPassword.trim();

    if (email.isEmpty || password.isEmpty) {
      AppSnackbar.warning(
        'Please enter both administrator email and password.',
        title: 'Sign In Required',
      );
      return;
    }

    rxIsLoading.value = true;
    try {
      final isOwner = authorizedOwnerEmails.contains(email);

      // 1. Authenticate with Firebase Authentication
      var user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email?.toLowerCase() != email) {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = cred.user;
        } on FirebaseAuthException catch (authErr) {
          if ((authErr.code == 'user-not-found' ||
                  authErr.code == 'invalid-credential' ||
                  authErr.code == 'wrong-password') &&
              isOwner) {
            try {
              // Trigger backend bootstrap sync to ensure Auth user & password
              final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
                  .httpsCallable('verifyAdminUsername');
              await callable.call<Map<String, dynamic>>({'username': email});

              final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              user = cred.user;
            } catch (retryErr) {
              try {
                final cred =
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );
                user = cred.user;
              } catch (createErr, s) {
                ErrorHandler.log(
                  createErr,
                  stackTrace: s,
                  tag: 'AdminAuthProtocolService.ownerAutoRegistration',
                );
              }
            }
          }

          if (user == null) {
            ErrorHandler.log(authErr);
            AppSnackbar.error(
              'Invalid administrator credentials. Please check your email and password.',
              title: 'Sign In Notice',
            );
            rxIsLoading.value = false;
            return;
          }
        }
      }

      if (user == null) {
        AppSnackbar.error(
          'Unable to verify administrator identity. Please try again.',
          title: 'Sign In Notice',
        );
        rxIsLoading.value = false;
        return;
      }

      // 2. Query admin_members collection in Firestore
      Map<String, dynamic>? matchedMember;
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('admin_members')
            .doc(email)
            .get();

        if (docSnap.exists && docSnap.data() != null) {
          matchedMember = {'id': docSnap.id, ...docSnap.data()!};
        } else {
          final qSnap = await FirebaseFirestore.instance
              .collection('admin_members')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (qSnap.docs.isNotEmpty) {
            matchedMember = {
              'id': qSnap.docs.first.id,
              ...qSnap.docs.first.data(),
            };
          }
        }
      } catch (firestoreErr, s) {
        ErrorHandler.log(
          firestoreErr,
          stackTrace: s,
          tag: 'AdminAuthProtocolService.adminMembersQuery',
        );
      }

      final status =
          (matchedMember?['status'] ?? 'active').toString().toLowerCase();
      if (status == 'suspended') {
        await FirebaseAuth.instance.signOut();
        AppSnackbar.error(
          'This administrator account has been suspended by the team.',
          title: 'Access Restricted',
        );
        rxIsLoading.value = false;
        return;
      }

      final tokenResult = await user.getIdTokenResult(true);
      final hasClaim = tokenResult.claims?['admin'] == true;
      final isAuthorized =
          isOwner || hasClaim || (matchedMember != null && status == 'active');

      if (!isAuthorized) {
        await FirebaseAuth.instance.signOut();
        AppSnackbar.error(
          'You do not have administrative privileges on Truthworld.',
          title: 'Access Restricted',
        );
        rxIsLoading.value = false;
        return;
      }

      final memberRole = matchedMember?['role']?.toString() ??
          (isOwner ? 'Owner / Super Admin' : 'Admin');
      if (isOwner) {
        unawaited(
          AdminTeamService.ensureDefaultAdminSeeded(
            authorizedOwnerEmails: authorizedOwnerEmails,
          ),
        );
      }

      final rawRoles = matchedMember?['roles'];
      var rolesList = <String>[];
      if (rawRoles is List && rawRoles.isNotEmpty) {
        rolesList = rawRoles.map((e) => e.toString()).toList();
      } else if (memberRole.isNotEmpty) {
        rolesList = memberRole
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (rolesList.isEmpty) rolesList = [memberRole];

      isAdmin.value = true;
      currentAdminEmail.value = email;
      currentAdminRole.value = memberRole;
      currentAdminRoles.assignAll(rolesList);

      // Persist session to GetStorage
      try {
        GetStorage().write('truthworld_admin_session', {
          'email': email,
          'role': memberRole,
          'roles': rolesList,
          'loginAt': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'AdminAuthProtocolService.persistAdminSession',
        );
      }

      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'role': 'admin',
          'isAdmin': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError(
          (e, s) => ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AdminAuthProtocolService.updateUserAdminRole',
          ),
        ),
      );

      onStartSubscriptions();
      Get.offAllNamed('/admin/dashboard');

      AppSnackbar.success(
        'Logged into TruthWorld Admin Console as $email ($memberRole)',
        title: 'Welcome',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Authentication failed. Please check your credentials and try again.',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Authenticates using Google OAuth with administrator validation
  static Future<void> signInWithGoogle({
    required RxBool rxIsLoading,
    required RxBool isAdmin,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required RxList<String> currentAdminRoles,
    required List<String> authorizedOwnerEmails,
    required VoidCallback onStartSubscriptions,
  }) async {
    rxIsLoading.value = true;
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await AuthService.to.signOut();
      }
      await AuthService.to.signInWithGoogle();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final email = user.email?.toLowerCase() ?? '';
        final isOwner = authorizedOwnerEmails.contains(email);
        final tokenResult = await user.getIdTokenResult(true);
        final hasAdminClaim = tokenResult.claims?['admin'] == true;

        var isAuthorized = isOwner || hasAdminClaim;
        var memberRole = isOwner ? 'Owner / Super Admin' : 'Super Admin';
        var rolesList = <String>['Super Admin'];

        if (!isAuthorized) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('admin_members')
                .doc(email)
                .get();
            if (doc.exists &&
                (doc.data()?['status'] ?? 'active') != 'suspended') {
              isAuthorized = true;
              memberRole =
                  doc.data()?['role']?.toString() ?? 'Content Moderator';
              final rawRoles = doc.data()?['roles'];
              if (rawRoles is List && rawRoles.isNotEmpty) {
                rolesList = rawRoles.map((e) => e.toString()).toList();
              } else {
                rolesList = memberRole
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
            }
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'AdminAuthProtocolService.googleSignInMemberQuery',
            );
          }
        }

        if (isAuthorized) {
          isAdmin.value = true;
          currentAdminEmail.value = email;
          currentAdminRole.value = memberRole;
          currentAdminRoles.assignAll(rolesList);

          try {
            final storage = GetStorage();
            storage.write('truthworld_admin_session', {
              'email': email,
              'role': memberRole,
              'roles': rolesList,
              'loginAt': DateTime.now().millisecondsSinceEpoch,
            });
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'AdminAuthProtocolService.googleSignInPersistSession',
            );
          }

          // Update last login in user profile asynchronously
          unawaited(
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError(
              (e, s) => ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'AdminAuthProtocolService.googleSignInLastLogin',
              ),
            ),
          );

          onStartSubscriptions();
          Get.offAllNamed('/admin/dashboard');

          AppSnackbar.success(
            'Logged into TruthWorld Admin Console as $email ($memberRole)',
            title: 'Welcome',
          );
        } else {
          await AuthService.to.signOut();
          AppSnackbar.error(
            'Account ($email) does not have administrator privileges.',
            title: 'Access Restricted',
          );
        }
      }
    } catch (e) {
      if (e is GoogleSignInException && e.isCancelled) {
        return;
      }
      ErrorHandler.log(
        e,
        tag: 'AdminAuthProtocolService.signInWithGoogle',
      );
      AppSnackbar.error(
        'Unable to complete Google Sign In. Please try again.',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Signs out of the administrative console
  static Future<void> signOutAdmin({
    required RxBool rxIsLoading,
    required RxBool isAdmin,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required VoidCallback onClearSelectedItems,
    required VoidCallback onStopSubscriptions,
  }) async {
    rxIsLoading.value = true;
    try {
      onClearSelectedItems();

      try {
        final storage = GetStorage();
        storage.remove('truthworld_admin_session');
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'AdminAuthProtocolService.removeAdminSession',
        );
      }

      isAdmin.value = false;
      currentAdminEmail.value = '';
      currentAdminRole.value = 'Super Admin';

      onStopSubscriptions();
      await AuthService.to.signOut();
      Get.offAllNamed('/admin/login');
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminAuthProtocolService.signOutAdmin',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Directly verifies admin console claims and starts data streams
  static Future<void> checkAdminClaims({
    required RxBool isAuthChecking,
    required RxBool isAdmin,
    required RxString currentAdminEmail,
    required RxString currentAdminRole,
    required RxList<String> currentAdminRoles,
    required List<String> authorizedOwnerEmails,
    required VoidCallback onStartSubscriptions,
  }) async {
    isAuthChecking.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        isAdmin.value = false;
        return;
      }
      final email = user.email?.toLowerCase() ?? '';
      final isOwner = authorizedOwnerEmails.contains(email);
      final tokenResult = await user.getIdTokenResult(true);
      final hasClaim = tokenResult.claims?['admin'] == true;
      if (isOwner || hasClaim) {
        isAdmin.value = true;
        if (currentAdminEmail.value.isEmpty && email.isNotEmpty) {
          currentAdminEmail.value = email;
        }
        if (isOwner && currentAdminRoles.isEmpty) {
          currentAdminRole.value = 'Super Admin';
          currentAdminRoles.assignAll(['Super Admin']);
        }
        onStartSubscriptions();
      } else {
        // Fallback check in admin_members collection
        try {
          final doc = await FirebaseFirestore.instance
              .collection('admin_members')
              .doc(email)
              .get();
          if (doc.exists &&
              (doc.data()?['status'] ?? 'active') != 'suspended') {
            isAdmin.value = true;
            currentAdminEmail.value = email;
            final role = doc.data()?['role']?.toString() ?? 'Content Moderator';
            currentAdminRole.value = role;
            final rawRoles = doc.data()?['roles'];
            if (rawRoles is List && rawRoles.isNotEmpty) {
              currentAdminRoles
                  .assignAll(rawRoles.map((e) => e.toString()).toList());
            } else {
              currentAdminRoles.assignAll(
                role
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              );
            }
            onStartSubscriptions();
            return;
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AdminAuthProtocolService.checkAdminClaimsDoc',
          );
        }

        isAdmin.value = false;
        AppSnackbar.error(
          'Account does not have administrator privileges.',
          title: 'Access Restricted',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdminAuthProtocolService.checkAdminClaims',
      );
    } finally {
      isAuthChecking.value = false;
    }
  }
}
