import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';

/// GetX Service for Firestore database operations
class FirestoreService extends GetxService {
  late final FirebaseFirestore _firestore;

  // Observable states
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _firestore = FirebaseFirestore.instance;
  }

  /// Get a single document
  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final doc = await _firestore.collection(collection).doc(docId).get();
      return doc;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get all documents from a collection
  Future<QuerySnapshot> getCollection(String collection) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final docs = await _firestore.collection(collection).get();
      return docs;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get collection with query
  Future<QuerySnapshot> getCollectionWhere({
    required String collection,
    required String field,
    required dynamic isEqualTo,
  }) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final docs = await _firestore
          .collection(collection)
          .where(field, isEqualTo: isEqualTo)
          .get();
      return docs;
    } catch (e) {
      _handleError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Create or update a document
  Future<void> setDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      ToastService.loading('Saving...');

      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: merge));

      ToastService.dismissAll();
      ToastService.success('Saved successfully');
    } catch (e) {
      ToastService.dismissAll();
      _handleError(e);
      ToastService.error('Failed to save');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a document (auto-generated ID)
  Future<DocumentReference> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      ToastService.loading('Creating...');

      final docRef = await _firestore.collection(collection).add(data);

      ToastService.dismissAll();
      ToastService.success('Created successfully');
      return docRef;
    } catch (e) {
      ToastService.dismissAll();
      _handleError(e);
      ToastService.error('Failed to create');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a document
  Future<void> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      ToastService.loading('Updating...');

      await _firestore.collection(collection).doc(docId).update(data);

      ToastService.dismissAll();
      ToastService.success('Updated successfully');
    } catch (e) {
      ToastService.dismissAll();
      _handleError(e);
      ToastService.error('Failed to update');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String collection, String docId) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      DialogService.loading(message: 'Deleting...');

      await _firestore.collection(collection).doc(docId).delete();

      DialogService.close();
      ToastService.success('Deleted successfully');
    } catch (e) {
      DialogService.close();
      _handleError(e);
      SnackbarService.error(
        message: 'Failed to delete',
        actionLabel: 'Retry',
        onAction: () => deleteDocument(collection, docId),
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Stream a document
  Stream<DocumentSnapshot> streamDocument(String collection, String docId) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Stream a collection
  Stream<QuerySnapshot> streamCollection(String collection) {
    return _firestore.collection(collection).snapshots();
  }

  /// Stream collection with where query
  Stream<QuerySnapshot> streamCollectionWhere({
    required String collection,
    required String field,
    required dynamic isEqualTo,
  }) {
    return _firestore
        .collection(collection)
        .where(field, isEqualTo: isEqualTo)
        .snapshots();
  }

  /// Batch write operations
  Future<void> batchWrite(Function(WriteBatch) writes) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      ToastService.loading('Processing batch...');

      final batch = _firestore.batch();
      writes(batch);
      await batch.commit();

      ToastService.dismissAll();
      ToastService.success('Batch processed successfully');
    } catch (e) {
      ToastService.dismissAll();
      _handleError(e);
      ToastService.error('Batch processing failed');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore => _firestore;

  /// Handle errors
  void _handleError(dynamic error) {
    hasError.value = true;
    errorMessage.value = error.toString();
  }

  /// Clear error
  void clearError() {
    hasError.value = false;
    errorMessage.value = '';
  }
}





