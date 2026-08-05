import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/admin_repository.dart';

class AdminRepositoryImpl extends BaseRepository implements AdminRepository {
  final FirebaseFirestore _firestore;
  
  DocumentSnapshot? _lastUserDoc;
  DocumentSnapshot? _lastReportDoc;
  DocumentSnapshot? _lastFeedbackDoc;

  AdminRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getUsers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastUserDoc = null;
      
      var query = _firestore.collection(FirestoreCollections.users).limit(limit);
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        query = query.where('searchName', isGreaterThanOrEqualTo: queryLower)
            .where('searchName', isLessThanOrEqualTo: '$queryLower\uf8ff');
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      if (page > 1 && _lastUserDoc != null) {
        query = query.startAfterDocument(_lastUserDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastUserDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getUserById(String userId) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.users).doc(userId).get();
      if (!doc.exists) throw Exception('User not found');
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    });
  }

  @override
  Future<Result<void>> banUser(String userId, {String? reason}) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.users).doc(userId),
      {'isBanned': true, 'banReason': reason, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Future<Result<void>> unbanUser(String userId) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.users).doc(userId),
      {'isBanned': false, 'banReason': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Future<Result<void>> deleteUser(String userId) async {
    return safeDelete(
      _firestore.collection(FirestoreCollections.users).doc(userId),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getReportedContent({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastReportDoc = null;

      var query = _firestore.collection(FirestoreCollections.reports).limit(limit).orderBy('createdAt', descending: true);

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (page > 1 && _lastReportDoc != null) {
        query = query.startAfterDocument(_lastReportDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastReportDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.reports).doc(reportId),
      {'status': 'resolved', 'action': action, 'resolutionNote': note, 'resolvedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> getPlatformAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics).doc('platform_summary').get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getFeedback({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastFeedbackDoc = null;

      var query = _firestore.collection(FirestoreCollections.feedback).limit(limit).orderBy('createdAt', descending: true);

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (page > 1 && _lastFeedbackDoc != null) {
        query = query.startAfterDocument(_lastFeedbackDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastFeedbackDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> updateFeedbackStatus(
    String feedbackId,
    String status,
  ) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.feedback).doc(feedbackId),
      {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }
}
