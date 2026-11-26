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

  final Rxn<Channel> _deletedChannel = Rxn<Channel>();
  Channel? get deletedChannel => _deletedChannel.value;
  Rxn<Channel> get rxDeletedChannel => _deletedChannel;

  StreamSubscription? _channelSubscription;
  String? _subscribedUid;
  final Set<String> _fallbackResolvedUids = <String>{};

  /// Loads locally cached channel existence flag and channel data synchronously.
  void initCachedChannelStatus(String? currentUid) {
    if (currentUid == null || currentUid.isEmpty) return;
    try {
      final box = GetStorage();
      final savedHasChannel = box.read('hasChannel_$currentUid') as bool?;
      if (savedHasChannel != null) {
        _hasChannel.value = savedHasChannel;
      }
      final savedChannelData = box.read('channel_data_$currentUid');
      final savedChannelId = box.read('channel_id_$currentUid') as String?;
      if (savedChannelData is Map &&
          savedChannelId != null &&
          savedChannelId.isNotEmpty) {
        try {
          final channelMap = Map<String, dynamic>.from(savedChannelData);
          final ch = Channel.fromMap(channelMap, savedChannelId);
          if (ch.status != ChannelStatus.deleted) {
            _userChannel.value = ch;
            _hasChannel.value = true;
          }
        } catch (parseErr, parseStack) {
          ErrorHandler.log(
            parseErr,
            stackTrace: parseStack,
            tag: 'AuthChannelManager.initCachedChannelStatus.parse',
          );
        }
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
    final prev = _userChannel.value;
    if (prev != null && channel != null && prev.id == channel.id) {
      final isSame = prev.status == channel.status &&
          prev.name == channel.name &&
          prev.handle == channel.handle &&
          prev.avatarUrl == channel.avatarUrl &&
          prev.bannerUrl == channel.bannerUrl &&
          prev.subscriberCount == channel.subscriberCount &&
          prev.videoCount == channel.videoCount &&
          prev.updatedAt == channel.updatedAt &&
          prev.isVerified == channel.isVerified;
      if (isSame) {
        return;
      }
    } else if (prev == null && channel == null) {
      return;
    }

    _userChannel.value = channel;
    _hasChannel.value =
        channel != null && channel.status != ChannelStatus.deleted;
    if (_hasChannel.value) {
      _deletedChannel.value = null;
    } else if (channel != null && channel.status == ChannelStatus.deleted) {
      _deletedChannel.value = channel;
    }
    if (uid != null && uid.isNotEmpty) {
      final box = GetStorage();
      box.write('hasChannel_$uid', _hasChannel.value);
      if (_hasChannel.value && channel != null) {
        _fallbackResolvedUids.remove(uid);
        box.write('channel_id_$uid', channel.id);
        box.write('channel_avatar_$uid', channel.avatarUrl);
        box.write('channel_name_$uid', channel.name);
        box.write('channel_handle_$uid', channel.handle);
        box.write('channel_data_$uid', channel.toCacheMap());
      } else {
        box.remove('channel_id_$uid');
        box.remove('channel_avatar_$uid');
        box.remove('channel_name_$uid');
        box.remove('channel_handle_$uid');
        box.remove('channel_data_$uid');
      }
    }
  }

  /// Sets or clears deleted channel reference
  void setDeletedChannel(Channel? channel) {
    _deletedChannel.value = channel;
  }

  /// Clears active channel reference and resets local cache.
  void clearUserChannel([String? uid]) {
    _userChannel.value = null;
    _hasChannel.value = false;
    _deletedChannel.value = null;
    _fallbackResolvedUids.clear();
    if (uid != null && uid.isNotEmpty) {
      final box = GetStorage();
      box.write('hasChannel_$uid', false);
      box.remove('channel_id_$uid');
      box.remove('channel_avatar_$uid');
      box.remove('channel_name_$uid');
      box.remove('channel_handle_$uid');
      box.remove('channel_data_$uid');
    }
  }

  /// Asynchronously guarantees that the user's channel is resolved from Firestore.
  /// Checks ownerId, userId, userDoc channelId, and email fallback.
  Future<Channel?> ensureChannelLoaded(
    User? user,
    FirebaseAuth auth, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasChannel.value && _userChannel.value != null) {
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

    // Check synchronous local cache first before firing remote Firestore query
    if (_userChannel.value == null) {
      initCachedChannelStatus(u.uid);
      if (_hasChannel.value && _userChannel.value != null) {
        return _userChannel.value;
      }
    }

    try {
      // 1. Direct check by ownerId
      var snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .where('ownerId', isEqualTo: u.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (snap.docs.isEmpty) {
        // 2. Direct check by userId
        snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('userId', isEqualTo: u.uid)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
      }

      if (snap.docs.isNotEmpty) {
        final allChannels =
            snap.docs.map(Channel.fromDocumentSnapshot).toList();
        final activeChannels = allChannels
            .where((c) => c.status != ChannelStatus.deleted)
            .toList();
        if (activeChannels.isNotEmpty) {
          final ch = activeChannels.first;
          setUserChannel(ch, u.uid);
          return ch;
        }
        final deletedChannels = allChannels
            .where((c) => c.status == ChannelStatus.deleted)
            .toList();
        if (deletedChannels.isNotEmpty) {
          _deletedChannel.value = deletedChannels.first;
        }
      }

      // 3. Direct check user doc for channelId
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(u.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final chId = userDoc.data()?['channelId'] as String?;
      if (chId != null && chId.isNotEmpty) {
        final chDoc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(chId)
            .get()
            .timeout(const Duration(seconds: 8));
        if (chDoc.exists && chDoc.data() != null) {
          final ch = Channel.fromDocumentSnapshot(chDoc);
          if (ch.status != ChannelStatus.deleted) {
            setUserChannel(ch, u.uid);
            return ch;
          } else {
            _deletedChannel.value = ch;
          }
        }
      }

      // 4. Direct check by email if available
      if (u.email != null && u.email!.isNotEmpty) {
        final emailSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('email', isEqualTo: u.email)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
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
            final allChannels = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .toList();

            final activeChannels = allChannels
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();

            if (activeChannels.isNotEmpty) {
              final ch = activeChannels.first;
              setUserChannel(ch, user.uid);
              return;
            }

            final deletedChannels = allChannels
                .where((c) => c.status == ChannelStatus.deleted)
                .toList();
            if (deletedChannels.isNotEmpty) {
              _deletedChannel.value = deletedChannels.first;
            } else {
              _deletedChannel.value = null;
            }

            // High-scale optimization: The overwhelming majority of users are viewers with no channel.
            // Avoid firing 3 un-cached fallback queries on every subsequent stream snapshot or reconnect event.
            if (_fallbackResolvedUids.contains(user.uid)) {
              if (_userChannel.value == null) {
                _hasChannel.value = false;
                GetStorage().write('hasChannel_${user.uid}', false);
              }
              return;
            }
            _fallbackResolvedUids.add(user.uid);

            // Fallback 1: Check by userId if ownerId returned nothing
            try {
              final userSnap = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .where('userId', isEqualTo: user.uid)
                  .limit(1)
                  .get()
                  .timeout(const Duration(seconds: 8));
              final userChannels = userSnap.docs
                  .map(Channel.fromDocumentSnapshot)
                  .where((c) => c.status != ChannelStatus.deleted)
                  .toList();
              if (userChannels.isNotEmpty) {
                final ch = userChannels.first;
                setUserChannel(ch, user.uid);
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
                  .get()
                  .timeout(const Duration(seconds: 8));
              final chId = userDoc.data()?['channelId'] as String?;
              if (chId != null && chId.isNotEmpty) {
                final chDoc = await FirebaseFirestore.instance
                    .collection(FirestoreCollections.channels)
                    .doc(chId)
                    .get()
                    .timeout(const Duration(seconds: 8));
                if (chDoc.exists && chDoc.data() != null) {
                  final ch = Channel.fromDocumentSnapshot(chDoc);
                  if (ch.status != ChannelStatus.deleted) {
                    setUserChannel(ch, user.uid);
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
                    .get()
                    .timeout(const Duration(seconds: 8));
                final emailChannels = emailSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((c) => c.status != ChannelStatus.deleted)
                    .toList();
                if (emailChannels.isNotEmpty) {
                  final ch = emailChannels.first;
                  setUserChannel(ch, user.uid);
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

            if (_userChannel.value == null) {
              _hasChannel.value = false;
              GetStorage().write('hasChannel_${user.uid}', false);
            }
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
