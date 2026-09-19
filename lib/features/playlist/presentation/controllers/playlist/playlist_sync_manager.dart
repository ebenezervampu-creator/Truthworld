import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';

/// Manager coordinating realtime streams and snapshot listeners for channels, private, and public playlists.
class PlaylistSyncManager {
  PlaylistSyncManager({
    required this.getUserId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String Function() getUserId;

  final RxList<Channel> channels = <Channel>[].obs;
  final RxList<PlaylistModel> playlists = <PlaylistModel>[].obs;
  final RxList<PlaylistModel> publicPlaylists = <PlaylistModel>[].obs;
  final Rx<Channel?> selectedChannel = Rx<Channel?>(null);

  final RxBool isPlaylistsLoaded = false.obs;
  final RxBool isPublicPlaylistsLoaded = false.obs;

  StreamSubscription<QuerySnapshot>? _channelsSubscription;
  StreamSubscription<QuerySnapshot>? _playlistsSubscription;
  StreamSubscription<QuerySnapshot>? _publicPlaylistsSubscription;

  void fetchChannels() {
    _channelsSubscription?.cancel();
    final user = getUserId();
    if (user.isEmpty) {
      logger.debug('⚠️ fetchChannels: No user logged in, skipping listener');
      return;
    }

    _channelsSubscription = _firestore
        .collection(FirestoreCollections.channels)
        .where('ownerId', isEqualTo: user)
        .snapshots()
        .listen(
          (snapshot) async {
            var loaded = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();

            if (loaded.isEmpty) {
              try {
                final userSnap = await _firestore
                    .collection(FirestoreCollections.channels)
                    .where('userId', isEqualTo: user)
                    .get();
                loaded = userSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((c) => c.status != ChannelStatus.deleted)
                    .toList();
              } catch (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'PlaylistSyncManager.fetchChannels.fallback',
                );
              }
            }

            if (loaded.isEmpty && AuthService.to.userChannel != null) {
              final authCh = AuthService.to.userChannel!;
              if (authCh.status != ChannelStatus.deleted) {
                loaded = [authCh];
              }
            }

            channels.value = loaded;
            logger.debug('✅ Channels loaded: ${channels.length}');
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'PlaylistSyncManager.fetchChannels',
            );
            if (AuthService.to.userChannel != null) {
              channels.value = [AuthService.to.userChannel!];
            }
          },
        );
  }

  void fetchPlaylists() {
    _playlistsSubscription?.cancel();
    final user = getUserId();
    if (user.isEmpty) {
      logger.debug('📋 Cannot fetch playlists: no user logged in');
      isPlaylistsLoaded.value = false;
      return;
    }

    _playlistsSubscription = _firestore
        .collection(FirestoreCollections.users)
        .doc(user)
        .collection(FirestoreCollections.playlists)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
            final loadedPlaylists = snapshot.docs
                .map((doc) {
                  try {
                    return PlaylistModel.fromDocumentSnapshot(doc);
                  } catch (e) {
                    logger.debug('❌ Error parsing playlist ${doc.id}: $e');
                    return null;
                  }
                })
                .where((p) => p != null)
                .cast<PlaylistModel>()
                .toList();

            playlists.value = loadedPlaylists;
            isPlaylistsLoaded.value = true;
            logger.debug('📋 Loaded ${playlists.length} playlists');
          },
          onError: (error) {
            isPlaylistsLoaded.value = true;
            if (error.toString().contains('permission-denied')) {
              logger.debug(
                '📋 PlaylistSyncManager: Permission denied listening to playlists for user $user.',
              );
            } else {
              logger.debug(
                '❌ PlaylistSyncManager: Error listening to playlists: $error',
              );
            }
          },
        );
  }

  Future<void> refreshPlaylists() async {
    final user = getUserId();
    if (user.isEmpty) {
      logger.debug('📋 Cannot refresh playlists: no user logged in');
      return;
    }

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user)
          .collection(FirestoreCollections.playlists)
          .get();

      final loadedPlaylists = snapshot.docs
          .map((doc) {
            try {
              return PlaylistModel.fromDocumentSnapshot(doc);
            } catch (e) {
              logger.debug(
                '❌ Error parsing playlist ${doc.id} during refresh: $e',
              );
              return null;
            }
          })
          .where((p) => p != null)
          .cast<PlaylistModel>()
          .toList();

      playlists.value = loadedPlaylists;
      isPlaylistsLoaded.value = true;
      logger.debug('📋 Force refreshed ${playlists.length} playlists');
    } catch (e) {
      logger.debug('❌ Error force refreshing playlists: $e');
    }
  }

  void fetchPublicPlaylists() {
    _publicPlaylistsSubscription?.cancel();
    final user = getUserId();
    if (user.isEmpty) {
      logger.debug(
        '⚠️ fetchPublicPlaylists: No user logged in, skipping listener',
      );
      isPublicPlaylistsLoaded.value = false;
      return;
    }

    _publicPlaylistsSubscription = _firestore
        .collection('public_playlists')
        .orderBy('sortIndex')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
            final loadedPlaylists = snapshot.docs
                .map((doc) {
                  try {
                    return PlaylistModel.fromDocumentSnapshot(doc);
                  } catch (e) {
                    logger.debug(
                      '❌ Error parsing public playlist ${doc.id}: $e',
                    );
                    return null;
                  }
                })
                .where((p) => p != null && p.thumbnailUrl.trim().isNotEmpty)
                .cast<PlaylistModel>()
                .toList();

            publicPlaylists.value = loadedPlaylists;
            isPublicPlaylistsLoaded.value = true;
            logger.debug(
              '📋 Loaded ${publicPlaylists.length} public playlists',
            );
          },
          onError: (error, stackTrace) {
            isPublicPlaylistsLoaded.value = true;
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'PlaylistSyncManager.fetchPublicPlaylists',
            );
          },
        );
  }

  Future<void> refreshPublicPlaylists() async {
    try {
      final snapshot = await _firestore
          .collection('public_playlists')
          .orderBy('sortIndex')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedPlaylists = snapshot.docs
          .map((doc) {
            try {
              return PlaylistModel.fromDocumentSnapshot(doc);
            } catch (e) {
              logger.debug('❌ Error parsing public playlist ${doc.id}: $e');
              return null;
            }
          })
          .where((p) => p != null && p.thumbnailUrl.trim().isNotEmpty)
          .cast<PlaylistModel>()
          .toList();

      publicPlaylists.value = loadedPlaylists;
      logger.debug(
        '📋 Force refreshed ${publicPlaylists.length} public playlists',
      );
    } catch (e) {
      logger.debug('❌ Error refreshing public playlists: $e');
    }
  }

  Stream<List<PlaylistModel>> getPrivatePlaylists() {
    final user = getUserId();
    if (user.isEmpty) {
      logger.debug('⚠️ getPrivatePlaylists: No user logged in');
      return Stream.value([]);
    }

    return _firestore
        .collection(FirestoreCollections.users)
        .doc(user)
        .collection(FirestoreCollections.playlists)
        .orderBy('sortIndex')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
          logger.debug('❌ getPrivatePlaylists error: $error');
          return <PlaylistModel>[];
        })
        .map(
          (snap) => snap.docs.map(PlaylistModel.fromDocumentSnapshot).toList(),
        );
  }

  Stream<List<PlaylistModel>> getPublicPlaylists() {
    return _firestore
        .collection('public_playlists')
        .orderBy('sortIndex')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
          logger.debug('❌ getPublicPlaylists error: $error');
          return <PlaylistModel>[];
        })
        .map(
          (snap) => snap.docs.map(PlaylistModel.fromDocumentSnapshot).toList(),
        );
  }

  void handleUserLoggedOut() {
    _playlistsSubscription?.cancel();
    playlists.clear();
    isPlaylistsLoaded.value = false;
    _publicPlaylistsSubscription?.cancel();
    publicPlaylists.clear();
    isPublicPlaylistsLoaded.value = false;
  }

  void dispose() {
    _channelsSubscription?.cancel();
    _playlistsSubscription?.cancel();
    _publicPlaylistsSubscription?.cancel();
  }
}
