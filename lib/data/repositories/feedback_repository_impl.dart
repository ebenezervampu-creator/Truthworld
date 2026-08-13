import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/feedback_repository.dart';

class FeedbackRepositoryImpl extends BaseRepository implements FeedbackRepository {
  final FirebaseFirestore _firestore;

  FeedbackRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<void>> submitFeedback({
    required String userId,
    required String userEmail,
    required String feedbackType,
    required String feedbackText,
    required int rating,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
  }) async {
    return safeSave(
      _firestore.collection(FirestoreCollections.feedback).doc(),
      {
        'userId': userId,
        'userEmail': userEmail,
        'feedbackType': feedbackType,
        'feedbackText': feedbackText,
        'rating': rating,
        'appVersion': appVersion,
        'deviceInfo': deviceInfo,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getAllFeedback({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  }) async {
    return safeFetch(() async {
      Query query = _firestore
          .collection(FirestoreCollections.feedback)
          .orderBy('createdAt', descending: true);

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }
      if (type != null && type.isNotEmpty) {
        query = query.where('feedbackType', isEqualTo: type);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()! as Map<String, dynamic>}).toList();
    });
  }

  @override
  Future<Result<void>> updateFeedbackStatus(
    String feedbackId,
    String status, {
    String? adminNote,
  }) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.feedback).doc(feedbackId),
      {
        'status': status,
        'adminNote': ?adminNote,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
