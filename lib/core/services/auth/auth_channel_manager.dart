import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/channel.dart';

/// Manages channel resolution, multi-tier fallback loading, and real-time channel state.
class AuthChannelManager {
  final RxBool _hasChannel = false.obs;
  RxBool get hasChannel => _hasChannel;

  final Rxn<Channel> _userChannel = Rxn<Channel>();
  Channel? get userChannel => _userChannel.value;
  Rxn<Channel> get rxUserChannel => _userChannel;

  StreamSubscription? _channelSubscription;
  String? _subscribedUid;
  final Set<String> _fallbackResolvedUids = <String>{};

  /// Loads locally cached channel existence flag synchronously.
  void initCachedChannelStatus(String? currentUid) {
    if (currentUid == null) return;
    try {
      final box = GetStorage();
      final savedHasChannel = box.read('hasChannel_$currentUid') as bool?;
      if (savedHasChannel != null) {
        _hasChannel.value = savedHasChannel;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthChannelManager.initCachedChannelStatus',
      );
    }
  }

  /// Sets the active channel and updates local cache.
  void setUserChannel(Channel? channel, [String? uid]) {
    _userChannel.value = channel;
    _hasChannel.value =
        channel != null && channel.status != ChannelStatus.deleted;
    if (uid != null) {
      GetStorage().write('hasChannel_$uid', _hasChannel.value);
      if (_hasChannel.value) {
        _fallbackResolvedUids.remove(uid);
      }
    }
  }

  /// Clears active channel reference and resets local cache.
  void clearUserChannel([String? uid]) {
    _userChannel.value = null;
    _hasChannel.value = false;
    if (uid != null) {
      GetStorage().write('hasChannel_$uid', false);
      _fallbackResolvedUids.remove(uid);
    }
  }

  /// Asynchronously guarantees that the user's channel is resolved from Firestore.
  /// Checks ownerId, userId, userDoc channelId, and email fallback.
  Future<Channel?> ensureChannelLoaded(User? user, FirebaseAuth auth) async {
    if (_hasChannel.value && _userChannel.value != null) {
      return _userChannel.value;
    }
    var u = user;
    if (u == null) {
      try {
        u = auth.currentUser;
      } catch (_) {
        u = null;
      }
    }
    if (u == null || u.isAnonymous) return null;

    try {
      // 1. Direct check by ownerId
      var snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .where('ownerId', isEqualTo: u.uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // 2. Direct check by userId
        snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('userId', isEqualTo: u.uid)
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final activeChannels = snap.docs
            .map(Channel.fromDocumentSnapshot)
            .where((c) => c.status != ChannelStatus.deleted)
            .toList();
        if (activeChannels.isNotEmpty) {
          final ch = activeChannels.first;
          setUserChannel(ch, u.uid);
          return ch;
        }
      }

      // 3. Direct check user doc for channelId
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(u.uid)
          .get();
      final chId = userDoc.data()?['channelId'] as String?;
      if (chId != null && chId.isNotEmpty) {
        final chDoc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(chId)
            .get();
        if (chDoc.exists && chDoc.data() != null) {
          final ch = Channel.fromDocumentSnapshot(chDoc);
          if (ch.status != ChannelStatus.deleted) {
            setUserChannel(ch, u.uid);
            return ch;
          }
        }
      }

      // 4. Direct check by email if available
      if (u.email != null && u.email!.isNotEmpty) {
        final emailSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('email', isEqualTo: u.email)
            .limit(1)
            .get();
        final emailChannels = emailSnap.docs
            .map(Channel.fromDocumentSnapshot)
            .where((c) => c.status != ChannelStatus.deleted)
            .toList();
        if (emailChannels.isNotEmpty) {
          final ch = emailChannels.first;
          setUserChannel(ch, u.uid);
          return ch;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthChannelManager.ensureChannelLoaded',
      );
    }
    return _userChannel.value;
  }

  /// Sets up real-time listener for user channel documents with cascading fallback resolvers.
  void updateChannelSubscription(User? user) {
    if (user == null) {
      _subscribedUid = null;
      _channelSubscription?.cancel();
      _channelSubscription = null;
      _hasChannel.value = false;
      _userChannel.value = null;
      return;
    }

    if (_subscribedUid == user.uid && _channelSubscription != null) {
      return;
    }

    _subscribedUid = user.uid;
    _channelSubscription?.cancel();

    _channelSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.channels)
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) async {
            final activeChannels = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();

            if (activeChannels.isNotEmpty) {
              _hasChannel.value = true;
              _userChannel.value = activeChannels.first;
              GetStorage().write('hasChannel_${user.uid}', true);
              return;
            }

            // High-scale optimization: The overwhelming majority of users are viewers with no channel.
            // Avoid firing 3 un-cached fallback queries on every subsequent stream snapshot or reconnect event.
            if (_fallbackResolvedUids.contains(user.uid)) {
              _hasChannel.value = false;
              _userChannel.value = null;
              GetStorage().write('hasChannel_${user.uid}', false);
              return;
            }
            _fallbackResolvedUids.add(user.uid);

            // Fallback 1: Check by userId if ownerId returned nothing
            try {
              final userSnap = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .where('userId', isEqualTo: user.uid)
                  .limit(1)
                  .get();
              final userChannels = userSnap.docs
                  .map(Channel.fromDocumentSnapshot)
                  .where((c) => c.status != ChannelStatus.deleted)
                  .toList();
              if (userChannels.isNotEmpty) {
                final ch = userChannels.first;
                _hasChannel.value = true;
                _userChannel.value = ch;
                GetStorage().write('hasChannel_${user.uid}', true);
                // Promote to ownerId so subsequent queries resolve via primary listener
                FirebaseFirestore.instance
                    .collection(FirestoreCollections.channels)
                    .doc(ch.id)
                    .update({'ownerId': user.uid}).catchError((_) {});
                return;
              }
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'AuthChannelManager.fallbackChannelByUserId',
              );
            }

            // Fallback 2: Check user document for channelId reference
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.users)
                  .doc(user.uid)
                  .get();
              final chId = userDoc.data()?['channelId'] as String?;
              if (chId != null && chId.isNotEmpty) {
                final chDoc = await FirebaseFirestore.instance
                    .collection(FirestoreCollections.channels)
                    .doc(chId)
                    .get();
                if (chDoc.exists && chDoc.data() != null) {
                  final ch = Channel.fromDocumentSnapshot(chDoc);
                  if (ch.status != ChannelStatus.deleted) {
                    _hasChannel.value = true;
                    _userChannel.value = ch;
                    GetStorage().write('hasChannel_${user.uid}', true);
                    FirebaseFirestore.instance
                        .collection(FirestoreCollections.channels)
                        .doc(ch.id)
                        .update({'ownerId': user.uid}).catchError((_) {});
                    return;
                  }
                }
              }
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'AuthChannelManager.fallbackChannelByUserDoc',
              );
            }

            // Fallback 3: Check channels by email to ensure channel is never lost
            if (user.email != null && user.email!.isNotEmpty) {
              try {
                final emailSnap = await FirebaseFirestore.instance
                    .collection(FirestoreCollections.channels)
                    .where('email', isEqualTo: user.email)
                    .limit(1)
                    .get();
                final emailChannels = emailSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((c) => c.status != ChannelStatus.deleted)
                    .toList();
                if (emailChannels.isNotEmpty) {
                  final ch = emailChannels.first;
                  _hasChannel.value = true;
                  _userChannel.value = ch;
                  GetStorage().write('hasChannel_${user.uid}', true);
                  // Update channel ownerId and userId to current active uid
                  try {
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.channels)
                        .doc(ch.id)
                        .update({
                          'ownerId': user.uid,
                          'userId': user.uid,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                  } catch (e, s) {
                    ErrorHandler.log(
                      e,
                      stackTrace: s,
                      tag: 'AuthChannelManager.updateChannelOwner',
                    );
                  }
                  return;
                }
              } catch (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'AuthChannelManager.fallbackChannelByEmail',
                );
              }
            }

            _hasChannel.value = false;
            _userChannel.value = null;
            GetStorage().write('hasChannel_${user.uid}', false);
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'AuthChannelManager.channelSubscription',
            );
          },
        );
  }

  /// Cancels active Firestore channel subscription.
  void dispose() {
    _subscribedUid = null;
    _fallbackResolvedUids.clear();
    _channelSubscription?.cancel();
    _channelSubscription = null;
  }
}
