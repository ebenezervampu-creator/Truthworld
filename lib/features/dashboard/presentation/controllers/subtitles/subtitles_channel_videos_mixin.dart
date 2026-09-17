import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Mixin handling channel context, video queries, and video list selection
mixin SubtitlesChannelVideosMixin on SubtitlesControllerBase {
  Future<void> initializeContext() async {
    try {
      setViewState(ViewState.loading);
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        setError('User not authenticated');
        return;
      }

      // Resolve channel ID from navigation arguments or user document
      final channelArg = Get.arguments?['channel'];
      if (channelArg != null) {
        if (channelArg is Map) {
          channelId.value = channelArg['id'] ?? '';
        } else if (channelArg is DocumentSnapshot) {
          channelId.value = channelArg.id;
        }
      }

      if (channelId.value.isEmpty) {
        final userDoc = await firestore
            .collection(FirestoreCollections.users)
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          channelId.value = userDoc.data()!['channelId'] ?? currentUser.uid;
        } else {
          channelId.value = currentUser.uid;
        }
      }

      listenToChannelVideos();
    } catch (e, stack) {
      logger.error(
        'Failed to initialize subtitles context',
        error: e,
        stackTrace: stack,
        tag: SubtitlesControllerBase.subtitlesTag,
      );
      setError('Initialization failed');
    }
  }

  void setChannelContext(String id) {
    if (id.isNotEmpty && channelId.value != id) {
      channelId.value = id;
      listenToChannelVideos();
    }
  }

  void listenToChannelVideos() {
    final currentUser = auth.currentUser;
    final targetOwnerId = currentUser?.uid ?? '';
    final targetChannelId = channelId.value;

    if (targetOwnerId.isEmpty && targetChannelId.isEmpty) {
      setError('User not authenticated and Channel ID is missing');
      return;
    }

    videosSubscription?.cancel();
    channelVideosSubscription?.cancel();
    ownerVideosMap.clear();
    channelVideosMap.clear();

    void updateVideosList() {
      final combinedMap = <String, Video>{
        ...ownerVideosMap,
        ...channelVideosMap,
      };
      final loadedVideos = combinedMap.values.toList();
      loadedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      videos.value = loadedVideos;
      applySearchFilter();

      setViewState(loadedVideos.isEmpty ? ViewState.empty : ViewState.success);

      // Preserve or auto-select a video
      if (selectedVideo.value != null) {
        final updatedVideo = loadedVideos.firstWhereOrNull(
          (v) => v.id == selectedVideo.value!.id,
        );
        if (updatedVideo != null) {
          selectedVideo.value = updatedVideo;
        } else {
          selectVideo(loadedVideos.isNotEmpty ? loadedVideos.first : null);
        }
      } else if (loadedVideos.isNotEmpty) {
        selectVideo(loadedVideos.first);
      }
    }

    if (targetOwnerId.isNotEmpty) {
      videosSubscription = firestore
          .collection(FirestoreCollections.videos)
          .where('ownerId', isEqualTo: targetOwnerId)
          .snapshots()
          .listen(
            (snapshot) {
              ownerVideosMap.clear();
              for (final doc in snapshot.docs) {
                final video = Video.fromDocumentSnapshot(doc);
                ownerVideosMap[video.id] = video;
              }
              updateVideosList();
            },
            onError: (e) {
              logger.error('Error streaming owner videos', error: e, tag: SubtitlesControllerBase.subtitlesTag);
              if (channelVideosMap.isEmpty) {
                setError('Failed to fetch videos');
              }
            },
          );
    }

    if (targetChannelId.isNotEmpty && targetChannelId != targetOwnerId) {
      channelVideosSubscription = firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: targetChannelId)
          .snapshots()
          .listen(
            (snapshot) {
              channelVideosMap.clear();
              for (final doc in snapshot.docs) {
                final video = Video.fromDocumentSnapshot(doc);
                channelVideosMap[video.id] = video;
              }
              updateVideosList();
            },
            onError: (e) {
              logger.error(
                'Error streaming channel videos',
                error: e,
                tag: SubtitlesControllerBase.subtitlesTag,
              );
            },
          );
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    applySearchFilter();
  }

  void applySearchFilter() {
    if (searchQuery.value.trim().isEmpty) {
      filteredVideos.value = videos;
      return;
    }
    final q = searchQuery.value.toLowerCase().trim();
    filteredVideos.value = videos.where((v) {
      return v.title.toLowerCase().contains(q) ||
          v.description.toLowerCase().contains(q) ||
          v.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> selectVideo(Video? video) async {
    selectedVideo.value = video;
    hasUnsavedChanges.value = false;
    requestsSubscription?.cancel();
    if (video == null) {
      disposeVideoPlayer();
      availableLanguages.clear();
      selectedLanguage.value = '';
      currentCues.clear();
      languageRequests.clear();
      return;
    }

    logger.info('Selected video for subtitles: ${video.title}', tag: SubtitlesControllerBase.subtitlesTag);

    listenToLanguageRequests(video.id);

    // Lazy-load localization from subcollection first
    await VideoMediaService().getLocalization(video.id);

    // Parse existing mediaSubtitles map
    final subs = video.mediaSubtitles;

    final orderedLangs = <String>[];

    // Always add 'en' first
    if (!orderedLangs.contains('en')) {
      orderedLangs.add('en');
    }

    // Add all languages that have existing subtitle URLs
    for (final lang in subs.keys) {
      if (!orderedLangs.contains(lang)) {
        orderedLangs.add(lang);
      }
    }

    // Add pending translation languages from video.languages
    final langNameToCode = <String, String>{
      'tamil': 'ta',
      'hindi': 'hi',
      'telugu': 'te',
      'kannada': 'kn',
      'malayalam': 'ml',
      'spanish': 'es',
      'french': 'fr',
      'arabic': 'ar',
      'portuguese': 'pt',
      'german': 'de',
      'japanese': 'ja',
      'korean': 'ko',
      'chinese': 'zh',
      'bengali': 'bn',
      'marathi': 'mr',
      'gujarati': 'gu',
      'punjabi': 'pa',
      'urdu': 'ur',
    };

    for (final langName in video.languages) {
      final code =
          langNameToCode[langName.toLowerCase()] ?? langName.toLowerCase();
      if (!orderedLangs.contains(code) && !orderedLangs.contains(langName)) {
        orderedLangs.add(code);
      }
    }

    if (orderedLangs.isEmpty) {
      availableLanguages.value = ['en'];
      selectedLanguage.value = 'en';
      currentCues.clear();
    } else {
      availableLanguages.value = orderedLangs;
      final defaultLang =
          orderedLangs.contains('en') ? 'en' : orderedLangs.first;
      selectedLanguage.value = defaultLang;
      parseCuesForLanguage(defaultLang, subs[defaultLang]);
    }
    selectedVideo.refresh();
    initVideoPlayer(video);
  }

  void listenToLanguageRequests(String videoId) {
    requestsSubscription?.cancel();
    isLoadingRequests.value = true;
    requestsSubscription = firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('language_requests')
        .snapshots()
        .listen(
          (snapshot) {
            final reqs = snapshot.docs
                .map((doc) => LanguageRequest.fromMap(doc.data(), doc.id))
                .toList();
            reqs.sort((a, b) {
              final countCompare = b.count.compareTo(a.count);
              if (countCompare != 0) return countCompare;
              return a.language.compareTo(b.language);
            });
            languageRequests.value = reqs;
            isLoadingRequests.value = false;
          },
          onError: (e) {
            logger.error(
              'Error listening to language requests',
              error: e,
              tag: SubtitlesControllerBase.subtitlesTag,
            );
            isLoadingRequests.value = false;
          },
        );
  }

  void toggleRequestsPanel() {
    showRequestsPanel.value = !showRequestsPanel.value;
  }

  void switchLanguage(String langCode) {
    if (!availableLanguages.contains(langCode)) return;
    selectedLanguage.value = langCode;
    hasUnsavedChanges.value = false;
    final subs = selectedVideo.value?.mediaSubtitles ?? {};
    if (subs.containsKey(langCode)) {
      parseCuesForLanguage(langCode, subs[langCode]);
    } else {
      currentCues.clear();
    }
  }
}
