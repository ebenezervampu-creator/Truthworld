import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics/revenue_analytics_state_base.dart';

/// Mixin managing Firestore snapshot subscriptions for channel revenue, memberships, tiers, bank account, and KYC.
mixin RevenueAnalyticsStreamsMixin on RevenueAnalyticsStateBase {
  StreamSubscription? _channelSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _tiersSub;
  StreamSubscription? _statementsSub;
  StreamSubscription? _bankAccountSub;
  StreamSubscription? _kycSub;
  StreamSubscription? _premiumSubsSub;
  Worker? _rateWorker;

  double _directMembersRevenue = 0.0;
  double _tierMembersRevenue = 0.0;
  int _tierMembersCount = 0;

  /// Initializes exchange rate worker for live USD/INR conversions.
  void initExchangeRateWorker() {
    if (Get.isRegistered<CurrencyLocalizationService>()) {
      _rateWorker = ever(CurrencyLocalizationService.to.liveUsdToInrRate, (_) {
        recalculateWithLiveExchangeRate();
      });
    }
  }

  /// Cancels all active Firestore subscriptions and workers.
  void disposeStreams() {
    _rateWorker?.dispose();
    _channelSub?.cancel();
    _membersSub?.cancel();
    _tiersSub?.cancel();
    _statementsSub?.cancel();
    _bankAccountSub?.cancel();
    _kycSub?.cancel();
    _premiumSubsSub?.cancel();
  }

  /// Subscribes to authentic Firestore collections for revenue analytics.
  void subscribeToAuthenticData() {
    final chId = channelId.value;
    if (chId.isEmpty) return;

    rxIsLoading.value = true;

    // 1. Main Channel Document (superchats, ad revenue, views)
    _channelSub?.cancel();
    _channelSub = firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          if (channelName.value.isEmpty || channelName.value == 'Channel') {
            channelName.value =
                (data['name'] ?? data['channelName'] ?? 'Creator Channel')
                    .toString();
          }

          final superchats =
              (data['superchatRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          superchatRevenue.value = superchats;

          final ads = (data['adsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          adsRevenue.value = ads;

          final views = (data['viewCount'] as num?)?.toInt() ??
              (data['totalViews'] as num?)?.toInt() ??
              0;
          totalViews.value = views;

          final membershipTotal = ((data['membershipRevenueTotal'] ??
                  data['membershipsRevenueTotal']) as num?)
              ?.toDouble() ??
              0.0;
          if (membershipTotal > 0 && membershipsRevenue.value == 0) {
            membershipsRevenue.value = membershipTotal;
            membershipsRevenueINR.value = membershipTotal;
            membershipsRevenueUSD.value =
                membershipTotal / RevenueAnalyticsStateBase.usdToInrRate;
          }

          final kycStatus =
              (data['kycStatus'] as String? ?? '').toLowerCase().trim();
          if (kycStatus.isNotEmpty) {
            channelKycStatus.value = kycStatus;
          }

          // Evaluate Custom Channel Viral Surge Withdrawal Hold
          final isCustom = (data['channelType'] ?? '').toString().toLowerCase() == 'custom';
          if (isCustom) {
            final infra = data['infraConfig'] is Map
                ? Map<String, dynamic>.from(data['infraConfig'] as Map)
                : null;
            final isHeld = infra?['isWithdrawalHeld'] == true;
            final holdReason = (infra?['withdrawalHoldReason'] ?? '').toString();
            final usedBytes = (infra?['bandwidthUsedBytesThisMonth'] as num?)?.toInt() ?? 0;
            final quotaBytes = (infra?['bandwidthQuotaBytesThisMonth'] as num?)?.toInt() ?? 0;
            final isExceeded = quotaBytes > 0 && usedBytes > quotaBytes;

            isWithdrawalHeld.value = isHeld || isExceeded;
            withdrawalHoldReason.value = holdReason.isNotEmpty
                ? holdReason
                : (isWithdrawalHeld.value
                    ? 'TruthWorld has covered 100% of your viral infrastructure costs! Revenue withdrawals are on hold until your custom plan is upgraded.'
                    : '');
          } else {
            isWithdrawalHeld.value = false;
            withdrawalHoldReason.value = '';
          }

          final withdrawnTotal =
              (data['withdrawnRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          withdrawnRevenue.value = withdrawnTotal;

          final clearedTotal = (data['clearedWithdrawableRevenueTotal'] as num?)?.toDouble() ??
              (superchats + ads + membershipTotal + premiumSubsRevenue.value);
          clearedRevenue.value = clearedTotal;
          clearedRevenueUSD.value =
              clearedTotal / RevenueAnalyticsStateBase.usdToInrRate;

          final pendingTotal =
              (data['pendingRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          pendingRevenue.value = pendingTotal;
          pendingRevenueUSD.value =
              pendingTotal / RevenueAnalyticsStateBase.usdToInrRate;

          final autoPayout = (data['autoPayoutEnabled'] as bool?) ?? true;
          autoPayoutEnabled.value = autoPayout;

          recalculateTotal();
        }
        rxIsLoading.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._channelSub',
        );
        rxIsLoading.value = false;
      },
    );

    // 2. Authentic Members Stream (Active memberships fan funding)
    _membersSub?.cancel();
    _membersSub = firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('members')
        .snapshots()
        .listen(
      (snap) {
        final activeDocs = snap.docs.where((doc) {
          final data = doc.data();
          return (data['status'] ?? 'active').toString().toLowerCase() ==
              'active';
        }).toList();

        var sumINR = 0.0;
        var sumUSD = 0.0;
        var rawUsd = 0.0;
        var rawInr = 0.0;

        for (final doc in activeDocs) {
          final data = doc.data();
          final price = (data['price'] as num?)?.toDouble() ?? 0.0;
          final rawCurrency = (data['currency'] as String?)?.toUpperCase();
          final currency = rawCurrency ?? (price >= 50 ? 'INR' : 'USD');

          if (currency == 'USD') {
            rawUsd += price;
            sumUSD += price;
            sumINR += price * RevenueAnalyticsStateBase.usdToInrRate;
          } else {
            rawInr += price;
            sumINR += price;
            sumUSD += price / RevenueAnalyticsStateBase.usdToInrRate;
          }
        }

        _directMembersRevenue = sumINR;
        if (activeDocs.isNotEmpty) {
          activeMembersCount.value = activeDocs.length;
          originalUsdMemberships.value = rawUsd;
          originalInrMemberships.value = rawInr;
          membershipsRevenueINR.value = sumINR;
          membershipsRevenueUSD.value = sumUSD;
          membershipsRevenue.value = sumINR;
        } else if (_tierMembersRevenue > 0) {
          membershipsRevenueINR.value = _tierMembersRevenue;
          membershipsRevenueUSD.value = _tierMembersRevenue /
              RevenueAnalyticsStateBase.usdToInrRate;
          membershipsRevenue.value = _tierMembersRevenue;
          if (activeMembersCount.value == 0) {
            activeMembersCount.value = _tierMembersCount;
          }
        } else {
          activeMembersCount.value = 0;
          originalUsdMemberships.value = 0.0;
          originalInrMemberships.value = 0.0;
          // Preserve cumulative membership earnings loaded from channel document
          if (membershipsRevenue.value == 0.0) {
            membershipsRevenueINR.value = 0.0;
            membershipsRevenueUSD.value = 0.0;
          }
        }
        recalculateTotal();
        rxIsLoading.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._membersSub',
        );
        rxIsLoading.value = false;
      },
    );

    // 3. Membership Tiers Stream (Fallback member count and tier prices)
    _tiersSub?.cancel();
    _tiersSub = firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('membership_tiers')
        .snapshots()
        .listen(
      (snap) {
        var activeCount = 0;
        var tierIncomeINR = 0.0;
        var tierIncomeUSD = 0.0;
        var rawUsdTiers = 0.0;
        var rawInrTiers = 0.0;
        var memberSum = 0;

        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['isEnabled'] != false) {
            activeCount++;
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final count = (data['memberCount'] as num?)?.toInt() ?? 0;
            final rawCurrency = (data['currency'] as String?)?.toUpperCase();
            final currency = rawCurrency ?? (price >= 50 ? 'INR' : 'USD');

            if (currency == 'USD') {
              rawUsdTiers += price * count;
              tierIncomeUSD += price * count;
              tierIncomeINR += price *
                  RevenueAnalyticsStateBase.usdToInrRate *
                  count;
            } else {
              rawInrTiers += price * count;
              tierIncomeINR += price * count;
              tierIncomeUSD +=
                  (price / RevenueAnalyticsStateBase.usdToInrRate) * count;
            }
            memberSum += count;
          }
        }

        activeTiersCount.value = activeCount;
        _tierMembersRevenue = tierIncomeINR;
        _tierMembersCount = memberSum;

        if (_directMembersRevenue > 0) {
          // Direct members take precedence
        } else if (tierIncomeINR > 0.0) {
          originalUsdMemberships.value = rawUsdTiers;
          originalInrMemberships.value = rawInrTiers;
          membershipsRevenueINR.value = tierIncomeINR;
          membershipsRevenueUSD.value = tierIncomeUSD;
          membershipsRevenue.value = tierIncomeINR;
          if (activeMembersCount.value == 0) {
            activeMembersCount.value = memberSum;
          }
        }
        recalculateTotal();
        rxIsLoading.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._tiersSub',
        );
        rxIsLoading.value = false;
      },
    );

    // 4. Revenue Statements Stream
    _statementsSub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    var statementsQuery = firestore
        .collection('revenue_statements')
        .where('channelId', isEqualTo: chId);
    if (uid != null && uid.isNotEmpty) {
      statementsQuery = statementsQuery.where('userId', isEqualTo: uid);
    }
    _statementsSub = statementsQuery
        .limit(1)
        .snapshots()
        .listen(
      (snap) {
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final grossAds = (data['grossAdsRevenue'] as num?)?.toDouble() ?? 0.0;
          if (grossAds > 0 && adsRevenue.value == 0.0) {
            adsRevenue.value = grossAds;
          }
          final grossPremium =
              (data['grossPremiumSubsRevenue'] as num?)?.toDouble() ?? 0.0;
          if (grossPremium > 0 && premiumSubsRevenue.value == 0.0) {
            premiumSubsRevenue.value = grossPremium;
          }
          final creatorShare =
              (data['creatorShare'] as num?)?.toDouble() ?? 0.0;
          if (creatorShare > 0 && totalRevenue.value == 0.0) {
            totalRevenue.value = creatorShare;
            totalRevenueUSD.value =
                creatorShare / RevenueAnalyticsStateBase.usdToInrRate;
          }
          recalculateTotal();
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._statementsSub',
        );
      },
    );

    // 5. Creator Bank Account for Direct Payouts
    _bankAccountSub?.cancel();
    _bankAccountSub = firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('payout_settings')
        .doc('bank_account')
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          savedBankAccount.value = CreatorBankAccount.fromMap(doc.data()!);
        } else {
          loadUserFallbackBankAccount();
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._bankAccountSub',
        );
      },
    );

    // 6. Creator KYC Verification Stream
    _kycSub?.cancel();
    _kycSub = firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('kyc')
        .doc('verification')
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          final kyc = CreatorKycVerification.fromMap(
            doc.data()!,
            channelId: chId,
          );
          creatorKyc.value = kyc;
          channelKycStatus.value = kyc.status.toDbString();
        } else {
          checkRootKycFallback(chId);
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._kycSub',
        );
      },
    );

    // 7. Premium Subscription Revenue Stream
    // Listens to the channel's cumulative premiumSubsRevenueTotal field,
    // updated monthly by the distributePremiumRevenue Cloud Function.
    _premiumSubsSub?.cancel();
    _premiumSubsSub = firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          final premiumSubs =
              (data['premiumSubsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          if (premiumSubs != premiumSubsRevenue.value) {
            premiumSubsRevenue.value = premiumSubs;
            recalculateTotal();
          }
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(
          err,
          stackTrace: stack,
          tag: 'RevenueAnalyticsStreamsMixin._premiumSubsSub',
        );
      },
    );
  }

  /// Checks fallback KYC verification at root 'creator_kyc/{chId}'.
  Future<void> checkRootKycFallback(String chId) async {
    try {
      final rootDoc = await firestore.collection('creator_kyc').doc(chId).get();
      if (rootDoc.exists && rootDoc.data() != null) {
        final kyc = CreatorKycVerification.fromMap(
          rootDoc.data()!,
          channelId: chId,
        );
        creatorKyc.value = kyc;
        channelKycStatus.value = kyc.status.toDbString();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'RevenueAnalyticsStreamsMixin.checkRootKycFallback',
      );
    }
  }

  /// Checks fallback bank account at 'users/{uid}/payout_settings/bank_account'.
  Future<void> loadUserFallbackBankAccount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final userDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('payout_settings')
          .doc('bank_account')
          .get();
      if (userDoc.exists &&
          userDoc.data() != null &&
          savedBankAccount.value == null) {
        savedBankAccount.value = CreatorBankAccount.fromMap(userDoc.data()!);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'RevenueAnalyticsStreamsMixin.loadUserFallbackBankAccount',
      );
    }
  }

  /// Refreshes all revenue streams and data connections.
  Future<void> refreshData() async {
    subscribeToAuthenticData();
  }
}

