import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/library_repository.dart';

class LibraryRepositoryImpl extends BaseRepository implements LibraryRepository {
  final FirebaseFirestore _firestore;
  
  DocumentSnapshot? _lastLikedDoc;
  DocumentSnapshot? _lastHistoryDoc;
  DocumentSnapshot? _lastWatchLaterDoc;

  LibraryRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getLikedVideos(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastLikedDoc = null;
      
      var query = _firestore.collection('users').doc(userId).collection('liked_videos')
          .orderBy('likedAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastLikedDoc != null) {
        query = query.startAfterDocument(_lastLikedDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastLikedDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> toggleLikeVideo(String userId, String videoId) async {
    return safeFetch(() async {
      final docRef = _firestore.collection('users').doc(userId).collection('liked_videos').doc(videoId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
      } else {
        await docRef.set({'likedAt': FieldValue.serverTimestamp()});
      }
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getWatchHistory(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastHistoryDoc = null;
      
      var query = _firestore.collection('users').doc(userId).collection('watch_history')
          .orderBy('watchedAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastHistoryDoc != null) {
        query = query.startAfterDocument(_lastHistoryDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastHistoryDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> addToWatchHistory(
    String userId,
    String videoId, {
    int watchedSeconds = 0,
    int totalSeconds = 0,
  }) async {
    return safeFetch(() async {
      await _firestore.collection('users').doc(userId).collection('watch_history').doc(videoId).set({
        'watchedAt': FieldValue.serverTimestamp(),
        'watchedSeconds': watchedSeconds,
        'totalSeconds': totalSeconds,
      });
    });
  }

  @override
  Future<Result<void>> clearWatchHistory(String userId) async {
    return safeFetch(() async {
      final snapshot = await _firestore.collection('users').doc(userId).collection('watch_history').get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    });
  }

  @override
  Future<Result<void>> removeFromWatchHistory(String userId, String videoId) async {
    return safeDelete(
      _firestore.collection('users').doc(userId).collection('watch_history').doc(videoId)
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getWatchLater(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastWatchLaterDoc = null;
      
      var query = _firestore.collection('users').doc(userId).collection('watch_later')
          .orderBy('addedAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastWatchLaterDoc != null) {
        query = query.startAfterDocument(_lastWatchLaterDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastWatchLaterDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> toggleWatchLater(String userId, String videoId) async {
    return safeFetch(() async {
      final docRef = _firestore.collection('users').doc(userId).collection('watch_later').doc(videoId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
      } else {
        await docRef.set({'addedAt': FieldValue.serverTimestamp()});
      }
    });
  }

  DocumentSnapshot? _lastSavedDoc;

  @override
  Future<Result<List<Map<String, dynamic>>>> getSavedVideos(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastSavedDoc = null;

      var query = _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .orderBy('savedAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastSavedDoc != null) {
        query = query.startAfterDocument(_lastSavedDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSavedDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> toggleSaveVideo(
    String userId,
    Map<String, dynamic> videoMap,
  ) async {
    return safeFetch(() async {
      final videoId = (videoMap['id'] ?? '').toString();
      if (videoId.isEmpty) return;

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .doc(videoId);

      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
      } else {
        await docRef.set({
          'savedAt': FieldValue.serverTimestamp(),
          'videoId': videoId,
          'videoData': videoMap,
        });
      }
    });
  }
}
