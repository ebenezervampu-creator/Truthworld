import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';

import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumController extends BaseController {
  final RxString selectedPlanId = 'individual_monthly'.obs;
  final RxBool rxIsLoading = false.obs;
  final RxBool isSimulating = false.obs;

  void selectPlan(String planId) {
    selectedPlanId.value = planId;
  }

  /// Initiates Stripe payment checkout session for the selected plan
  Future<void> purchasePlan(String planId) async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) {
      AppSnackbar.show(
        'Sign In Required',
        'Please sign in to upgrade to Premium.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      rxIsLoading.value = true;

      // Get origin URL for redirection after payment
      var clientOrigin = 'https://truthworld.in';
      if (kIsWeb) {
        clientOrigin = Uri.base.origin;
      }

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('createStripeCheckoutSession');

      final result = await callable.call({
        'planId': planId,
        'clientOrigin': clientOrigin,
      });

      final data = result.data as Map;
      final sessionUrl = data['sessionUrl'] as String?;

      if (sessionUrl != null && sessionUrl.isNotEmpty) {
        final uri = Uri.parse(sessionUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (kDebugMode) {
        await upgradeSimulated(planId);
      } else {
        AppSnackbar.show(
          'Checkout Error',
          'Unable to launch payment gateway. Please try again.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
      }
    } catch (_) {
      if (kDebugMode) {
        // Fallback to simulated sandbox upgrade only in debug/development
        await upgradeSimulated(planId);
      } else {
        AppSnackbar.show(
          'Payment Error',
          'Failed to initialize checkout session. Please try again.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
      }
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Instantly unlocks Premium locally by writing directly to Firestore (Simulated Sandbox)
  Future<void> upgradeSimulated(String planId) async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) {
      AppSnackbar.show(
        'Sign In Required',
        'Please sign in to simulate premium upgrade.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      isSimulating.value = true;

      final now = DateTime.now();
      final startedAtMs = now.millisecondsSinceEpoch;
      final expiresAtMs =
          now.add(const Duration(days: 7)).millisecondsSinceEpoch;

      if (kDebugMode && auth.uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(auth.uid)
            .update(
              {
                'premiumStartedAt': startedAtMs,
                'premiumExpiresAt': expiresAtMs,
              },
            )
            .catchError((_) {});
      }

      // Synchronously update active state and persist in local GetStorage
      auth.isPremiumUser.value = true;
      auth.premiumPlanId.value = planId;
      auth.premiumStartedAt.value = startedAtMs;
      auth.premiumExpiresAt.value = expiresAtMs;

      final box = GetStorage();
      box.write('isPremiumUser', true);
      box.write('premiumPlanId', planId);
      box.write('premiumStartedAt', startedAtMs);
      box.write('premiumExpiresAt', expiresAtMs);

      AppSnackbar.show(
        'Subscription Activated',
        'Successfully started your 7-day free trial! All Premium features unlocked.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Simulation Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
    } finally {
      isSimulating.value = false;
    }
  }

  /// Cancels Premium subscription immediately via mock cancellation
  Future<void> cancelSimulated() async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) return;

    try {
      isSimulating.value = true;
      await auth.cancelPremiumSubscription();
      AppSnackbar.show(
        'Subscription Cancelled',
        'Your Premium subscription has been deactivated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      AppSnackbar.show(
        'Cancellation Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
    } finally {
      isSimulating.value = false;
    }
  }
}
