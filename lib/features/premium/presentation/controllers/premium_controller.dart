import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

class PremiumController extends GetxController {
  final RxString selectedPlanId = 'individual_monthly'.obs;
  final RxBool isLoading = false.obs;
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

    // Trial plans bypass payment and activate instantly!
    if (planId != 'individual_yearly') {
      await upgradeSimulated(planId);
      return;
    }

    try {
      isLoading.value = true;

      // Get origin URL for redirection after payment
      var clientOrigin = 'http://localhost:5000';
      if (kIsWeb) {
        clientOrigin = Uri.parse(html.window.location.href).origin;
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
        } else {
          throw Exception('Could not redirect to payment gateway.');
        }
      } else {
        throw Exception('Invalid payment session response received.');
      }
    } catch (e) {
      AppSnackbar.show(
        'Upgrade Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.textPrimary,
      );
    } finally {
      isLoading.value = false;
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

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(auth.uid)
          .update(
            {
              'isPremium': true,
              'monetizationTier': 'premium',
              'premiumPlanId': planId,
              'premiumUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            },
          );

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
