import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/domain/repositories/library_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Controller managing saved videos state, persistence, and synchronization.
class SavedVideosController extends BaseController {
  SavedVideosController({
    GetStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _storageInstance = storage,
        _firestoreInstance = firestore,
        _authInstance = auth;

  static SavedVideosController get to {
    if (!Get.isRegistered<SavedVideosController>()) {
      Get.put(SavedVideosController(), permanent: true);
    }
    return Get.find<SavedVideosController>();
  }

  static const String _keySavedVideoIds = 'saved_video_ids';
  final GetStorage? _storageInstance;
  final FirebaseFirestore? _firestoreInstance;
  final FirebaseAuth? _authInstance;

  GetStorage get _storage => _storageInstance ?? GetStorage();
  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  final RxList<Video> savedVideos = <Video>[].obs;
  final RxSet<String> savedVideoIds = <String>{}.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _savedVideosSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadFromLocalStorage();
    loadSavedVideos();
  }

  void _loadFromLocalStorage() {
    try {
      final rawSaved = _storage.read<List<dynamic>>(_keySavedVideoIds);
      if (rawSaved != null) {
        savedVideoIds.assignAll(rawSaved.map((e) => e.toString()));
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SavedVideosController.readLocalStorage',
      );
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      await _storage.write(_keySavedVideoIds, savedVideoIds.toList());
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SavedVideosController.saveLocalStorage',
      );
    }
  }

  bool isSaved(String videoId) {
    if (videoId.isEmpty) return false;
    return savedVideoIds.contains(videoId);
  }

  Future<void> loadSavedVideos() async {
    setViewState(ViewState.loading);
    try {
      _loadFromLocalStorage();

      final user = _auth.currentUser;
      if (user != null) {
        await _savedVideosSubscription?.cancel();

        final stream = _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .collection('saved_videos')
            .orderBy('savedAt', descending: true)
            .snapshots();

        _savedVideosSubscription = trackSubscription(
          stream.listen(
            (snapshot) async {
              final ids = snapshot.docs.map((doc) => doc.id).toSet();
              savedVideoIds.assignAll(ids);
              await _saveToLocalStorage();

              if (ids.isEmpty) {
                savedVideos.clear();
                setViewState(ViewState.empty);
                return;
              }

              final fetchedVideos = <Video>[];
              final missingIds = <String>[];

              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (data.containsKey('videoData') && data['videoData'] is Map) {
                  try {
                    fetchedVideos.add(
                      Video.fromMap(
                        Map<String, dynamic>.from(data['videoData'] as Map),
                        doc.id,
                      ),
                    );
                  } catch (e, stackTrace) {
                    ErrorHandler.log(
                      e,
                      stackTrace: stackTrace,
                      tag: 'SavedVideosController.parseVideoData',
                    );
                    missingIds.add(doc.id);
                  }
                } else {
                  missingIds.add(doc.id);
                }
              }

              if (missingIds.isNotEmpty) {
                final fetchedMissing = await _fetchVideosByIds(missingIds);
                fetchedVideos.addAll(fetchedMissing);
              }

              fetchedVideos.sort((a, b) {
                final indexA = snapshot.docs.indexWhere((doc) => doc.id == a.id);
                final indexB = snapshot.docs.indexWhere((doc) => doc.id == b.id);
                if (indexA == -1) return 1;
                if (indexB == -1) return -1;
                return indexA.compareTo(indexB);
              });

              savedVideos.assignAll(fetchedVideos);
              setViewState(
                savedVideos.isEmpty ? ViewState.empty : ViewState.success,
              );
            },
            onError: (error) {
              logException(error);
              setViewState(ViewState.error);
            },
          ),
        );
      } else {
        if (savedVideoIds.isNotEmpty) {
          final fetched = await _fetchVideosByIds(savedVideoIds.toList());
          savedVideos.assignAll(fetched);
        } else {
          savedVideos.clear();
        }
        setViewState(
          savedVideos.isEmpty ? ViewState.empty : ViewState.success,
        );
      }
    } catch (e) {
      handleError(e);
    }
  }

  Future<void> toggleSaveVideo(Video video) async {
    if (video.id.isEmpty) return;

    final currentlySaved = isSaved(video.id);

    if (currentlySaved) {
      savedVideoIds.remove(video.id);
      savedVideos.removeWhere((v) => v.id == video.id);
      await _saveToLocalStorage();

      final user = _auth.currentUser;
      if (user != null) {
        if (Get.isRegistered<LibraryRepository>()) {
          final libRepo = Get.find<LibraryRepository>();
          await libRepo.toggleSaveVideo(user.uid, video.toMap());
        } else {
          try {
            await _firestore
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .collection('saved_videos')
                .doc(video.id)
                .delete();
          } catch (e) {
            logException('Error removing saved video from Firestore: $e');
          }
        }
      }
      showSuccess('Removed from saved videos');
    } else {
      savedVideoIds.add(video.id);
      if (!savedVideos.any((v) => v.id == video.id)) {
        savedVideos.insert(0, video);
      }
      await _saveToLocalStorage();

      final user = _auth.currentUser;
      if (user != null) {
        if (Get.isRegistered<LibraryRepository>()) {
          final libRepo = Get.find<LibraryRepository>();
          await libRepo.toggleSaveVideo(user.uid, video.toMap());
        } else {
          try {
            await _firestore
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .collection('saved_videos')
                .doc(video.id)
                .set({
              'savedAt': FieldValue.serverTimestamp(),
              'videoId': video.id,
              'videoData': video.toMap(),
            });
          } catch (e) {
            logException('Error saving video to Firestore: $e');
          }
        }
      }
      showSuccess('Video saved successfully');
    }
  }

  Future<List<Video>> _fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Video>[];
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    try {
      final snapshots = await Future.wait(
        chunks.map(
          (chunk) => _firestore
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, whereIn: chunk)
              .getCacheFirst()
              .catchError((e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'SavedVideosController.fetchVideosChunk',
                );
                return _firestore.collection(FirestoreCollections.videos).limit(0).get();
              }),
        ),
      );

      for (final snap in snapshots) {
        results.addAll(snap.docs.map(Video.fromDocumentSnapshot));
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SavedVideosController.fetchVideosByIds',
      );
    }
    return results;
  }
}
