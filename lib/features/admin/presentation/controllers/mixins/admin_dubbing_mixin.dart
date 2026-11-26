import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dubbing/data/dubbing_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';

/// Mixin for managing user dubbing accounts, granting free credits,
/// and configuring special dubbing discounts or 100% free waivers.
mixin AdminDubbingMixin on GetxController {
  final DubbingService _dubbingService = DubbingService();

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE: Dubbing User Accounts & Wallet Ledger
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> allDubbingUsers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredDubbingUsers = <Map<String, dynamic>>[].obs;

  final Rxn<Map<String, dynamic>> selectedDubbingUser = Rxn<Map<String, dynamic>>();
  final Rxn<DubbingWallet> selectedDubbingWallet = Rxn<DubbingWallet>();
  final RxList<Map<String, dynamic>> selectedUserRecentJobs = <Map<String, dynamic>>[].obs;

  final RxBool isFetchingDubbingUsers = false.obs;
  final RxBool isLoadingDubbingDetails = false.obs;
  final RxBool isSavingDubbingAction = false.obs;

  final RxString dubbingSearchQuery = ''.obs;
  final RxString dubbingFilterOption = 'all'.obs; // 'all', 'with_discount', 'free_waiver', 'with_credits', 'zero_credits'

  final TextEditingController dubbingSearchController = TextEditingController();

  /// Loads registered user accounts and merges their live dubbing wallet stats.
  /// Uses authoritative Cloud Function first; falls back resiliently to multi-collection
  /// Firestore synthesis across users, channels, and dubbing_wallets.
  Future<void> fetchDubbingUsers({bool force = false}) async {
    if (isFetchingDubbingUsers.value && !force) return;
    isFetchingDubbingUsers.value = true;

    try {
      // 1. Authoritative Cloud Function path (Admin SDK context, immune to client Firestore Rules)
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('adminListDubbingAccounts');
        final res = await callable.call();
        final data = res.data;
        if (data is Map && data['success'] == true && data['accounts'] is List) {
          final accounts = List<Map<String, dynamic>>.from(
            (data['accounts'] as List).map((a) => Map<String, dynamic>.from(a as Map)),
          );
          if (accounts.isNotEmpty) {
            allDubbingUsers.assignAll(accounts);
            filterDubbingUsers();
            _autoSelectDubbingUser();
            return;
          }
        }
      } catch (cfErr, s) {
        ErrorHandler.log(cfErr, stackTrace: s, tag: 'AdminDubbingMixin.fetchDubbingUsers.callable');
      }

      // 2. Resilient Multi-Collection Fallback (synthesizes channels, wallets, and users)
      final db = FirebaseFirestore.instance;
      final accountMap = <String, Map<String, dynamic>>{};

      // A. Pull channels (Channels are always readable public collections)
      try {
        final channelsSnap = await db.collection(FirestoreCollections.channels).limit(100).get();
        for (final doc in channelsSnap.docs) {
          final cData = doc.data();
          final uid = (cData['ownerId'] ?? cData['userId'] ?? doc.id).toString();
          if (uid.isNotEmpty) {
            final channelName = (cData['name'] ?? cData['channelName'] ?? 'Creator Channel').toString();
            final dubPct = (cData['dubbingDiscountPercent'] as num?)?.toDouble() ?? 0.0;
            final dubType = (cData['dubbingDiscountType'] ?? 'none').toString();
            final isFree = cData['isDubbingFree'] == true || dubType == 'free' || dubPct >= 100.0;
            final freeCredits = (cData['freeDubbingCredits'] as num?)?.toInt() ?? 0;

            accountMap[uid] = {
              'id': uid,
              'uid': uid,
              'displayName': channelName,
              'email': (cData['email'] ?? '').toString(),
              'photoURL': (cData['avatarUrl'] ?? '').toString(),
              'createdAt': cData['createdAt'],
              'accountStatus': (cData['status'] ?? 'ACTIVE').toString(),
              'balanceCredits': freeCredits,
              'balanceUsd': 0.0,
              'totalCharactersUsed': 0,
              'specialDiscountPercent': dubPct,
              'specialDiscountType': dubType,
              'isDubbingFree': isFree,
              'discountReason': (cData['quotaIncreaseReason'] ?? 'Channel VIP Plan').toString(),
              'channelId': doc.id,
              'channelName': channelName,
              'channelHandle': cData['handle'],
              'customDailyVideoDurationSeconds': cData['customDailyVideoDurationSeconds'],
              'freeDubbingCredits': freeCredits,
            };
          }
        }
      } catch (chErr, s) {
        ErrorHandler.log(chErr, stackTrace: s, tag: 'AdminDubbingMixin.fetchDubbingUsers.channels');
      }

      // B. Fetch existing dubbing wallets and merge live balances & discount tags
      final walletMap = <String, Map<String, dynamic>>{};
      try {
        final walletsSnap = await db.collection('dubbing_wallets').limit(150).get();
        for (final doc in walletsSnap.docs) {
          final wData = doc.data();
          walletMap[doc.id] = wData;
          final uid = doc.id;
          final balanceCredits = (wData['balanceCredits'] as num?)?.toInt() ?? 0;
          final balanceUsd = (wData['balanceUsd'] as num?)?.toDouble() ?? 0.0;
          final totalUsed = (wData['totalCharactersUsed'] as num?)?.toInt() ?? 0;
          final discountPercent = (wData['specialDiscountPercent'] as num?)?.toDouble() ?? 0.0;
          final discountType = (wData['specialDiscountType'] ?? 'none').toString();
          final isFree = wData['isDubbingFree'] == true || discountType == 'free' || discountPercent >= 100.0;

          if (accountMap.containsKey(uid)) {
            final existing = accountMap[uid]!;
            existing['balanceCredits'] = balanceCredits;
            existing['balanceUsd'] = balanceUsd;
            existing['totalCharactersUsed'] = totalUsed;
            if (discountPercent > 0 || isFree) {
              existing['specialDiscountPercent'] = discountPercent;
              existing['specialDiscountType'] = discountType;
              existing['isDubbingFree'] = isFree;
            }
          } else {
            accountMap[uid] = {
              'id': uid,
              'uid': uid,
              'displayName': 'User ${uid.length > 6 ? uid.substring(0, 6) : uid}',
              'email': '',
              'photoURL': '',
              'createdAt': wData['createdAt'],
              'accountStatus': 'ACTIVE',
              'balanceCredits': balanceCredits,
              'balanceUsd': balanceUsd,
              'totalCharactersUsed': totalUsed,
              'specialDiscountPercent': discountPercent,
              'specialDiscountType': discountType,
              'isDubbingFree': isFree,
              'discountReason': (wData['discountReason'] ?? '').toString(),
            };
          }
        }
      } catch (wErr, s) {
        ErrorHandler.log(wErr, stackTrace: s, tag: 'AdminDubbingMixin.fetchDubbingUsers.wallets');
      }

      // C. Fetch users collection (guarded so security-rule rejections don't erase channels/wallets)
      try {
        QuerySnapshot<Map<String, dynamic>> usersSnap;
        try {
          usersSnap = await db.collection('users').orderBy('createdAt', descending: true).limit(100).get();
        } catch (_) {
          usersSnap = await db.collection('users').limit(100).get();
        }

        for (final doc in usersSnap.docs) {
          final uData = doc.data();
          final uid = doc.id;
          final wData = walletMap[uid];

          final displayName = (uData['displayName'] ?? uData['name'] ?? uData['username'] ?? '').toString().trim();
          final email = (uData['email'] ?? '').toString().trim();
          final fallbackName = displayName.isNotEmpty
              ? displayName
              : (email.contains('@') ? email.split('@')[0] : 'User ${uid.length > 6 ? uid.substring(0, 6) : uid}');

          final balanceCredits = (wData?['balanceCredits'] as num?)?.toInt() ??
              (uData['dubbingBalanceCredits'] as num?)?.toInt() ??
              0;
          final balanceUsd = (wData?['balanceUsd'] as num?)?.toDouble() ?? 0.0;
          final totalUsed = (wData?['totalCharactersUsed'] as num?)?.toInt() ?? 0;

          final discountPercent = (wData?['specialDiscountPercent'] as num?)?.toDouble() ??
              (uData['dubbingDiscountPercent'] as num?)?.toDouble() ??
              0.0;
          final discountType = (wData?['specialDiscountType'] ?? uData['dubbingDiscountType'] ?? 'none').toString();
          final isFree = wData?['isDubbingFree'] == true ||
              uData['isDubbingFree'] == true ||
              discountType == 'free' ||
              discountPercent >= 100.0;

          if (accountMap.containsKey(uid)) {
            final existing = accountMap[uid]!;
            if (displayName.isNotEmpty) existing['displayName'] = displayName;
            if (email.isNotEmpty) existing['email'] = email;
            if (uData['photoURL'] != null && uData['photoURL'].toString().isNotEmpty) {
              existing['photoURL'] = uData['photoURL'];
            }
            existing['accountStatus'] = (uData['accountStatus'] ?? existing['accountStatus'] ?? 'ACTIVE').toString();
          } else {
            accountMap[uid] = {
              'id': uid,
              'uid': uid,
              'displayName': fallbackName,
              'email': email,
              'photoURL': (uData['photoURL'] ?? uData['avatarUrl'] ?? '').toString(),
              'createdAt': uData['createdAt'],
              'accountStatus': (uData['accountStatus'] ?? 'ACTIVE').toString(),
              'balanceCredits': balanceCredits,
              'balanceUsd': balanceUsd,
              'totalCharactersUsed': totalUsed,
              'specialDiscountPercent': discountPercent,
              'specialDiscountType': discountType,
              'isDubbingFree': isFree,
              'discountReason': (wData?['discountReason'] ?? uData['dubbingDiscountReason'] ?? '').toString(),
            };
          }
        }
      } catch (uErr, s) {
        ErrorHandler.log(uErr, stackTrace: s, tag: 'AdminDubbingMixin.fetchDubbingUsers.users');
      }

      final mappedUsers = accountMap.values.toList();

      // Sort prioritizing accounts with active discounts or active balances
      mappedUsers.sort((a, b) {
        if (a['isDubbingFree'] == true && b['isDubbingFree'] != true) return -1;
        if (b['isDubbingFree'] == true && a['isDubbingFree'] != true) return 1;
        final aDiscount = (a['specialDiscountPercent'] as num?)?.toDouble() ?? 0;
        final bDiscount = (b['specialDiscountPercent'] as num?)?.toDouble() ?? 0;
        if (aDiscount != bDiscount) return bDiscount.compareTo(aDiscount);
        final aCredits = (a['balanceCredits'] as num?)?.toInt() ?? 0;
        final bCredits = (b['balanceCredits'] as num?)?.toInt() ?? 0;
        return bCredits.compareTo(aCredits);
      });

      allDubbingUsers.assignAll(mappedUsers);
      filterDubbingUsers();
      _autoSelectDubbingUser();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminDubbingMixin.fetchDubbingUsers');
    } finally {
      isFetchingDubbingUsers.value = false;
    }
  }

  void _autoSelectDubbingUser() {
    if (selectedDubbingUser.value == null && filteredDubbingUsers.isNotEmpty) {
      selectDubbingUser(filteredDubbingUsers.first);
    } else if (selectedDubbingUser.value != null) {
      final currentId = selectedDubbingUser.value!['id'];
      final updated = allDubbingUsers.firstWhereOrNull((u) => u['id'] == currentId);
      if (updated != null) {
        selectedDubbingUser.value = updated;
      }
    }
  }

  /// Filters user accounts according to search query and discount/credit options.
  void filterDubbingUsers() {
    var result = List<Map<String, dynamic>>.from(allDubbingUsers);

    // Apply Filter Option
    switch (dubbingFilterOption.value) {
      case 'with_discount':
        result = result.where((u) => (u['isDubbingFree'] == true) || ((u['specialDiscountPercent'] as num?)?.toDouble() ?? 0) > 0).toList();
        break;
      case 'free_waiver':
        result = result.where((u) => u['isDubbingFree'] == true).toList();
        break;
      case 'with_credits':
        result = result.where((u) => ((u['balanceCredits'] as num?)?.toInt() ?? 0) > 0).toList();
        break;
      case 'zero_credits':
        result = result.where((u) => ((u['balanceCredits'] as num?)?.toInt() ?? 0) == 0).toList();
        break;
      case 'channels':
        result = result.where((u) => u['channelId'] != null || u['channelName'] != null).toList();
        break;
      case 'all':
      default:
        break;
    }

    // Apply Search Query
    final query = dubbingSearchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((u) {
        final name = (u['displayName'] ?? '').toString().toLowerCase();
        final chName = (u['channelName'] ?? '').toString().toLowerCase();
        final chHandle = (u['channelHandle'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final id = (u['id'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            chName.contains(query) ||
            chHandle.contains(query) ||
            email.contains(query) ||
            id.contains(query);
      }).toList();
    }

    filteredDubbingUsers.assignAll(result);

    // If current selection is outside filtered list, select first match
    if (selectedDubbingUser.value != null) {
      final currentId = selectedDubbingUser.value!['id'];
      final match = filteredDubbingUsers.firstWhereOrNull((u) => u['id'] == currentId);
      if (match == null && filteredDubbingUsers.isNotEmpty) {
        selectDubbingUser(filteredDubbingUsers.first);
      }
    } else if (filteredDubbingUsers.isNotEmpty) {
      selectDubbingUser(filteredDubbingUsers.first);
    }
  }

  /// Sets the active search query for dubbing users.
  void searchDubbingUsers(String text) {
    dubbingSearchQuery.value = text;
    filterDubbingUsers();
  }

  /// Sets the active filter option ('all', 'with_discount', 'free_waiver', 'with_credits', 'zero_credits').
  void setDubbingFilterOption(String option) {
    dubbingFilterOption.value = option;
    filterDubbingUsers();
  }

  /// Selects a user account and loads their detailed wallet ledger and jobs.
  Future<void> selectDubbingUser(Map<String, dynamic> user) async {
    selectedDubbingUser.value = user;
    final userId = (user['id'] ?? user['uid'] ?? '').toString();
    if (userId.isEmpty) return;

    // Immediately seed reactive wallet state from user map
    selectedDubbingWallet.value = DubbingWallet(
      userId: userId,
      balanceCredits: (user['balanceCredits'] as num?)?.toInt() ?? 0,
      balanceUsd: (user['balanceUsd'] as num?)?.toDouble() ?? 0.0,
      specialDiscountPercent: (user['specialDiscountPercent'] as num?)?.toDouble() ?? 0.0,
      specialDiscountType: (user['specialDiscountType'] ?? 'none').toString(),
      isDubbingFree: user['isDubbingFree'] == true,
      discountReason: (user['discountReason'] ?? '').toString(),
    );

    isLoadingDubbingDetails.value = true;
    try {
      // 1. Direct fetch wallet from Firestore for real-time reactivity
      final walletDoc = await FirebaseFirestore.instance.collection('dubbing_wallets').doc(userId).get();
      if (walletDoc.exists && walletDoc.data() != null) {
        selectedDubbingWallet.value = DubbingWallet.fromMap(walletDoc.data()!);
      }

      // 2. Fetch recent dubbing jobs for this user
      final jobsSnap = await FirebaseFirestore.instance
          .collection('dubbing_jobs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get()
          .catchError((_) => null);

      if (jobsSnap != null) {
        final jobs = jobsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        selectedUserRecentJobs.assignAll(jobs);
      } else {
        selectedUserRecentJobs.clear();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminDubbingMixin.selectDubbingUser');
    } finally {
      isLoadingDubbingDetails.value = false;
    }
  }

  /// Grants free dubbing credits directly to a user account.
  Future<bool> grantFreeDubbingCredits({
    required String targetUserId,
    required int amountCredits,
    double amountUsd = 0.0,
    required String reason,
    String mode = 'add',
  }) async {
    if (isSavingDubbingAction.value) return false;
    isSavingDubbingAction.value = true;

    try {
      final res = await _dubbingService.adminGrantCredits(
        targetUserId: targetUserId,
        amountCredits: amountCredits,
        amountUsd: amountUsd,
        reason: reason,
        mode: mode,
      );

      if (res['success'] == true) {
        AppSnackbar.success(
          'Successfully granted ${amountCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} free credits.',
        );

        // Update local state in-place
        final newCredits = (res['balanceCredits'] as num?)?.toInt() ?? 0;
        final newUsd = (res['balanceUsd'] as num?)?.toDouble() ?? 0.0;

        _updateUserInList(targetUserId, {
          'balanceCredits': newCredits,
          'balanceUsd': newUsd,
        });

        if (selectedDubbingUser.value?['id'] == targetUserId) {
          await selectDubbingUser(selectedDubbingUser.value!);
        }

        return true;
      } else {
        AppSnackbar.warning(res['message']?.toString() ?? 'Unable to grant credits at this time.');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminDubbingMixin.grantFreeDubbingCredits');
      AppSnackbar.warning('Unable to grant credits. Please verify your connection.');
    } finally {
      isSavingDubbingAction.value = false;
    }
    return false;
  }

  /// Sets special dubbing discount or 100% free waiver for a user account.
  Future<bool> updateDubbingSpecialDiscount({
    required String targetUserId,
    required double discountPercent,
    required String discountType,
    required String reason,
    bool applyToChannels = true,
  }) async {
    if (isSavingDubbingAction.value) return false;
    isSavingDubbingAction.value = true;

    try {
      final res = await _dubbingService.adminSetDiscount(
        targetUserId: targetUserId,
        discountPercent: discountPercent,
        discountType: discountType,
        reason: reason,
        applyToChannels: applyToChannels,
      );

      if (res['success'] == true) {
        final isFree = res['isDubbingFree'] == true;
        final cleanPct = (res['discountPercent'] as num?)?.toDouble() ?? discountPercent;

        AppSnackbar.success(
          isFree
              ? '100% Free Dubbing Waiver activated for this user.'
              : cleanPct > 0
                  ? '${cleanPct.round()}% Special Dubbing Discount activated.'
                  : 'Dubbing discount reset to standard rate.',
        );

        _updateUserInList(targetUserId, {
          'specialDiscountPercent': cleanPct,
          'specialDiscountType': discountType,
          'isDubbingFree': isFree,
          'discountReason': reason,
        });

        if (selectedDubbingUser.value?['id'] == targetUserId) {
          await selectDubbingUser(selectedDubbingUser.value!);
        }

        return true;
      } else {
        AppSnackbar.warning(res['message']?.toString() ?? 'Unable to update discount.');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminDubbingMixin.updateDubbingSpecialDiscount');
      AppSnackbar.warning('Unable to update discount. Please verify connection.');
    } finally {
      isSavingDubbingAction.value = false;
    }
    return false;
  }

  void _updateUserInList(String userId, Map<String, dynamic> updates) {
    final idx = allDubbingUsers.indexWhere((u) => u['id'] == userId);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(allDubbingUsers[idx])..addAll(updates);
      allDubbingUsers[idx] = updated;
      filterDubbingUsers();
    }
  }
}
