import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/premium_repository.dart';

class PremiumRepositoryImpl extends BaseRepository implements PremiumRepository {
  final FirebaseFirestore _firestore;

  PremiumRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getPremiumPlans() async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection('premium_plans')
          .where('isActive', isEqualTo: true)
          .orderBy('price')
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getSubscriptionStatus(String userId) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.premiumSubscriptions)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return <String, dynamic>{'userId': userId, 'isPremium': false, 'tier': 'free'};
      }

      return {'id': doc.id, ...doc.data()!};
    });
  }

  @override
  Future<Result<void>> createSubscription(
    String userId,
    String planId, {
    required Map<String, dynamic> paymentData,
  }) async {
    return safeSave(
      _firestore.collection(FirestoreCollections.premiumSubscriptions).doc(userId),
      {
        'userId': userId,
        'planId': planId,
        'isPremium': true,
        'paymentData': paymentData,
        'subscribedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<Result<void>> cancelSubscription(String userId) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.premiumSubscriptions).doc(userId),
      {
        'isPremium': false,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<Result<bool>> verifyPayment(String receiptId) async {
    return safeFetch(() async {
      final doc = await _firestore.collection('payment_receipts').doc(receiptId).get();
      return doc.exists && (doc.data()?['status'] == 'verified');
    });
  }

  @override
  Future<Result<List<String>>> getPremiumFeatures(String userId) async {
    return safeFetch(() async {
      final statusResult = await getSubscriptionStatus(userId);
      final statusData = statusResult.when(
        success: (data) => data,
        failure: (_) => <String, dynamic>{'isPremium': false},
      );

      final isPremium = statusData['isPremium'] as bool? ?? false;
      if (!isPremium) {
        return <String>[];
      }

      final features = statusData['features'] as List<dynamic>?;
      if (features != null) {
        return features.map((e) => e.toString()).toList();
      }

      return <String>['ad_free', '4k_streaming', 'offline_downloads', 'creator_insights'];
    });
  }
}
