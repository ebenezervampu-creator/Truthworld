import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

class PremiumController extends BaseController {
  final RxString selectedPlanId = 'individual_monthly'.obs;
  final RxBool rxIsLoading = false.obs;
  RxBool get isSimulating => rxIsLoading;

  static const Map<String, double> planPricesINR = {
    'audio_monthly': 40.0,
    'individual_monthly': 169.0,
    '4k_factchecked_monthly': 249.0,
    'family_monthly': 399.0,
    'individual_yearly': 1490.0,
  };

  static const Map<String, String> planTitles = {
    'audio_monthly': r'TruthWorld Audio Premium (Monthly - $0.50 / ₹40)',
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
    return planPricesINR[planId] ?? 169.0;
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

  /// Calculates the effective payable price.
  /// If upgrading: target base price MINUS amount already paid for current active tier.
  /// - Audio Premium (₹40) -> $2 Premium (₹169): 169 - 40 = ₹129 ($2 - 40 rupees)
  /// - Audio Premium (₹40) -> $3 Fact-Checked (₹249): 249 - 40 = ₹209 ($3 - 40 rupees)
  /// - $2 Premium (₹169) -> $3 Fact-Checked (₹249): 249 - 169 = ₹80 ($3 - $2)
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
    return upgradeCost > 0 ? upgradeCost : 0.0;
  }

  /// Amount of credit deducted from existing subscription
  double getCreditApplied(String targetPlanId) {
    if (!isUpgrade(targetPlanId)) return 0.0;
    final auth = AuthService.to;
    final currentPlanId = auth.premiumPlanId.value;
    if (currentPlanId == null) return 0.0;
    return getPriceForPlan(currentPlanId);
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

      final isUpgrading = isUpgrade(planId);
      final amount = getEffectivePrice(planId);
      final credit = getCreditApplied(planId);
      final title = planTitles[planId] ?? 'TruthWorld Premium';

      final orderNote = isUpgrading
          ? 'Upgrade to $title (₹${credit.toInt()} credit applied)'
          : '$title Subscription';

      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: amount,
        purpose: 'premium_subscription',
        orderNote: orderNote,
        metadata: {
          'planId': planId,
          'planTitle': title,
          'isUpgrade': isUpgrading,
          'previousPlanId': auth.premiumPlanId.value,
          'creditApplied': credit,
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

        final box = GetStorage();
        box.write('isPremiumUser', true);
        box.write('premiumPlanId', planId);
        box.write('premiumStartedAt', startedAtMs);
        box.write('premiumExpiresAt', expiresAtMs);

        // Authoritatively persist to Firestore users collection
        final u = auth.user;
        if (u != null) {
          try {
            await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(u.uid)
                .update({
                  'isPremium': true,
                  'premiumPlanId': planId,
                  'premiumStartedAt': startedAtMs,
                  'premiumExpiresAt': expiresAtMs,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
          } catch (fireErr, s) {
            ErrorHandler.log(fireErr, stackTrace: s, tag: 'PremiumController.updateUserDoc');
          }
        }

        final successMessage = isUpgrading
            ? 'Your plan has been upgraded to $title. ₹${credit.toInt()} credit was applied!'
            : 'Your $title is now active. Enjoy ad-free 4K streaming and AI fact-checking!';

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
}
