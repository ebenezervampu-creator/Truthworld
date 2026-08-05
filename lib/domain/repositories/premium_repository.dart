import 'package:truthworld/core/network/result.dart';

/// Repository interface for premium/subscription tier operations.
abstract class PremiumRepository {
  /// Fetch available premium plans.
  Future<Result<List<Map<String, dynamic>>>> getPremiumPlans();

  /// Fetch current user's subscription status.
  Future<Result<Map<String, dynamic>>> getSubscriptionStatus(String userId);

  /// Create a new subscription.
  Future<Result<void>> createSubscription(
    String userId,
    String planId, {
    required Map<String, dynamic> paymentData,
  });

  /// Cancel a subscription.
  Future<Result<void>> cancelSubscription(String userId);

  /// Verify a payment receipt.
  Future<Result<bool>> verifyPayment(String receiptId);

  /// Fetch premium feature access list for a user.
  Future<Result<List<String>>> getPremiumFeatures(String userId);
}
