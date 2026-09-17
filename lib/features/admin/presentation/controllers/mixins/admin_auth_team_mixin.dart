import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Mixin managing administrator authentication, credentials, RBAC roles, and team membership.
mixin AdminAuthTeamMixin on BaseController {
  /// Base controller contracts
  void startSubscriptions();
  void ensureSubscriptionsStarted();
  void stopSubscriptions();
  void clearSelectedItems();
  RxBool get rxIsLoading;

  Future<void> logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  });

  // Backward-compatible alias
  Future<void> _logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  }) =>
      logAdminAction(
        action: action,
        targetId: targetId,
        userId: userId,
        reason: reason,
        extra: extra,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth & Team State
  // ═══════════════════════════════════════════════════════════════════════════
  final RxBool isAuthChecking = false.obs;
  final RxBool isAdmin = false.obs;
  final RxList<Map<String, dynamic>> adminMembers = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingMembers = false.obs;
  final RxString currentAdminEmail = ''.obs;
  final RxString currentAdminRole = 'Super Admin'.obs;
  final RxList<String> currentAdminRoles = <String>[].obs;
  StreamSubscription<QuerySnapshot>? _adminMembersSub;

  static const List<String> authorizedOwnerEmails = [
    'ebenezervampy@towervsp.com',
    'ebenezervampu@towervsp.com',
    'ebenezervampu4@gmail.com',
  ];

  /// Returns true if the currently signed-in admin is the platform owner ("only me")
  bool get isPrimaryOwner {
    final email = currentAdminEmail.value.toLowerCase().trim();
    final authEmail =
        FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
    final activeEmail = email.isNotEmpty ? email : authEmail;
    return authorizedOwnerEmails.contains(activeEmail);
  }

  void stopAdminMembersSubscription() {
    _adminMembersSub?.cancel();
    _adminMembersSub = null;
  }
  void restoreAdminSession() {
    try {
      final storage = GetStorage();
      final session = storage.read<Map<dynamic, dynamic>>('truthworld_admin_session');
      if (session != null && session['email'] != null) {
        final email = session['email'].toString();
        final role = (session['role'] ?? 'Super Admin').toString();
        final rawRoles = session['roles'];
        var rolesList = <String>[];
        if (rawRoles is List) {
          rolesList = rawRoles.map((e) => e.toString()).toList();
        } else if (role.isNotEmpty) {
          rolesList = role.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        if (rolesList.isEmpty) rolesList = [role];

        isAdmin.value = true;
        currentAdminEmail.value = email;
        currentAdminRole.value = role;
        currentAdminRoles.assignAll(rolesList);
        startSubscriptions();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.restoreAdminSession');
    }
  }

  void listenToAdminMembers() {
    if (_adminMembersSub == null) {
      _adminMembersSub = FirebaseFirestore.instance
          .collection('admin_members')
          .snapshots()
          .listen((snapshot) {
        final list = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        adminMembers.assignAll(list);

        // Real-time synchronization of current administrator's assigned roles
        final targetEmail = currentAdminEmail.value.isNotEmpty
            ? currentAdminEmail.value.toLowerCase()
            : FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

        if (targetEmail.isNotEmpty) {
          final isOwner = authorizedOwnerEmails.contains(targetEmail);
          final me = list.firstWhereOrNull((m) => (m['email'] ?? '').toString().toLowerCase() == targetEmail);
          if (isOwner || me != null) {
            final isSuspended = me != null && (me['status'] ?? 'active').toString().toLowerCase() == 'suspended';
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
                  currentAdminRoles.assignAll(rawRoles.map((e) => e.toString()).toList());
                } else if (roleStr.isNotEmpty) {
                  currentAdminRoles.assignAll(roleStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
                }
              }
            }
          }
        }
      }, onError: (err, stackTrace) {
        ErrorHandler.log(err, stackTrace: stackTrace, tag: 'AdminAuthTeamMixin.adminMembersStream');
      });
      if (_adminMembersSub != null) trackSubscription(_adminMembersSub!);
    }
  }

  Future<void> ensureDefaultAdminSeeded() async {
    // Only attempt to seed defaults if authenticated with Firebase
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final defaultAdmins = [
        {'email': 'ebenezervampy@towervsp.com', 'name': 'Ebenezer Vampu'},
        {'email': 'ebenezervampu@towervsp.com', 'name': 'Ebenezer Vampu'},
        {'email': 'ebenezervampu4@gmail.com', 'name': 'Ebenezer Vampu'},
      ];
      for (final admin in defaultAdmins) {
        final docRef = FirebaseFirestore.instance.collection('admin_members').doc(admin['email']);
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
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.ensureDefaultAdminSeeded');
    }
  }

  void navigateToDashboardIfOnLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = Get.currentRoute;
      if (route == '/admin' || route == '/admin/login' || route.isEmpty) {
        Get.offAllNamed('/admin/dashboard');
      }
    });
  }


  // Email & Password login controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxString loginEmail = 'ebenezervampu@towervsp.com'.obs;
  final RxString loginPassword = '12345'.obs;
  final RxBool needsPasswordSetup = false.obs;

  /// Authenticates using the TruthWorld Admin Security Protocol.
  /// Validates against Firestore `admin_members` (including default ebenezervampy@towervsp.com / 12345),
  /// with Firebase Auth fallback and persistent session caching.
  Future<void> signInWithAdminProtocol({
    String? emailInput,
    String? passwordInput,
  }) async {
    final rawEmail = (emailInput != null && emailInput.trim().isNotEmpty)
        ? emailInput
        : (emailController.text.trim().isNotEmpty ? emailController.text : loginEmail.value);
    var email = rawEmail.trim().toLowerCase();
    if (email.contains('@') && !email.contains('.')) {
      email = '$email.com';
    }
    final rawPassword = (passwordInput != null && passwordInput.trim().isNotEmpty)
        ? passwordInput
        : (passwordController.text.trim().isNotEmpty ? passwordController.text : loginPassword.value);
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
          // If authorized owner account is being initialized for the first time
          if ((authErr.code == 'user-not-found' || authErr.code == 'invalid-credential') && isOwner) {
            try {
              final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
              user = cred.user;
            } catch (createErr, s) {
              ErrorHandler.log(createErr, stackTrace: s, tag: 'AdminAuthTeamMixin.ownerAutoRegistration');
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
            matchedMember = {'id': qSnap.docs.first.id, ...qSnap.docs.first.data()};
          }
        }
      } catch (firestoreErr, s) {
        ErrorHandler.log(firestoreErr, stackTrace: s, tag: 'AdminAuthTeamMixin.adminMembersQuery');
      }

      final status = (matchedMember?['status'] ?? 'active').toString().toLowerCase();
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
      final isAuthorized = isOwner || hasClaim || (matchedMember != null && status == 'active');

      if (!isAuthorized) {
        await FirebaseAuth.instance.signOut();
        AppSnackbar.error(
          'You do not have administrative privileges on Truthworld.',
          title: 'Access Restricted',
        );
        rxIsLoading.value = false;
        return;
      }

      final memberRole = matchedMember?['role']?.toString() ?? (isOwner ? 'Owner / Super Admin' : 'Admin');
      if (isOwner) {
        unawaited(ensureDefaultAdminSeeded());
      }

      if (isAuthorized) {

        final rawRoles = matchedMember?['roles'];
        var rolesList = <String>[];
        if (rawRoles is List && rawRoles.isNotEmpty) {
          rolesList = rawRoles.map((e) => e.toString()).toList();
        } else if (memberRole.isNotEmpty) {
          rolesList = memberRole.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.persistAdminSession');
        }

        // Update last login in Firestore asynchronously
        unawaited(
          FirebaseFirestore.instance
              .collection('admin_members')
              .doc(email)
              .set({
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e, s) => ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.updateLastLogin')),
        );

        unawaited(
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'role': 'admin',
            'isAdmin': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e, s) => ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.updateUserAdminRole')),
        );

        startSubscriptions();
        Get.offAllNamed('/admin/dashboard');

        AppSnackbar.success(
          'Logged into TruthWorld Admin Console as $email ($memberRole)',
          title: 'Welcome',
        );
      } else {
        AppSnackbar.error(
          'Invalid administrator credentials. Only authorized TruthWorld team members can enter.',
          title: 'Access Restricted',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Authentication failed. Please check your credentials and try again.',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Alias for [signInWithAdminProtocol] to preserve compatibility
  Future<void> signInWithEmailAndPassword({
    String? emailInput,
    String? passwordInput,
  }) =>
      signInWithAdminProtocol(
        emailInput: emailInput,
        passwordInput: passwordInput,
      );

  /// Changes the password for the current logged in administrator
  Future<bool> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentAdminEmail.value.isNotEmpty
        ? currentAdminEmail.value
        : (FirebaseAuth.instance.currentUser?.email ?? 'ebenezervampu@towervsp.com');

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
      final creds = Map<String, dynamic>.from(storage.read<Map<String, dynamic>>('truthworld_admin_credentials') ?? {});
      final localStoredPass = creds[cleanEmail]?.toString() ?? '';

      final docRef = FirebaseFirestore.instance.collection('admin_members').doc(cleanEmail);
      DocumentSnapshot<Map<String, dynamic>>? snap;
      try {
        snap = await docRef.get();
      } catch (fsErr, s) {
        ErrorHandler.log(fsErr, stackTrace: s, tag: 'AdminAuthTeamMixin.readAdminMembersDoc');
      }

      var verified = false;
      if (snap != null && snap.exists && snap.data() != null) {
        final storedPass = snap.data()?['password']?.toString() ?? '';
        if (storedPass.isNotEmpty && storedPass == cleanCurrentPassword) {
          verified = true;
        }
      }

      if (!verified && localStoredPass.isNotEmpty && localStoredPass == cleanCurrentPassword) {
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
          await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(authCred);
          verified = true;
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.reauthenticateWithCredential');
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
          await FirebaseAuth.instance.currentUser!.updatePassword(cleanNewPassword);
        } else {
          // Attempt sign in or create user in Firebase Auth
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: cleanEmail,
              password: cleanCurrentPassword,
            );
            if (FirebaseAuth.instance.currentUser != null) {
              await FirebaseAuth.instance.currentUser!.updatePassword(cleanNewPassword);
            }
          } on FirebaseAuthException catch (authErr) {
            if (authErr.code == 'user-not-found' || authErr.code == 'invalid-credential') {
              try {
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: cleanEmail,
                  password: cleanNewPassword,
                );
              } catch (createErr, s) {
                ErrorHandler.log(createErr, stackTrace: s, tag: 'AdminAuthTeamMixin.createUserAuth');
              }
            } else if (authErr.code == 'email-already-in-use') {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: cleanEmail,
                  password: cleanNewPassword,
                );
              } catch (e, s) {
                ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.signInUpdatedUser');
              }
            }
          }
        }
      } catch (authErr, s) {
        ErrorHandler.log(authErr, stackTrace: s, tag: 'AdminAuthTeamMixin.syncAuthCredentials');
      }

      // 2. Persist updated password to local GetStorage credentials store
      try {
        creds[cleanEmail] = cleanNewPassword;
        storage.write('truthworld_admin_credentials', creds);

        final session = Map<String, dynamic>.from(storage.read<Map<String, dynamic>>('truthworld_admin_session') ?? {});
        session['updatedPasswordAt'] = DateTime.now().millisecondsSinceEpoch;
        storage.write('truthworld_admin_session', session);
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.persistAdminCredentials');
      }

      // 3. Update password in Firestore admin_members
      try {
        await docRef.set({
          'email': cleanEmail,
          'password': cleanNewPassword,
          'role': currentAdminRole.value.isNotEmpty ? currentAdminRole.value : (isOwner ? 'Super Admin' : 'Admin'),
          'roles': currentAdminRoles.isNotEmpty ? currentAdminRoles.toList() : ['Super Admin'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (fsWriteErr, s) {
        ErrorHandler.log(fsWriteErr, stackTrace: s, tag: 'AdminAuthTeamMixin.writeAdminMembersDoc');
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

  /// Adds a new team member with email, password, and assigned roles
  Future<bool> addTeamMember({
    required String email,
    required String password,
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
            ? role.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : ['Content Moderator']);
    final finalRole = finalRoles.contains('Super Admin')
        ? 'Super Admin'
        : (finalRoles.isNotEmpty ? finalRoles.join(', ') : role);

    try {
      final docRef = FirebaseFirestore.instance.collection('admin_members').doc(cleanEmail);
      await docRef.set({
        'email': cleanEmail,
        'password': cleanPassword,
        'role': finalRole,
        'roles': finalRoles,
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : cleanEmail.split('@').first,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminEmail.value.isNotEmpty ? currentAdminEmail.value : 'Super Admin',
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
  Future<bool> updateTeamMember({
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
  Future<bool> deleteTeamMember(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == 'ebenezervampy@towervsp.com' || cleanEmail == 'ebenezervampu@towervsp.com') {
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
  void copyMemberCredentials({
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

  /// Directly verifies admin console claims and starts data streams
  Future<void> checkAdminClaims() async {
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
        startSubscriptions();
      } else {
        // Fallback check in admin_members collection
        try {
          final doc = await FirebaseFirestore.instance.collection('admin_members').doc(email).get();
          if (doc.exists && (doc.data()?['status'] ?? 'active') != 'suspended') {
            isAdmin.value = true;
            currentAdminEmail.value = email;
            final role = doc.data()?['role']?.toString() ?? 'Content Moderator';
            currentAdminRole.value = role;
            final rawRoles = doc.data()?['roles'];
            if (rawRoles is List && rawRoles.isNotEmpty) {
              currentAdminRoles.assignAll(rawRoles.map((e) => e.toString()).toList());
            } else {
              currentAdminRoles.assignAll(role.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
            }
            startSubscriptions();
            return;
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.checkAdminClaimsDoc');
        }

        isAdmin.value = false;
        AppSnackbar.error(
          'Account does not have administrator privileges.',
          title: 'Access Restricted',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.checkAdminClaims');
    } finally {
      isAuthChecking.value = false;
    }
  }

  /// Checks if the owner account needs initial admin password setup
  Future<void> _checkPasswordSetupStatus(User user) async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('owner_config')
          .get();

      if (!ownerDoc.exists || ownerDoc.data()?['isPasswordSet'] != true) {
        needsPasswordSetup.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showSetPasswordDialog();
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.checkPasswordSetupStatus');
    }
  }

  /// Prompts a dialog to set the admin password for ebenezervampu4@gmail.com
  void showSetPasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isSaving = false.obs;
    final dialogError = ''.obs;

    unawaited(
      Get.dialog(
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
                              final targetEmail = (currentUser?.email ?? currentAdminEmail.value).trim().toLowerCase();

                              if (currentUser != null) {
                                await currentUser.updatePassword(pass);
                              }

                              // Cache in local credentials store
                              try {
                                final storage = GetStorage();
                                final creds = Map<String, dynamic>.from(storage.read<Map<String, dynamic>>('truthworld_admin_credentials') ?? {});
                                if (targetEmail.isNotEmpty) {
                                  creds[targetEmail] = pass;
                                  storage.write('truthworld_admin_credentials', creds);
                                }
                              } catch (e, s) {
                                ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.cacheAdminCredentials');
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
                                  ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.updateAdminMemberPassword');
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
                                ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.updateOwnerConfig');
                              }
                              needsPasswordSetup.value = false;
                              Get.back();
                              AppSnackbar.success(
                                'Admin password set successfully! You can now log in with your email and password.',
                                title: 'Password Saved',
                              );
                            } catch (e, s) {
                              ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.showSetPasswordDialog');
                              dialogError.value = 'Failed to set admin password. Please try again.';
                            } finally {
                              isSaving.value = false;
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
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

  /// Start Firestore real-time synchronization safely without tearing down active streams

  Future<void> signInWithGoogle() async {
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
            final doc = await FirebaseFirestore.instance.collection('admin_members').doc(email).get();
            if (doc.exists && (doc.data()?['status'] ?? 'active') != 'suspended') {
              isAuthorized = true;
              memberRole = doc.data()?['role']?.toString() ?? 'Content Moderator';
              final rawRoles = doc.data()?['roles'];
              if (rawRoles is List && rawRoles.isNotEmpty) {
                rolesList = rawRoles.map((e) => e.toString()).toList();
              } else {
                rolesList = memberRole.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              }
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.googleSignInMemberQuery');
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
            ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.googleSignInPersistSession');
          }

          // Update last login in Firestore asynchronously
          unawaited(
            FirebaseFirestore.instance
                .collection('admin_members')
                .doc(email)
                .set({
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError((e, s) => ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.googleSignInLastLogin')),
          );

          startSubscriptions();
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
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete Google Sign In. Please try again.',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Signs out of the administrative console
  Future<void> signOutAdmin() async {
    rxIsLoading.value = true;
    try {
      clearSelectedItems();

      try {
        final storage = GetStorage();
        storage.remove('truthworld_admin_session');
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.removeAdminSession');
      }

      isAdmin.value = false;
      currentAdminEmail.value = '';
      currentAdminRole.value = 'Super Admin';

      stopSubscriptions();
      await AuthService.to.signOut();
      Get.offAllNamed('/admin/login');
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminAuthTeamMixin.signOutAdmin');
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Executes manual video moderation action (Approve/Reject/Override)

}
