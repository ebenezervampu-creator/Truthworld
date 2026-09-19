import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Manages user subscription tiers, premium status, trial validity, and local caching.
class AuthPremiumManager {
  final RxBool isPremiumUser = false.obs;
  final RxnString premiumPlanId = RxnString();
  final RxnInt premiumStartedAt = RxnInt();
  final RxnInt premiumExpiresAt = RxnInt();

  /// Whether user's trial or subscription has expired.
  bool get isTrialExpired {
    final exp = premiumExpiresAt.value;
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch > exp;
  }

  /// Whether user is specifically subscribed to the Audio Premium tier (₹40/mo).
  bool get isAudioPremiumOnly =>
      isPremiumUser.value && premiumPlanId.value == 'audio_monthly';

  /// Whether user is subscribed to full TruthWorld Premium ($2/mo or higher).
  bool get hasFullPremium =>
      isPremiumUser.value && premiumPlanId.value != 'audio_monthly';

  /// Whether user has the $3 tier including on-demand & every video fact-checking.
  bool get hasFactCheckPremium =>
      isPremiumUser.value &&
      (premiumPlanId.value == '4k_factchecked_monthly' ||
          premiumPlanId.value == 'factcheck_monthly');

  /// Human-readable subscription start date.
  String get formattedStartedDate {
    final start = premiumStartedAt.value;
    if (start == null) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(start);
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  /// Human-readable subscription expiration date.
  String get formattedExpiresDate {
    final exp = premiumExpiresAt.value;
    if (exp == null) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(exp);
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  /// Formatted countdown of remaining trial or subscription duration.
  String get formattedRemainingTime {
    final exp = premiumExpiresAt.value;
    if (exp == null) return 'N/A';
    final diff = DateTime.fromMillisecondsSinceEpoch(exp).difference(
      DateTime.now(),
    );
    if (diff.isNegative) return 'Trial Expired';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (days > 0) {
      return '$days days, $hours hrs remaining';
    } else if (hours > 0) {
      return '$hours hrs, $mins mins remaining';
    } else {
      return '${diff.inMinutes} mins remaining';
    }
  }

  /// Loads locally cached Premium status synchronously so UI loads immediately without flickering.
  void loadCachedPremiumStatus() {
    try {
      final box = GetStorage();
      final savedIsPremium = box.read('isPremiumUser') as bool? ?? false;
      final savedPlanId = box.read('premiumPlanId') as String?;
      final savedStartedAt = box.read('premiumStartedAt') as int?;
      final savedExpiresAt = box.read('premiumExpiresAt') as int?;

      premiumStartedAt.value = savedStartedAt;
      premiumExpiresAt.value = savedExpiresAt;

      if (savedExpiresAt != null &&
          DateTime.now().millisecondsSinceEpoch > savedExpiresAt) {
        isPremiumUser.value = false;
        premiumPlanId.value = savedPlanId;
        box.write('isPremiumUser', false);
      } else {
        isPremiumUser.value = savedIsPremium;
        premiumPlanId.value = savedPlanId;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthPremiumManager.loadCachedPremiumStatus',
      );
    }
  }

  /// Checks if trial period has elapsed and updates state accordingly.
  void checkTrialExpiry() {
    final exp = premiumExpiresAt.value;
    if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
      if (isPremiumUser.value) {
        isPremiumUser.value = false;
        try {
          final box = GetStorage();
          box.write('isPremiumUser', false);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'AuthPremiumManager.checkTrialExpiry',
          );
        }
      }
    }
  }

  /// Synchronizes premium fields from Firestore user document snapshot.
  void updateFromUserData(
    Map<String, dynamic> data, {
    required Future<String?> Function() onTokenRefresh,
  }) {
    int? cachedStartedAt;
    int? cachedExpiresAt;
    var cachedIsPremium = false;
    String? cachedPlanId;

    try {
      final box = GetStorage();
      cachedStartedAt = box.read('premiumStartedAt') as int?;
      cachedExpiresAt = box.read('premiumExpiresAt') as int?;
      cachedIsPremium = box.read('isPremiumUser') as bool? ?? false;
      cachedPlanId = box.read('premiumPlanId') as String?;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthPremiumManager.updateFromUserData.readCache',
      );
    }

    final startAt =
        (data['premiumStartedAt'] as num?)?.toInt() ?? cachedStartedAt;
    final expAt = (data['premiumExpiresAt'] as num?)?.toInt() ?? cachedExpiresAt;

    premiumStartedAt.value = startAt;
    premiumExpiresAt.value = expAt;

    try {
      final box = GetStorage();
      if (startAt != null) box.write('premiumStartedAt', startAt);
      if (expAt != null) box.write('premiumExpiresAt', expAt);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthPremiumManager.updateFromUserData.writeDates',
      );
    }

    final isExpired =
        expAt != null && DateTime.now().millisecondsSinceEpoch > expAt;

    if (data.containsKey('isPremium')) {
      final isPrem = data['isPremium'] as bool? ?? false;
      final planId = data['premiumPlanId'] as String?;
      final oldIsPremium = isPremiumUser.value;

      if (isExpired) {
        isPremiumUser.value = false;
        premiumPlanId.value = planId ?? cachedPlanId;
        try {
          GetStorage().write('isPremiumUser', false);
        } catch (_) {}
      } else {
        isPremiumUser.value = isPrem;
        premiumPlanId.value = planId;
        try {
          GetStorage().write('isPremiumUser', isPrem);
        } catch (_) {}
      }

      if (oldIsPremium != isPremiumUser.value) {
        unawaited(onTokenRefresh());
      }

      try {
        final box = GetStorage();
        if (planId != null) {
          box.write('premiumPlanId', planId);
        } else {
          box.remove('premiumPlanId');
        }
      } catch (_) {}
    } else {
      if (isExpired) {
        isPremiumUser.value = false;
      } else {
        isPremiumUser.value = cachedIsPremium;
      }
      premiumPlanId.value = cachedPlanId;
    }
  }

  /// Resets state back to local cache when Firestore document is absent or user signed out.
  void resetToCached() {
    final box = GetStorage();
    final cachedIsPremium = box.read('isPremiumUser') as bool? ?? false;
    final cachedPlanId = box.read('premiumPlanId') as String?;
    final cachedStartedAt = box.read('premiumStartedAt') as int?;
    final cachedExpiresAt = box.read('premiumExpiresAt') as int?;

    premiumStartedAt.value = cachedStartedAt;
    premiumExpiresAt.value = cachedExpiresAt;

    if (cachedExpiresAt != null &&
        DateTime.now().millisecondsSinceEpoch > cachedExpiresAt) {
      isPremiumUser.value = false;
      premiumPlanId.value = cachedPlanId;
    } else {
      isPremiumUser.value = cachedIsPremium;
      premiumPlanId.value = cachedPlanId;
    }
  }

  /// Cancels active premium subscription and deletes Firestore premium metadata.
  Future<void> cancelPremiumSubscription(
    User? user, {
    required Future<String?> Function() onTokenRefresh,
  }) async {
    isPremiumUser.value = false;
    premiumPlanId.value = null;
    premiumStartedAt.value = null;
    premiumExpiresAt.value = null;

    final box = GetStorage();
    box.write('isPremiumUser', false);
    box.remove('premiumPlanId');
    box.remove('premiumStartedAt');
    box.remove('premiumExpiresAt');

    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .update({
            'isPremium': false,
            'premiumPlanId': FieldValue.delete(),
            'premiumStartedAt': FieldValue.delete(),
            'premiumExpiresAt': FieldValue.delete(),
          });
      // Force refresh claims on billing cancellation
      await onTokenRefresh();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthPremiumManager.cancelPremiumSubscription',
      );
    }
  }
}
