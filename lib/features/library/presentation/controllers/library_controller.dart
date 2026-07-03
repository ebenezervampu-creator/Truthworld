import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';

class LibraryController extends GetxController
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
  StreamSubscription? _historySub;
  StreamSubscription? _playlistsSub;
  StreamSubscription? _likedSub;
  StreamSubscription? _clipsSub;
  StreamSubscription? _yourVideosSub;

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
    _userSub = _auth.authStateChanges().listen((user) {
      rxUser.value = user;
      if (user != null) {
        _subscribeToUserData(user.uid);
      } else {
        _clearUserData();
      }
    });

    if (_auth.currentUser != null) {
      _subscribeToUserData(_auth.currentUser!.uid);
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

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Start animations
    fadeAnimationController.forward();
    slideAnimationController.forward();
    scaleAnimationController.forward();
  }

  @override
  void onClose() {
    _cancelAllSubscriptions();
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    scaleAnimationController.dispose();
    super.onClose();
  }

  void _clearUserData() {
    _cancelDataSubscriptions();
    watchHistory.clear();
    playlists.clear();
    likedVideos.clear();
    clips.clear();
    yourVideos.clear();
  }

  void _cancelAllSubscriptions() {
    _userSub?.cancel();
    _cancelDataSubscriptions();
  }

  void _cancelDataSubscriptions() {
    _historySub?.cancel();
    _playlistsSub?.cancel();
    _likedSub?.cancel();
    _clipsSub?.cancel();
    _yourVideosSub?.cancel();
  }

  void _subscribeToUserData(String uid) {
    _cancelDataSubscriptions();

    isLoadingHistory.value = true;
    _historySub = _firestore
        .collection('users')
        .doc(uid)
        .collection('watch_history')
        .orderBy('watchedAt', descending: true)
        .limit(10)
        .snapshots()
        .listen(
          (snapshot) {
            watchHistory.value = snapshot.docs
                .map((doc) => Video.fromDocumentSnapshot(doc))
                .toList();
            isLoadingHistory.value = false;
          },
          onError: (e) {
            isLoadingHistory.value = false;
          },
        );

    isLoadingPlaylists.value = true;
    _playlistsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_playlists')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            playlists.value = snapshot.docs
                .map((doc) => PlaylistModel.fromDocumentSnapshot(doc))
                .toList();
            isLoadingPlaylists.value = false;
          },
          onError: (e) {
            isLoadingPlaylists.value = false;
          },
        );

    isLoadingLiked.value = true;
    _likedSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('likedVideos')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.docs.isEmpty) {
              likedVideos.clear();
              isLoadingLiked.value = false;
              return;
            }
            final videoIds = snapshot.docs.map((doc) => doc.id).toList();
            final videoDocs = await _fetchVideosInBatches(videoIds);
            final videoMap = {for (var v in videoDocs) v.id: v};
            final orderedVideos = videoIds
                .where((id) => videoMap.containsKey(id))
                .map((id) => videoMap[id]!)
                .toList();
            likedVideos.value = orderedVideos;
            isLoadingLiked.value = false;
          },
          onError: (e) {
            isLoadingLiked.value = false;
          },
        );

    isLoadingClips.value = true;
    _clipsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('clips')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen(
          (snapshot) {
            clips.value = snapshot.docs
                .map((doc) => VideoClip.fromDocumentSnapshot(doc))
                .toList();
            isLoadingClips.value = false;
          },
          onError: (e) {
            isLoadingClips.value = false;
          },
        );

    isLoadingYourVideos.value = true;
    _yourVideosSub = _firestore
        .collection('videos')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            final list = snapshot.docs
                .map((doc) => Video.fromDocumentSnapshot(doc))
                .toList();
            // Sort in-memory to prevent missing composite index errors
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            yourVideos.value = list.take(10).toList();
            isLoadingYourVideos.value = false;
          },
          onError: (e) {
            debugPrint('LibraryController yourVideos error: $e');
            isLoadingYourVideos.value = false;
          },
        );
  }

  Future<List<Video>> _fetchVideosInBatches(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];
    try {
      final docs = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: videoIds)
          .get();
      return docs.docs.map((doc) => Video.fromDocumentSnapshot(doc)).toList();
    } catch (e) {
      debugPrint('LibraryController fetch liked videos error: $e');
      return [];
    }
  }
}
