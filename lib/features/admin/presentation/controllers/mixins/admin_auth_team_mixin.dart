import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/admin/presentation/controllers/auth/admin_auth_barrel.dart';

export 'package:truthworld/features/admin/presentation/controllers/auth/admin_auth_barrel.dart';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth & Team State
  // ═══════════════════════════════════════════════════════════════════════════
  final RxBool isAuthChecking = false.obs;
  final RxBool isAdmin = false.obs;
  final RxList<Map<String, dynamic>> adminMembers =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingMembers = false.obs;
  final RxString currentAdminEmail = ''.obs;
  final RxString currentAdminRole = 'Super Admin'.obs;
  final RxList<String> currentAdminRoles = <String>[].obs;
  StreamSubscription<QuerySnapshot>? _adminMembersSub;

  static const List<String> authorizedOwnerEmails = [
    String.fromEnvironment(
      'ADMIN_OWNER_EMAIL',
      defaultValue: 'hello@truthworld.in',
    ),
    'ebenezervampu4@gmail.com',
  ];

  // Two-step Admin Portal Login State
  final RxInt loginStep = 1.obs; // 1 = Username verification, 2 = Password input
  final Rxn<Map<String, dynamic>> verifiedAdminUser =
      Rxn<Map<String, dynamic>>();
  final TextEditingController usernameController = TextEditingController();
  final RxString loginUsername = ''.obs;
  final RxBool isVerifyingUsername = false.obs;

  // Email & Password login controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxString loginEmail = ''.obs;
  final RxString loginPassword = ''.obs;
  final RxBool needsPasswordSetup = false.obs;

  void resetLoginStep() {
    loginStep.value = 1;
    verifiedAdminUser.value = null;
    passwordController.clear();
    loginPassword.value = '';
  }

  Future<bool> verifyAdminUsername({String? usernameInput}) =>
      AdminAuthProtocolService.verifyAdminUsername(
        usernameInput: usernameInput,
        usernameController: usernameController,
        loginUsername: loginUsername,
        loginStep: loginStep,
        verifiedAdminUser: verifiedAdminUser,
        isVerifyingUsername: isVerifyingUsername,
        emailController: emailController,
        loginEmail: loginEmail,
      );

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

  void restoreAdminSession() => AdminAuthProtocolService.restoreAdminSession(
        isAdmin: isAdmin,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        currentAdminRoles: currentAdminRoles,
        onStartSubscriptions: startSubscriptions,
      );

  void listenToAdminMembers() {
    if (_adminMembersSub == null) {
      _adminMembersSub = AdminTeamService.listenToAdminMembers(
        adminMembers: adminMembers,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        currentAdminRoles: currentAdminRoles,
        isAdmin: isAdmin,
        authorizedOwnerEmails: authorizedOwnerEmails,
      );
      if (_adminMembersSub != null) trackSubscription(_adminMembersSub!);
    }
  }

  Future<void> ensureDefaultAdminSeeded() =>
      AdminTeamService.ensureDefaultAdminSeeded(
        authorizedOwnerEmails: authorizedOwnerEmails,
      );

  void navigateToDashboardIfOnLogin() =>
      AdminAuthProtocolService.navigateToDashboardIfOnLogin();

  Future<void> signInWithAdminProtocol({
    String? emailInput,
    String? passwordInput,
  }) =>
      AdminAuthProtocolService.signInWithAdminProtocol(
        emailInput: emailInput,
        passwordInput: passwordInput,
        emailController: emailController,
        passwordController: passwordController,
        loginEmail: loginEmail,
        loginPassword: loginPassword,
        rxIsLoading: rxIsLoading,
        isAdmin: isAdmin,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        currentAdminRoles: currentAdminRoles,
        authorizedOwnerEmails: authorizedOwnerEmails,
        onStartSubscriptions: startSubscriptions,
      );

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
  }) =>
      AdminPasswordService.changeAdminPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        currentAdminRoles: currentAdminRoles,
        authorizedOwnerEmails: authorizedOwnerEmails,
        rxIsLoading: rxIsLoading,
      );

  /// Adds a new team member with email, username, password, and assigned roles
  Future<bool> addTeamMember({
    required String email,
    required String password,
    String? username,
    String role = 'Content Moderator',
    List<String>? roles,
    String? name,
  }) =>
      AdminTeamService.addTeamMember(
        email: email,
        password: password,
        username: username,
        currentAdminEmail: currentAdminEmail.value,
        role: role,
        roles: roles,
        name: name,
      );

  /// Updates an existing team member's role, roles list, password, or status
  Future<bool> updateTeamMember({
    required String email,
    required Map<String, dynamic> updates,
    List<String>? roles,
  }) =>
      AdminTeamService.updateTeamMember(
        email: email,
        updates: updates,
        roles: roles,
      );

  /// Removes a team member's admin access
  Future<bool> deleteTeamMember(String email) =>
      AdminTeamService.deleteTeamMember(
        email: email,
        authorizedOwnerEmails: authorizedOwnerEmails,
      );

  /// Formats member credentials and copies to clipboard for sharing
  void copyMemberCredentials({
    required String email,
    required String password,
    String? username,
    String? role,
  }) =>
      AdminTeamService.copyMemberCredentials(
        email: email,
        password: password,
        username: username,
        role: role,
      );

  /// Directly verifies admin console claims and starts data streams
  Future<void> checkAdminClaims() =>
      AdminAuthProtocolService.checkAdminClaims(
        isAuthChecking: isAuthChecking,
        isAdmin: isAdmin,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        currentAdminRoles: currentAdminRoles,
        authorizedOwnerEmails: authorizedOwnerEmails,
        onStartSubscriptions: startSubscriptions,
      );

  /// Prompts a dialog to set the admin password for ebenezervampu4@gmail.com
  void showSetPasswordDialog() =>
      AdminPasswordService.showSetPasswordDialog(
        needsPasswordSetup: needsPasswordSetup,
        currentAdminEmail: currentAdminEmail,
      );

  Future<void> signInWithGoogle() =>
      AdminAuthProtocolService.signInWithGoogle(
        rxIsLoading: rxIsLoading,
        isAdmin: isAdmin,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        currentAdminRoles: currentAdminRoles,
        authorizedOwnerEmails: authorizedOwnerEmails,
        onStartSubscriptions: startSubscriptions,
      );

  /// Signs out of the administrative console
  Future<void> signOutAdmin() =>
      AdminAuthProtocolService.signOutAdmin(
        rxIsLoading: rxIsLoading,
        isAdmin: isAdmin,
        currentAdminEmail: currentAdminEmail,
        currentAdminRole: currentAdminRole,
        onClearSelectedItems: clearSelectedItems,
        onStopSubscriptions: stopSubscriptions,
      );
}
