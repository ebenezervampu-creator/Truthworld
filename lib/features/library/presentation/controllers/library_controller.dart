import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';

class LibraryController extends BaseController
    with GetTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rxn<User> rxUser = Rxn<User>();

  final RxList<Video> watchHistory = <Video>[].obs;
  final RxList<PlaylistModel> playlists = <PlaylistModel>[].obs;
  final RxList<Video> likedVideos = <Video>[].obs;
  final RxList<VideoClip> clips = <VideoClip>[].obs;
  final RxList<Video> yourVideos = <Video>[].obs;

  final RxString activeView = 'main'.obs;
  final Rxn<PlaylistModel> selectedPlaylist = Rxn<PlaylistModel>();

  void changeView(String view, {PlaylistModel? playlist}) {
    selectedPlaylist.value = playlist;
    activeView.value = view;
  }

  final RxBool isLoadingHistory = false.obs;
  final RxBool isLoadingPlaylists = false.obs;
  final RxBool isLoadingLiked = false.obs;
  final RxBool isLoadingClips = false.obs;
  final RxBool isLoadingYourVideos = false.obs;

  StreamSubscription? _userSub;

  // Animation controllers and animations
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late AnimationController scaleAnimationController;

  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();

    rxUser.value = _auth.currentUser;
    _userSub = _auth.authStateChanges().listen(
      (user) {
        rxUser.value = user;
        if (user != null) {
          loadUserData(user.uid);
        } else {
          _clearUserData();
        }
      },
      onError: (e, stackTrace) => ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'LibraryController._userSub',
      ),
    );
    if (_userSub != null) trackSubscription(_userSub!);

    if (_auth.currentUser != null) {
      loadUserData(_auth.currentUser!.uid);
    }
  }

  void _initializeAnimations() {
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Start animations
    if (Get.testMode) {
      fadeAnimationController.value = 1.0;
      slideAnimationController.value = 1.0;
      scaleAnimationController.value = 1.0;
    } else {
      fadeAnimationController.forward();
      slideAnimationController.forward();
      scaleAnimationController.forward();
    }
  }

  @override
  void onClose() {
    _userSub?.cancel();
    fadeAnimationController.stop();
    slideAnimationController.stop();
    scaleAnimationController.stop();
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    scaleAnimationController.dispose();
    super.onClose();
  }

  void _clearUserData() {
    watchHistory.clear();
    playlists.clear();
    likedVideos.clear();
    clips.clear();
    yourVideos.clear();
  }

  Future<void> loadUserData(String uid) async {
    isLoadingHistory.value = true;
    isLoadingPlaylists.value = true;
    isLoadingLiked.value = true;
    isLoadingClips.value = true;
    isLoadingYourVideos.value = true;

    await Future.wait([
      // 1. History (one-time fetch)
      (() async {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.users)
              .doc(uid)
              .collection('watch_history')
              .orderBy('watchedAt', descending: true)
              .limit(10)
              .get();
          watchHistory.value = snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .toList();
        } catch (e) {
          debugPrint('LibraryController history error: $e');
        } finally {
          isLoadingHistory.value = false;
        }
      })(),

      // 2. Playlists (one-time fetch)
      (() async {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.users)
              .doc(uid)
              .collection(FirestoreCollections.playlists)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get();
          playlists.value = snapshot.docs
              .map(PlaylistModel.fromDocumentSnapshot)
              .toList();
        } catch (e) {
          debugPrint('LibraryController playlists error: $e');
        } finally {
          isLoadingPlaylists.value = false;
        }
      })(),

      // 3. Liked videos (one-time fetch)
      (() async {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.users)
              .doc(uid)
              .collection('likedVideos')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();
          if (snapshot.docs.isEmpty) {
            likedVideos.clear();
          } else {
            final videoIds = snapshot.docs.map((doc) => doc.id).toList();
            final videoDocs = await _fetchVideosInBatches(videoIds);
            final videoMap = {for (final v in videoDocs) v.id: v};
            final orderedVideos = videoIds
                .where(videoMap.containsKey)
                .map((id) => videoMap[id]!)
                .toList();
            likedVideos.value = orderedVideos;
          }
        } catch (e) {
          debugPrint('LibraryController liked error: $e');
        } finally {
          isLoadingLiked.value = false;
        }
      })(),

      // 4. Clips (one-time fetch)
      (() async {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.users)
              .doc(uid)
              .collection('clips')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();
          clips.value = snapshot.docs
              .map(VideoClip.fromDocumentSnapshot)
              .toList();
        } catch (e) {
          debugPrint('LibraryController clips error: $e');
        } finally {
          isLoadingClips.value = false;
        }
      })(),

      // 5. Your Videos (one-time fetch)
      (() async {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: uid)
              .limit(20)
              .get();
          final list = snapshot.docs.map(Video.fromDocumentSnapshot).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yourVideos.value = list.take(10).toList();
        } catch (e) {
          debugPrint('LibraryController yourVideos error: $e');
        } finally {
          isLoadingYourVideos.value = false;
        }
      })(),
    ]);
  }

  Future<void> refreshLibrary() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await loadUserData(uid);
    }
  }

  Future<List<Video>> _fetchVideosInBatches(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];
    try {
      final allVideos = <Video>[];
      for (var i = 0; i < videoIds.length; i += 10) {
        final batch = videoIds.sublist(
          i,
          i + 10 > videoIds.length ? videoIds.length : i + 10,
        );
        final docs = await _firestore
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        allVideos.addAll(docs.docs.map(Video.fromDocumentSnapshot));
      }
      return allVideos;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LibraryController.fetchLikedVideos',
      );
      return [];
    }
  }
}
