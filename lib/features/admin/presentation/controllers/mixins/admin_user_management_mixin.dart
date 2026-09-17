import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Mixin managing administrative user moderation, safety profiles, search, and account consolidation.
mixin AdminUserManagementMixin on GetxController {
  /// Base controller contracts
  RxString get currentAdminEmail;
  RxBool get isAdmin;
  RxBool get isActionSubmitting;

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
  // FEATURE: User Management State
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> searchedUsers =
      <Map<String, dynamic>>[].obs;
  final RxString userSearchQuery = ''.obs;
  final RxString userFilterStatus = 'all'.obs;
  final Rxn<Map<String, dynamic>> selectedUser = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> userSafetyProfile =
      Rxn<Map<String, dynamic>>();
  final RxBool isSearchingUsers = false.obs;
  final RxBool isLoadingProfile = false.obs;
  final TextEditingController userSearchController = TextEditingController();
  Map<String, dynamic> mapUserDoc(String id, Map<String, dynamic>? rawData) {
    final data = rawData ?? {};
    final displayName = (data['displayName'] ?? data['name'] ?? data['username'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final fallbackName = displayName.isNotEmpty
        ? displayName
        : (email.contains('@') ? email.split('@')[0] : 'User ${id.length > 6 ? id.substring(0, 6) : id}');

    final isBanned = data['isBanned'] == true || data['role'] == 'banned' || data['accountStatus'] == 'BANNED';
    final isSuspended = data['accountStatus'] == 'SUSPENDED' ||
        (data['suspendedUntil'] != null &&
            data['suspendedUntil'] is num &&
            (data['suspendedUntil'] as num) > DateTime.now().millisecondsSinceEpoch);

    final status = isBanned ? 'banned' : (isSuspended ? 'suspended' : 'active');
    final trustScore = (data['trustScore'] is num)
        ? (data['trustScore'] as num).toInt()
        : ((data['score'] is num) ? (data['score'] as num).toInt() : 100);
    final strikes = (data['strikes'] is num)
        ? (data['strikes'] as num).toInt()
        : ((data['strikeCount'] is num) ? (data['strikeCount'] as num).toInt() : 0);

    return {
      'id': id,
      'uid': id,
      'name': fallbackName,
      'displayName': displayName,
      'email': email,
      'photoURL': data['photoURL'] ?? data['avatarUrl'] ?? '',
      'avatarUrl': data['photoURL'] ?? data['avatarUrl'] ?? '',
      'trustScore': trustScore,
      'status': status,
      'accountStatus': data['accountStatus'] ?? status.toUpperCase(),
      'strikes': strikes,
      'role': data['role'] ?? (data['isAdmin'] == true ? 'admin' : 'user'),
      'channelId': data['channelId'],
      'createdAt': data['createdAt'],
      'lastLoginAt': data['lastLoginAt'],
      'phoneNumber': data['phoneNumber'] ?? '',
      'banReason': data['banReason'],
      'suspendedUntil': data['suspendedUntil'],
      ...data,
    };
  }

  /// Sorts users by creation date and applies current filters
  Map<String, dynamic> _mapUserDoc(String id, Map<String, dynamic>? rawData) => mapUserDoc(id, rawData);
  void _sortAndSetUsers(List<Map<String, dynamic>> list) => sortAndSetUsers(list);

  void sortAndSetUsers(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final timeA = a['createdAt'] ?? a['lastLoginAt'];
      final timeB = b['createdAt'] ?? b['lastLoginAt'];
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      final dtA = timeA is Timestamp
          ? timeA.toDate()
          : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
      final dtB = timeB is Timestamp
          ? timeB.toDate()
          : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
      return dtB.compareTo(dtA);
    });

    allUsers.assignAll(list);
    _applyUserFilters();
  }

  /// Applies search query and status filter to `allUsers` and updates `searchedUsers`
  void _applyUserFilters() {
    var filtered = List<Map<String, dynamic>>.from(allUsers);
    final query = userSearchQuery.value.trim().toLowerCase();
    final statusFilter = userFilterStatus.value;

    if (statusFilter != 'all') {
      filtered = filtered.where((u) => u['status'] == statusFilter).toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((u) {
        final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final uid = (u['id'] ?? u['uid'] ?? '').toString().toLowerCase();
        final phone = (u['phoneNumber'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || uid.contains(query) || phone.contains(query);
      }).toList();
    }

    searchedUsers.assignAll(filtered);

    // Auto-select user if current selection is missing or not in list
    if (selectedUser.value == null && searchedUsers.isNotEmpty) {
      selectedUser.value = searchedUsers.first;
      getUserSafetyProfile(searchedUsers.first['id'] ?? '');
    } else if (selectedUser.value != null) {
      final currentId = selectedUser.value!['id'];
      final updated = searchedUsers.firstWhereOrNull((u) => u['id'] == currentId);
      if (updated != null) {
        selectedUser.value = updated;
      }
    }
  }

  /// Sets the user status filter ('all', 'active', 'banned', 'suspended')
  void setUserFilterStatus(String status) {
    userFilterStatus.value = status;
    _applyUserFilters();
  }

  /// Fetches users directly from Firestore and updates [searchedUsers]
  Future<void> fetchUsers({String? query, bool force = false}) async {
    if (query != null) {
      userSearchQuery.value = query;
    }
    isSearchingUsers.value = true;
    try {
      QuerySnapshot<Map<String, dynamic>> usersSnap;
      try {
        usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.fetchUsersOrdered');
        // Fallback without orderBy in case index or field is missing
        usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .limit(100)
            .get();
      }

      final list = usersSnap.docs.map((doc) => _mapUserDoc(doc.id, doc.data())).toList();
      _sortAndSetUsers(list);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.fetchUsers');
    } finally {
      isSearchingUsers.value = false;
    }
  }

  /// Searches users by email or display name
  Future<void> searchUsers(String queryText) async {
    userSearchQuery.value = queryText;
    if (allUsers.isNotEmpty) {
      _applyUserFilters();
      return;
    }
    await fetchUsers(query: queryText);
  }

  /// Loads the full safety profile for a user
  Future<void> getUserSafetyProfile(String userId) async {
    if (userId.isEmpty) return;
    isLoadingProfile.value = true;
    try {
      final db = FirebaseFirestore.instance;

      // 1. Fetch user doc
      final userDoc = await db.collection(FirestoreCollections.users).doc(userId).get();
      final userData = userDoc.exists
          ? _mapUserDoc(userId, userDoc.data() ?? {})
          : <String, dynamic>{'id': userId, 'uid': userId, 'name': 'User', 'email': ''};

      // 2. Fetch userTrust doc
      var trustData = <String, dynamic>{};
      try {
        final trustDoc = await db.collection('userTrust').doc(userId).get();
        if (trustDoc.exists && trustDoc.data() != null) {
          trustData = trustDoc.data()!;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.getUserSafetyProfileTrust');
      }

      // 3. Fetch user's channels
      var userChannels = <Map<String, dynamic>>[];
      try {
        final channelsSnap = await db
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: userId)
            .limit(10)
            .get();
        userChannels = channelsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (userChannels.isEmpty) {
          final fallbackChannelsSnap = await db
              .collection(FirestoreCollections.channels)
              .where('userId', isEqualTo: userId)
              .limit(10)
              .get();
          userChannels = fallbackChannelsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.getUserSafetyProfileChannels');
      }

      // 4. Fetch user's videos for upload statistics
      var totalUploads = 0;
      var approvedCount = 0;
      var rejectedCount = 0;
      try {
        final videosSnap = await db
            .collection(FirestoreCollections.videos)
            .where('ownerId', isEqualTo: userId)
            .limit(100)
            .get();
        totalUploads = videosSnap.docs.length;
        for (final v in videosSnap.docs) {
          final s = (v.data()['status'] ?? (v.data()['isApproved'] == true ? 'approved' : '')).toString().toLowerCase();
          if (s == 'approved' || v.data()['isApproved'] == true) approvedCount++;
          if (s == 'rejected') rejectedCount++;
        }
        if (totalUploads == 0) {
          final fallbackVideosSnap = await db
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: userId)
              .limit(100)
              .get();
          totalUploads = fallbackVideosSnap.docs.length;
          for (final v in fallbackVideosSnap.docs) {
            final s = (v.data()['status'] ?? (v.data()['isApproved'] == true ? 'approved' : '')).toString().toLowerCase();
            if (s == 'approved' || v.data()['isApproved'] == true) approvedCount++;
            if (s == 'rejected') rejectedCount++;
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.getUserSafetyProfileVideos');
      }

      // 5. Fetch user's reports/violations
      var violations = <Map<String, dynamic>>[];
      try {
        final repSnap = await db
            .collection(FirestoreCollections.reports)
            .where('reportedUserId', isEqualTo: userId)
            .limit(20)
            .get();
        violations = repSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.getUserSafetyProfileViolations');
      }

      // 6. Fetch moderation history
      var modHistory = <Map<String, dynamic>>[];
      try {
        final logsSnap = await db
            .collection('admin_actions_log')
            .where('userId', isEqualTo: userId)
            .limit(20)
            .get();
        modHistory = logsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.getUserSafetyProfileHistory');
      }

      final trustScore = (trustData['score'] is num)
          ? (trustData['score'] as num).toInt()
          : (userData['trustScore'] as int? ?? 100);
      final strikes = (trustData['strikes'] is num)
          ? (trustData['strikes'] as num).toInt()
          : (userData['strikes'] as int? ?? 0);
      final approvalRate = totalUploads > 0 ? ((approvedCount / totalUploads) * 100).round() : 100;
      final rejectionRate = totalUploads > 0 ? ((rejectedCount / totalUploads) * 100).round() : 0;

      userSafetyProfile.value = {
        'userId': userId,
        'user': userData,
        'trustScore': trustScore,
        'strikes': strikes,
        'status': userData['status'] ?? 'active',
        'accountStatus': userData['accountStatus'] ?? 'ACTIVE',
        'totalUploads': totalUploads,
        'approvalRate': approvalRate,
        'rejectionRate': rejectionRate,
        'channels': userChannels,
        'violations': violations,
        'appeals': [],
        'moderationHistory': modHistory,
      };
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.getUserSafetyProfile');
    } finally {
      isLoadingProfile.value = false;
    }
  }

  /// Executes a moderation action on a user account
  Future<bool> moderateUser(
    String userId,
    String action,
    String reason, {
    int? durationDays,
  }) async {
    isActionSubmitting.value = true;
    try {
      var currentUser = FirebaseAuth.instance.currentUser;

      // Ensure active Firebase Auth session; if missing, attempt silent re-authentication with cached credentials
      if (currentUser == null && currentAdminEmail.value.isNotEmpty) {
        try {
          final storage = GetStorage();
          final creds = storage.read<Map<String, dynamic>>('truthworld_admin_credentials');
          final targetEmail = currentAdminEmail.value.trim().toLowerCase();
          final cachedPass = creds?[targetEmail] ?? '12345';
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: targetEmail,
            password: cachedPass.toString(),
          );
          currentUser = cred.user;
        } catch (reAuthErr, s) {
          ErrorHandler.log(reAuthErr, stackTrace: s, tag: 'AdminUserManagementMixin.silentAdminReAuth');
        }
      }

      if (currentUser == null) {
        AppSnackbar.warning(
          'Your administrator security session has expired. Please sign in again.',
          title: 'Session Expired',
        );
        return false;
      }

      final adminId = currentUser.uid;
      final adminEmail = currentUser.email ?? currentAdminEmail.value;
      final db = FirebaseFirestore.instance;

      final normalizedAction = action.trim().toLowerCase();
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalizedAction == 'ban' || normalizedAction == 'ban user') {
        updates['isBanned'] = true;
        updates['role'] = 'banned';
        updates['accountStatus'] = 'BANNED';
        updates['status'] = 'banned';
        updates['banReason'] = reason;
        updates['bannedAt'] = FieldValue.serverTimestamp();
      } else if (normalizedAction == 'unban' || normalizedAction == 'unban user' || normalizedAction == 'reactivate' || normalizedAction == 'reactivate user') {
        updates['isBanned'] = false;
        updates['role'] = 'user';
        updates['accountStatus'] = 'ACTIVE';
        updates['status'] = 'active';
        updates['banReason'] = FieldValue.delete();
        updates['suspendedUntil'] = FieldValue.delete();
      } else if (normalizedAction.startsWith('suspend')) {
        final days = durationDays ?? 7;
        final until = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
        updates['isBanned'] = false;
        updates['accountStatus'] = 'SUSPENDED';
        updates['status'] = 'suspended';
        updates['suspendedUntil'] = until;
        updates['banReason'] = reason;
      } else if (normalizedAction == 'warn' || normalizedAction == 'warn user') {
        updates['strikes'] = FieldValue.increment(1);
        updates['lastWarningReason'] = reason;
        updates['lastWarningAt'] = FieldValue.serverTimestamp();
      } else if (normalizedAction == 'reset trust' || normalizedAction == 'reset_trust' || normalizedAction == 'reset') {
        updates['trustScore'] = 100;
        updates['strikes'] = 0;
        try {
          await db.collection('userTrust').doc(userId).set({
            'score': 100,
            'strikes': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.resetTrustScore');
        }
      } else if (normalizedAction == 'delete' || normalizedAction == 'delete user' || normalizedAction == 'delete account') {
        updates['isDeleted'] = true;
        updates['status'] = 'deleted';
        updates['accountStatus'] = 'DELETED';
      }

      // 1. Authoritative Backend Moderation via Cloud Function
      var backendSuccess = false;
      try {
        final token = await currentUser.getIdToken();
        final url = Uri.parse('${AppConfig.cloudFunctionsBaseUrl}/moderateUser');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'userId': userId,
            'action': normalizedAction,
            'reason': reason,
            'durationDays': ?durationDays,
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          backendSuccess = true;
        } else {
          ErrorHandler.log(
            'moderateUser Cloud Function responded: ${response.statusCode} - ${response.body}',
            tag: 'AdminUserManagementMixin.moderateUserCloudFunction',
          );
        }
      } catch (cfErr, s) {
        ErrorHandler.log(cfErr, stackTrace: s, tag: 'AdminUserManagementMixin.moderateUserCloudFunction');
      }

      // 2. Direct Firestore fallback if backend endpoint was unreachable
      if (!backendSuccess) {
        await db.collection(FirestoreCollections.users).doc(userId).set(updates, SetOptions(merge: true));

        try {
          await db.collection('admin_actions_log').add({
            'adminId': adminId,
            'adminEmail': adminEmail,
            'userId': userId,
            'action': normalizedAction,
            'reason': reason,
            'durationDays': durationDays,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.logAdminActionFallback');
        }
      }

      AppSnackbar.success(
        'User action "$action" processed successfully.',
        title: 'Action Applied',
      );

      // 3. Update in-memory user list
      final index = allUsers.indexWhere((u) => u['id'] == userId);
      if (index != -1) {
        final updatedUser = Map<String, dynamic>.from(allUsers[index]);
        if (normalizedAction.contains('ban')) {
          updatedUser['status'] = 'banned';
          updatedUser['isBanned'] = true;
          updatedUser['accountStatus'] = 'BANNED';
        } else if (normalizedAction.contains('unban') || normalizedAction.contains('reactivate')) {
          updatedUser['status'] = 'active';
          updatedUser['isBanned'] = false;
          updatedUser['accountStatus'] = 'ACTIVE';
        } else if (normalizedAction.startsWith('suspend')) {
          updatedUser['status'] = 'suspended';
          updatedUser['accountStatus'] = 'SUSPENDED';
        } else if (normalizedAction.contains('warn')) {
          updatedUser['strikes'] = (updatedUser['strikes'] as int? ?? 0) + 1;
        } else if (normalizedAction.contains('reset')) {
          updatedUser['trustScore'] = 100;
          updatedUser['strikes'] = 0;
        }
        allUsers[index] = updatedUser;
        _applyUserFilters();
      }

      await getUserSafetyProfile(userId);
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to perform this action. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Fetches Google Cloud Vision verification details for a user's avatar
  Future<Map<String, dynamic>?> fetchAvatarVerification(
    String userId, {
    String? avatarFileId,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      if (avatarFileId != null && avatarFileId.isNotEmpty) {
        final doc =
            await db.collection('image_verification').doc(avatarFileId).get();
        if (doc.exists && doc.data() != null) {
          return {'id': doc.id, ...doc.data()!};
        }
      }
      final snap = await db
          .collection('image_verification')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'avatar')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return {'id': snap.docs.first.id, ...snap.docs.first.data()};
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminUserManagementMixin.fetchAvatarVerification');
    }
    return null;
  }

  /// Authoritatively moderates a user's avatar (approve or reject)
  Future<bool> moderateUserAvatar({
    required String userId,
    required String action,
    String? avatarFileId,
    String? reason,
  }) async {
    isActionSubmitting.value = true;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminId = currentUser?.uid ?? 'admin';
      final adminEmail = currentUser?.email ?? currentAdminEmail.value;
      final db = FirebaseFirestore.instance;

      final normalizedAction = action.trim().toLowerCase();
      final isApprove = normalizedAction == 'approve';
      final newStatus = isApprove ? 'APPROVED' : 'REJECTED';
      final modReason = reason?.trim().isNotEmpty == true
          ? reason!.trim()
          : (isApprove
              ? 'Avatar approved by Administrator'
              : 'Avatar rejected due to community safety standards');

      final batch = db.batch();

      // 1. Update user doc
      final userRef = db.collection(FirestoreCollections.users).doc(userId);
      final userUpdates = <String, dynamic>{
        'avatarStatus': newStatus,
        'avatarStatusReason': modReason,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!isApprove) {
        userUpdates['photoURL'] = '';
        userUpdates['avatarUrl'] = '';
      }
      batch.set(userRef, userUpdates, SetOptions(merge: true));

      // 2. Update image_verification doc if exists or known
      if (avatarFileId != null && avatarFileId.isNotEmpty) {
        final verifRef = db.collection('image_verification').doc(avatarFileId);
        batch.set(
          verifRef,
          {
            'status': newStatus,
            'adminReason': modReason,
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedBy': adminId,
          },
          SetOptions(merge: true),
        );

        final flaggedRef =
            db.collection('flagged_images_review').doc(avatarFileId);
        batch.set(
          flaggedRef,
          {
            'status': newStatus.toLowerCase(),
            'adminReason': modReason,
            'reviewedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 3. Admin audit log
      final auditRef = db.collection('admin_actions_log').doc();
      batch.set(auditRef, {
        'adminId': adminId,
        'adminEmail': adminEmail,
        'userId': userId,
        'action': isApprove ? 'approve_avatar' : 'reject_avatar',
        'reason': modReason,
        'avatarFileId': avatarFileId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Update in-memory user list and selected user
      final index = allUsers.indexWhere((u) => u['id'] == userId);
      if (index != -1) {
        final updatedUser = Map<String, dynamic>.from(allUsers[index]);
        updatedUser['avatarStatus'] = newStatus;
        updatedUser['avatarStatusReason'] = modReason;
        if (!isApprove) {
          updatedUser['photoURL'] = '';
          updatedUser['avatarUrl'] = '';
        }
        allUsers[index] = updatedUser;
        _applyUserFilters();
      }

      if (selectedUser.value?['id'] == userId) {
        final currentSelected = Map<String, dynamic>.from(selectedUser.value!);
        currentSelected['avatarStatus'] = newStatus;
        currentSelected['avatarStatusReason'] = modReason;
        if (!isApprove) {
          currentSelected['photoURL'] = '';
          currentSelected['avatarUrl'] = '';
        }
        selectedUser.value = currentSelected;
      }

      await getUserSafetyProfile(userId);

      AppSnackbar.success(
        'Avatar has been marked as $newStatus.',
        title: 'Avatar Moderation Updated',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update avatar moderation. Please try again.',
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  final RxBool isConsolidatingAccounts = false.obs;

  /// Helper to record administrative actions into Firestore admin_actions_log
    /// Consolidates duplicate user accounts under the same email
  Future<bool> consolidateUserAccounts(String email, {String? primaryUid}) async {
    if (isConsolidatingAccounts.value) return false;
    isConsolidatingAccounts.value = true;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final token = currentUser != null ? await currentUser.getIdToken() : null;

      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/consolidateUserAccounts',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          if (primaryUid != null && primaryUid.isNotEmpty) 'primaryUid': primaryUid,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>?;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final mergedCount = data?['mergedCount'] ?? 0;
        final message = data?['message'] as String? ??
            'Successfully consolidated $mergedCount duplicate accounts.';
        AppSnackbar.success(
          message,
          title: 'Accounts Consolidated',
        );
        await searchUsers(userSearchQuery.value);
        return true;
      } else {
        final errorMsg = data?['error'] as String? ??
            'Unable to consolidate accounts. Please try again.';
        AppSnackbar.warning(
          errorMsg,
        );
        return false;
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to connect to account consolidation service. Please check your connection and try again.',
      );
      return false;
    } finally {
      isConsolidatingAccounts.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Analytics Methods
  // ═══════════════════════════════════════════════════════════════════════════


}
