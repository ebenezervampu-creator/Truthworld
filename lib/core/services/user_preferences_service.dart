import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized service for managing user content preferences (hidden videos, blocked channels).
class UserPreferencesService extends GetxService {
  static UserPreferencesService get to {
    if (!Get.isRegistered<UserPreferencesService>()) {
      Get.put(UserPreferencesService(), permanent: true);
    }
    return Get.find<UserPreferencesService>();
  }

  static const String _keyHiddenVideos = 'hidden_video_ids';
  static const String _keyBlockedChannels = 'blocked_channel_ids';
  static const String _keyBlockedChannelNames = 'blocked_channel_names';

  final GetStorage _storage = GetStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxSet<String> hiddenVideoIds = <String>{}.obs;
  final RxSet<String> blockedChannelIds = <String>{}.obs;
  final RxSet<String> blockedChannelNames = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
    _syncFromFirestore();
  }

  void _loadFromStorage() {
    try {
      final rawHidden = _storage.read<List<dynamic>>(_keyHiddenVideos);
      if (rawHidden != null) {
        hiddenVideoIds.assignAll(rawHidden.map((e) => e.toString()));
      }

      final rawBlockedIds = _storage.read<List<dynamic>>(_keyBlockedChannels);
      if (rawBlockedIds != null) {
        blockedChannelIds.assignAll(rawBlockedIds.map((e) => e.toString()));
      }

      final rawBlockedNames = _storage.read<List<dynamic>>(
        _keyBlockedChannelNames,
      );
      if (rawBlockedNames != null) {
        blockedChannelNames.assignAll(rawBlockedNames.map((e) => e.toString()));
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserPreferencesService._loadFromStorage');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      await _storage.write(_keyHiddenVideos, hiddenVideoIds.toList());
      await _storage.write(_keyBlockedChannels, blockedChannelIds.toList());
      await _storage.write(
        _keyBlockedChannelNames,
        blockedChannelNames.toList(),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserPreferencesService._saveToStorage');
    }
  }

  Future<void> _syncFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final fsHidden = List<String>.from(
            data['notInterestedVideoIds'] ?? [],
          );
          final fsBlockedIds = List<String>.from(
            data['blockedChannelIds'] ?? [],
          );
          final fsBlockedNames = List<String>.from(
            data['blockedChannelNames'] ?? [],
          );

          if (fsHidden.isNotEmpty) hiddenVideoIds.addAll(fsHidden);
          if (fsBlockedIds.isNotEmpty) blockedChannelIds.addAll(fsBlockedIds);
          if (fsBlockedNames.isNotEmpty) {
            blockedChannelNames.addAll(fsBlockedNames);
          }

          _saveToStorage();
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserPreferencesService._syncFromFirestore');
    }
  }

  Future<void> hideVideo(String videoId) async {
    if (videoId.isEmpty) return;
    hiddenVideoIds.add(videoId);
    await _saveToStorage();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .set({
              'notInterestedVideoIds': FieldValue.arrayUnion([videoId]),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserPreferencesService.hideVideo',
        );
      }
    }
  }

  Future<void> unhideVideo(String videoId) async {
    if (videoId.isEmpty) return;
    hiddenVideoIds.remove(videoId);
    await _saveToStorage();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .set({
              'notInterestedVideoIds': FieldValue.arrayRemove([videoId]),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserPreferencesService.unhideVideo',
        );
      }
    }
  }

  Future<void> blockChannel(String channelId, {String? channelName}) async {
    var changed = false;
    if (channelId.isNotEmpty) {
      blockedChannelIds.add(channelId);
      changed = true;
    }
    if (channelName != null && channelName.isNotEmpty) {
      blockedChannelNames.add(channelName);
      changed = true;
    }
    if (!changed) return;

    await _saveToStorage();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (channelId.isNotEmpty) {
          updates['blockedChannelIds'] = FieldValue.arrayUnion([channelId]);
        }
        if (channelName != null && channelName.isNotEmpty) {
          updates['blockedChannelNames'] = FieldValue.arrayUnion([channelName]);
        }
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .set(updates, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserPreferencesService.blockChannel',
        );
      }
    }
  }

  Future<void> unblockChannel(String channelId, {String? channelName}) async {
    if (channelId.isNotEmpty) blockedChannelIds.remove(channelId);
    if (channelName != null && channelName.isNotEmpty) {
      blockedChannelNames.remove(channelName);
    }

    await _saveToStorage();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (channelId.isNotEmpty) {
          updates['blockedChannelIds'] = FieldValue.arrayRemove([channelId]);
        }
        if (channelName != null && channelName.isNotEmpty) {
          updates['blockedChannelNames'] = FieldValue.arrayRemove([
            channelName,
          ]);
        }
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .set(updates, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'UserPreferencesService.unblockChannel',
        );
      }
    }
  }

  bool isVideoHidden(String videoId) {
    if (videoId.isEmpty) return false;
    return hiddenVideoIds.contains(videoId);
  }

  bool isChannelBlocked(String channelId, {String? channelName}) {
    if (channelId.isNotEmpty && blockedChannelIds.contains(channelId)) {
      return true;
    }
    if (channelName != null &&
        channelName.isNotEmpty &&
        blockedChannelNames.contains(channelName)) {
      return true;
    }
    return false;
  }

  bool isVideoBlocked(Video video) {
    if (isVideoHidden(video.id)) return true;
    if (isChannelBlocked(video.channelId, channelName: video.channelName)) {
      return true;
    }
    return false;
  }

  List<Video> filterVideos(List<Video> videos) {
    if (videos.isEmpty) return videos;
    return videos.where((v) => !isVideoBlocked(v)).toList();
  }
}
