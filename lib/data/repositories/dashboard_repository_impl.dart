import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl extends BaseRepository implements DashboardRepository {
  final FirebaseFirestore _firestore;
  
  DocumentSnapshot? _lastVideoDoc;
  DocumentSnapshot? _lastCommentDoc;

  DashboardRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getChannelVideos(
    String channelId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastVideoDoc = null;
      
      var query = _firestore.collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
          
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (page > 1 && _lastVideoDoc != null) {
        query = query.startAfterDocument(_lastVideoDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastVideoDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getChannelAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics).doc(channelId).get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getVideoComments(
    String videoId, {
    int page = 1,
    int limit = 20,
    String? filter,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastCommentDoc = null;
      
      var query = _firestore.collection(FirestoreCollections.videoComments(videoId))
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastCommentDoc != null) {
        query = query.startAfterDocument(_lastCommentDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCommentDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> replyToComment(
    String videoId,
    String commentId,
    String replyText, {
    required String channelId,
    required String channelName,
    required String channelImageUrl,
  }) async {
    return safeFetch(() async {
      final replyRef = _firestore.collection(FirestoreCollections.videoComments(videoId))
          .doc(commentId)
          .collection('replies')
          .doc();
          
      await replyRef.set({
        'text': replyText,
        'channelId': channelId,
        'channelName': channelName,
        'channelImageUrl': channelImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<Result<Map<String, String>>> getVideoSubtitles(String videoId) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('subtitles')
          .doc('metadata')
          .get();
          
      if (!doc.exists) return {};
      final data = doc.data()!;
      return data.map((key, value) => MapEntry(key, value.toString()));
    });
  }

  @override
  Future<Result<void>> saveVideoSubtitles(
    String videoId,
    Map<String, String> subtitles,
  ) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('subtitles')
          .doc('metadata'),
      subtitles,
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getVideoChapters(String videoId) async {
    return safeFetch(() async {
      final snapshot = await _firestore.collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('chapters')
          .orderBy('startTime')
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> saveVideoChapters(
    String videoId,
    List<Map<String, dynamic>> chapters,
  ) async {
    return safeTransaction((tx) async {
      final chaptersRef = _firestore.collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('chapters');
          
      final existing = await chaptersRef.get();
      for (final doc in existing.docs) {
        tx.delete(doc.reference);
      }
      
      for (final chapter in chapters) {
        tx.set(chaptersRef.doc(), chapter);
      }
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getAudioTracks(String videoId) async {
    return safeFetch(() async {
      final snapshot = await _firestore.collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('audio_tracks')
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> trashVideo(String videoId) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.videos).doc(videoId),
      {'status': 'trashed', 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Future<Result<void>> restoreVideo(String videoId) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.videos).doc(videoId),
      {'status': 'draft', 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Future<Result<void>> permanentlyDeleteVideo(String videoId) async {
    return safeFetch(() async {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('permanentlyDeleteVideo');
        await callable.call({'videoId': videoId});
      } catch (fnErr) {
        ErrorHandler.log(fnErr, tag: 'DashboardRepo.permanentlyDeleteVideo');
        final subcollections = [
          'comments',
          'media',
          'subtitles',
          'chapters',
          'audio_tracks',
          'transcripts',
          'shards',
          'comment_shards',
          'views',
          'likes',
          'dislikes',
        ];
        for (final sub in subcollections) {
          try {
            final snap = await _firestore
                .collection(FirestoreCollections.videos)
                .doc(videoId)
                .collection(sub)
                .get();
            for (final doc in snap.docs) {
              if (sub == 'comments') {
                try {
                  final repliesSnap = await doc.reference.collection('replies').get();
                  for (final r in repliesSnap.docs) {
                    await r.reference.delete().catchError((_) {});
                  }
                } catch (_) {}
              }
              await doc.reference.delete().catchError((_) {});
            }
          } catch (_) {}
        }
        await _firestore.collection(FirestoreCollections.videos).doc(videoId).update({
          'status': 'deleted',
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'visibility': 'private',
        }).catchError((_) {});
        await _firestore.collection(FirestoreCollections.videos).doc(videoId).delete().catchError((_) {});
      }
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getAudienceDemographics(
    String channelId,
  ) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics)
          .doc(channelId)
          .collection('demographics')
          .doc('latest')
          .get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }
}
