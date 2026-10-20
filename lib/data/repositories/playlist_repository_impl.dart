import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/domain/entities/playlist_entity.dart';
import 'package:truthworld/domain/repositories/playlist_repository.dart';

class PlaylistRepositoryImpl extends BaseRepository
    implements PlaylistRepository {
  final FirebaseFirestore _firestore;

  DocumentSnapshot? _lastPlaylistDoc;

  PlaylistRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<PlaylistEntity>>> getPlaylists(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastPlaylistDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.playlists)
          .where('ownerId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastPlaylistDoc != null) {
        q = q.startAfterDocument(_lastPlaylistDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastPlaylistDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => PlaylistModel.fromDocumentSnapshot(doc).toEntity())
          .toList();
    });
  }

  @override
  Future<Result<PlaylistEntity>> getPlaylistById(String id) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.playlists)
          .doc(id)
          .get();
      if (!doc.exists) throw Exception('Playlist not found');
      return PlaylistModel.fromDocumentSnapshot(doc).toEntity();
    });
  }

  @override
  Future<Result<PlaylistEntity>> createPlaylist(PlaylistEntity playlist) async {
    return safeFetch(() async {
      final docRef = _firestore
          .collection(FirestoreCollections.playlists)
          .doc();
      final model = PlaylistModel.fromEntity(playlist);
      final data = model.toMap();
      data['id'] = docRef.id;

      await docRef.set(data);
      final doc = await docRef.get();
      return PlaylistModel.fromDocumentSnapshot(doc).toEntity();
    });
  }

  @override
  Future<Result<void>> deletePlaylist(String id) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.playlists).doc(id),
      {
        'status': 'deletion_pending',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<Result<void>> permanentlyDeletePlaylist(String id) async {
    return safeDelete(
      _firestore.collection(FirestoreCollections.playlists).doc(id),
    );
  }

  @override
  Future<Result<void>> addVideoToPlaylist(
    String playlistId,
    String videoId, {
    required String title,
    required String thumbnailUrl,
  }) async {
    return safeTransaction((tx) async {
      final playlistRef = _firestore
          .collection(FirestoreCollections.playlists)
          .doc(playlistId);
      final itemRef = _firestore
          .collection(FirestoreCollections.videoPlaylistItems(playlistId))
          .doc(videoId);

      final itemDoc = await tx.get(itemRef);
      if (!itemDoc.exists) {
        tx.set(itemRef, {
          'videoId': videoId,
          'title': title,
          'thumbnailUrl': thumbnailUrl,
          'addedAt': FieldValue.serverTimestamp(),
          'position': 0, // Naive position
        });

        tx.update(playlistRef, {
          'videoCount': FieldValue.increment(1),
          'videoIds': FieldValue.arrayUnion([videoId]),
          'updatedAt': FieldValue.serverTimestamp(),
          'thumbnailUrl': thumbnailUrl, // Update thumbnail to newest video
        });
      }
    });
  }

  @override
  Future<Result<void>> removeVideoFromPlaylist(
    String playlistId,
    String videoId,
  ) async {
    return safeTransaction((tx) async {
      final playlistRef = _firestore
          .collection(FirestoreCollections.playlists)
          .doc(playlistId);
      final itemRef = _firestore
          .collection(FirestoreCollections.videoPlaylistItems(playlistId))
          .doc(videoId);

      final itemDoc = await tx.get(itemRef);
      if (itemDoc.exists) {
        tx.delete(itemRef);
        tx.update(playlistRef, {
          'videoCount': FieldValue.increment(-1),
          'videoIds': FieldValue.arrayRemove([videoId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
