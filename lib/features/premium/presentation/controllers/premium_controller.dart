import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

class PremiumController extends BaseController {
  final RxString selectedPlanId = 'individual_monthly'.obs;
  final RxBool rxIsLoading = false.obs;
  RxBool get isSimulating => rxIsLoading;
  final RxBool isAutoPay = true.obs;

  void toggleAutoPay([bool? value]) {
    isAutoPay.value = value ?? !isAutoPay.value;
  }

  static const Map<String, double> planPricesUSD = {
    'audio_monthly': 0.50,
    'individual_monthly': 2.0,
    '4k_factchecked_monthly': 3.0,
    'family_monthly': 5.0,
    'individual_yearly': 18.0,
  };

  /// Fallback baseline prices in INR (1 USD = ₹84.0)
  static const Map<String, double> planPricesINR = {
    'audio_monthly': 42.0,
    'individual_monthly': 168.0,
    '4k_factchecked_monthly': 252.0,
    'family_monthly': 420.0,
    'individual_yearly': 1512.0,
  };

  static const Map<String, String> planTitles = {
    'audio_monthly': r'TruthWorld Audio Premium (Monthly - $0.50)',
    'individual_monthly': r'TruthWorld Premium (Monthly - $2)',
    '4k_factchecked_monthly': r'TruthWorld Premium + Fact-Checked (Monthly - $3)',
    'family_monthly': 'TruthWorld Family (Monthly)',
    'individual_yearly': 'TruthWorld Individual (Annual)',
  };

  @override
  void onInit() {
    super.onInit();
    _initDefaultSelectedPlan();
  }

  void _initDefaultSelectedPlan() {
    if (Get.isRegistered<AuthService>()) {
      final auth = AuthService.to;
      if (auth.isAudioPremiumOnly) {
        selectedPlanId.value = 'individual_monthly';
      } else if (auth.hasFullPremium && !auth.hasFactCheckPremium) {
        selectedPlanId.value = '4k_factchecked_monthly';
      }
    }
  }

  void selectPlan(String planId) {
    selectedPlanId.value = planId;
  }

  double getPriceForPlan(String planId) {
    final usdPrice = getPriceUSDForPlan(planId);
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;
    final inr = usdPrice * rate;
    return double.parse(inr.toStringAsFixed(2));
  }

  double getPriceUSDForPlan(String planId) {
    return planPricesUSD[planId] ?? 2.0;
  }

  /// Format an INR amount (e.g. ₹42 or ₹42.50)
  String formatAmountINR(double amount) {
    final isWhole = amount == amount.truncateToDouble();
    return '₹${isWhole ? amount.toInt() : amount.toStringAsFixed(2)}';
  }

  /// Format a USD amount (e.g. $2 or $0.50)
  String formatAmountUSD(double amount) {
    final isWhole = amount == amount.truncateToDouble();
    return '\$${isWhole ? amount.toInt() : amount.toStringAsFixed(2)}';
  }

  /// Checks if the target plan is an upgrade relative to user's currently active plan
  bool isUpgrade(String targetPlanId) {
    if (!Get.isRegistered<AuthService>()) return false;
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value || !auth.isPremiumUser.value) return false;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null || currentPlanId == targetPlanId) return false;

    final currentPrice = getPriceForPlan(currentPlanId);
    final targetPrice = getPriceForPlan(targetPlanId);
    return targetPrice > currentPrice;
  }

  /// Checks if the plan is currently active for the user
  bool isCurrentPlan(String planId) {
    if (!Get.isRegistered<AuthService>()) return false;
    final auth = AuthService.to;
    return auth.isAuthenticated.value &&
        auth.isPremiumUser.value &&
        auth.premiumPlanId.value == planId;
  }

  /// Checks if target plan is a lower tier than user's active plan
  bool isLowerTier(String targetPlanId) {
    if (!Get.isRegistered<AuthService>()) return false;
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value || !auth.isPremiumUser.value) return false;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null || currentPlanId == targetPlanId) return false;

    final currentPrice = getPriceForPlan(currentPlanId);
    final targetPrice = getPriceForPlan(targetPlanId);
    return targetPrice < currentPrice;
  }

  /// Calculates the effective payable price in INR based on live dollar exchange rate.
  /// If upgrading: target base price MINUS amount already paid for current active tier.
  double getEffectivePrice(String targetPlanId) {
    final basePrice = getPriceForPlan(targetPlanId);
    if (!isUpgrade(targetPlanId)) {
      return basePrice;
    }

    final auth = AuthService.to;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null) return basePrice;

    final currentPrice = getPriceForPlan(currentPlanId);
    final upgradeCost = basePrice - currentPrice;
    return upgradeCost > 0 ? double.parse(upgradeCost.toStringAsFixed(2)) : 0.0;
  }

  /// Calculates the effective payable price in USD for non-Indian viewers.
  double getEffectivePriceUSD(String targetPlanId) {
    final basePrice = getPriceUSDForPlan(targetPlanId);
    if (!isUpgrade(targetPlanId)) {
      return basePrice;
    }

    final auth = AuthService.to;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null) return basePrice;

    final currentPrice = getPriceUSDForPlan(currentPlanId);
    final upgradeCost = basePrice - currentPrice;
    return upgradeCost > 0 ? double.parse(upgradeCost.toStringAsFixed(2)) : 0.0;
  }

  /// Amount of credit deducted from existing subscription (INR)
  double getCreditApplied(String targetPlanId) {
    if (!isUpgrade(targetPlanId)) return 0.0;
    final auth = AuthService.to;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null) return 0.0;
    return getPriceForPlan(currentPlanId);
  }

  /// Amount of credit deducted from existing subscription (USD)
  double getCreditAppliedUSD(String targetPlanId) {
    if (!isUpgrade(targetPlanId)) return 0.0;
    final auth = AuthService.to;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null) return 0.0;
    return getPriceUSDForPlan(currentPlanId);
  }

  /// Formatted localized plan price string
  String getFormattedPrice(String planId) {
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    if (isIndian) {
      final price = getPriceForPlan(planId);
      return formatAmountINR(price);
    } else {
      final price = planPricesUSD[planId] ?? 2.0;
      return '\$${price.toStringAsFixed(price == 0.50 ? 2 : 0)}';
    }
  }

  /// Initiates authentic Cashfree payment for the chosen subscription tier or upgrade
  Future<void> purchasePlan(String planId) async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) {
      AppSnackbar.warning(
        'Please sign in to upgrade to TruthWorld Premium.',
        title: 'Sign In Required',
      );
      return;
    }

    if (isCurrentPlan(planId)) {
      AppSnackbar.info('You are already subscribed to this plan.');
      return;
    }

    try {
      rxIsLoading.value = true;

      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final isUpgrading = isUpgrade(planId);
      final effectivePrice = getEffectivePrice(planId);
      final amountINR = math.max(1.0, double.parse(effectivePrice.toStringAsFixed(2)));
      final creditINR = getCreditApplied(planId);
      final amountUSD = getEffectivePriceUSD(planId);
      final creditUSD = getCreditAppliedUSD(planId);
      final title = planTitles[planId] ?? 'TruthWorld Premium';

      final autoPaySuffix = isAutoPay.value ? ' (Auto Pay)' : ' (One-Time)';
      final formattedCreditINR = formatAmountINR(creditINR);
      final formattedCreditUSD = formatAmountUSD(creditUSD);
      final orderNote = isIndian
          ? (isUpgrading
              ? 'Upgrade to $title$autoPaySuffix ($formattedCreditINR credit applied)'
              : '$title$autoPaySuffix Subscription')
          : (isUpgrading
              ? 'Upgrade to $title$autoPaySuffix ($formattedCreditUSD USD credit applied)'
              : '$title$autoPaySuffix Subscription');

      final finalAmount = isIndian
          ? amountINR
          : math.max(0.50, double.parse(amountUSD.toStringAsFixed(2)));

      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: finalAmount,
        currency: isIndian ? 'INR' : 'USD',
        purpose: 'premium_subscription',
        orderNote: orderNote,
        metadata: {
          'planId': planId,
          'planTitle': title,
          'isUpgrade': isUpgrading,
          'previousPlanId': auth.premiumPlanId.value,
          'creditApplied': isIndian ? creditINR : creditUSD,
          'currency': isIndian ? 'INR' : 'USD',
          'autoPay': isAutoPay.value,
          'billingType': isAutoPay.value ? 'recurring' : 'one_time',
          if (!isIndian) 'amountUSD': amountUSD,
          if (!isIndian) 'creditUSD': creditUSD,
        },
      );

      if (paymentResult.success) {
        final now = DateTime.now();
        final startedAtMs = now.millisecondsSinceEpoch;
        final isYearly = planId.contains('yearly');
        final expiresAtMs = now
            .add(Duration(days: isYearly ? 365 : 30))
            .millisecondsSinceEpoch;

        // Synchronously update local auth state and persistent storage
        auth.isPremiumUser.value = true;
        auth.premiumPlanId.value = planId;
        auth.premiumStartedAt.value = startedAtMs;
        auth.premiumExpiresAt.value = expiresAtMs;

        final subId = paymentResult.details?['subscriptionId'] as String? ??
            (paymentResult.orderId.startsWith('sub_') ? paymentResult.orderId : null);

        final box = GetStorage();
        box.write('isPremiumUser', true);
        box.write('premiumPlanId', planId);
        box.write('premiumStartedAt', startedAtMs);
        box.write('premiumExpiresAt', expiresAtMs);
        box.write('isAutoPay', isAutoPay.value);
        if (subId != null) {
          box.write('cashfreeSubscriptionId', subId);
        }

        // Server-side fulfillOrder webhook authoritatively activates premium status in Firestore
        // upon verified payment gateway confirmation. Client-side Firestore writes to isPremium
        // are blocked by security rules to prevent self-elevation.
        await auth.forceRefreshToken();

        final autoPayNote = isAutoPay.value
            ? ' Auto Pay is active and will renew automatically.'
            : ' One-time payment valid for this billing cycle.';

        final successMessage = isIndian
            ? (isUpgrading
                ? 'Your plan has been upgraded to $title. $formattedCreditINR credit was applied!$autoPayNote'
                : 'Your $title is now active. Enjoy ad-free 4K streaming and AI fact-checking!$autoPayNote')
            : (isUpgrading
                ? 'Your plan has been upgraded to $title. $formattedCreditUSD USD credit was applied!$autoPayNote'
                : 'Your $title is now active. Enjoy ad-free 4K streaming and AI fact-checking!$autoPayNote');

        AppSnackbar.success(
          successMessage,
          title: isUpgrading ? 'Plan Upgraded' : 'Subscription Activated',
        );
      } else if (paymentResult.errorMessage != null &&
          !paymentResult.errorMessage!.toLowerCase().contains('cancel')) {
        AppSnackbar.error(paymentResult.errorMessage!);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'PremiumController.purchasePlan');
      AppSnackbar.error('Unable to complete subscription. Please try again.');
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Activates Premium subscription directly by updating Firestore and local auth state
  Future<void> activateSubscription(String planId) => purchasePlan(planId);

  /// Backwards-compatible alias for plan upgrade
  Future<void> upgradeSimulated(String planId) => purchasePlan(planId);

  /// Cancels Premium subscription immediately via cancellation
  Future<void> cancelSimulated() async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) return;

    try {
      rxIsLoading.value = true;
      await auth.cancelPremiumSubscription();
      AppSnackbar.info(
        'Your Premium subscription has been deactivated.',
        title: 'Subscription Cancelled',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'PremiumController.cancelSimulated');
      AppSnackbar.error('Unable to cancel subscription. Please try again.');
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Cancels active Cashfree Auto Pay mandate anytime while preserving service until cycle ends
  Future<bool> cancelAutoPay() async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) return false;
    final uid = auth.user?.uid;
    if (uid == null) return false;

    rxIsLoading.value = true;
    try {
      final box = GetStorage();
      var subId = box.read<String>('cashfreeSubscriptionId');

      if (subId == null || subId.isEmpty) {
        final subDoc = await FirebaseFirestore.instance
            .collection('payment_subscriptions')
            .where('userId', isEqualTo: uid)
            .where('purpose', isEqualTo: 'premium_subscription')
            .where('status', isEqualTo: 'ACTIVE')
            .limit(1)
            .get();
        if (subDoc.docs.isNotEmpty) {
          subId = subDoc.docs.first.id;
        }
      }

      if (subId != null && subId.isNotEmpty) {
        final cancelled = await CashfreePaymentService.to.cancelSubscriptionOnServer(subId);
        if (!cancelled) {
          AppSnackbar.warning('Unable to cancel Auto Pay mandate with the gateway. Please try again.');
          return false;
        }
      }

      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .update({
          'isAutoPay': false,
          'autoPay': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (err, s) {
        ErrorHandler.log(err, stackTrace: s, tag: 'PremiumController.cancelAutoPay.updateUser');
      }

      box.write('isAutoPay', false);
      box.remove('cashfreeSubscriptionId');
      isAutoPay.value = false;

      AppSnackbar.success(
        'Auto Pay has been turned off. Your subscription benefits remain active until the end of this billing cycle.',
        title: 'Auto Pay Cancelled',
      );
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'PremiumController.cancelAutoPay');
      AppSnackbar.error('Could not cancel Auto Pay. Please check your connection and try again.');
      return false;
    } finally {
      rxIsLoading.value = false;
    }
  }
}
