import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
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
      unawaited(refreshSpendableBalance());
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
      unawaited(refreshSpendableBalance());
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

      // Preserve or auto-select a video on desktop
      if (selectedVideo.value != null) {
        final updatedVideo = loadedVideos.firstWhereOrNull(
          (v) => v.id == selectedVideo.value!.id,
        );
        if (updatedVideo != null) {
          selectedVideo.value = updatedVideo;
        } else {
          selectVideo(null);
        }
      } else if (loadedVideos.isNotEmpty) {
        // Auto-select first video only on wide desktop displays
        final isDesktop =
            (Get.context != null ? Get.width : 800) >= 1024;
        if (isDesktop) {
          selectVideo(loadedVideos.first);
        }
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

  String? _inFlightSelectingVideoId;

  Future<void> selectVideo(Video? video) async {
    if (video == null) {
      _inFlightSelectingVideoId = null;
      selectedVideo.value = null;
      hasUnsavedChanges.value = false;
      requestsSubscription?.cancel();
      aiJobSubscription?.cancel();
      isGeneratingAI.value = false;
      disposeVideoPlayer();
      availableLanguages.clear();
      selectedLanguage.value = '';
      currentCues.clear();
      languageRequests.clear();
      return;
    }

    if (_inFlightSelectingVideoId == video.id ||
        (selectedVideo.value?.id == video.id &&
         videoPlayerController != null &&
         availableLanguages.isNotEmpty)) {
      return;
    }
    _inFlightSelectingVideoId = video.id;
    selectedVideo.value = video;
    hasUnsavedChanges.value = false;
    requestsSubscription?.cancel();

    logger.info('Selected video for subtitles: ${video.title}', tag: SubtitlesControllerBase.subtitlesTag);

    unawaited(checkAndResumeAIJob(video.id));
    unawaited(refreshSpendableBalance());
    listenToLanguageRequests(video.id);

    // Parse existing mediaSubtitles map
    final subs = Map<String, String>.from(video.mediaSubtitles);

    // If local mediaSubtitles is empty, await localization subcollection; otherwise load in parallel
    if (subs.isEmpty) {
      final loc = await VideoMediaService().getLocalization(video.id);
      if (loc.subtitles.isNotEmpty) {
        subs.addAll(loc.subtitles);
        selectedVideo.value = video.copyWith(mediaSubtitles: subs);
      }
    } else {
      unawaited(VideoMediaService().getLocalization(video.id).then((loc) {
        if (loc.subtitles.isNotEmpty && selectedVideo.value?.id == video.id) {
          final mergedSubs = Map<String, String>.from(selectedVideo.value!.mediaSubtitles)..addAll(loc.subtitles);
          selectedVideo.value = selectedVideo.value!.copyWith(mediaSubtitles: mergedSubs);
          for (final lang in loc.subtitles.keys) {
            final code = normalizeLanguageCode(lang);
            if (!availableLanguages.contains(code)) {
              availableLanguages.add(code);
            }
          }
        }
      }));
    }

    final orderedLangs = <String>[];

    // Always add primary video language first if defined, then 'en'
    final primaryLang = normalizeLanguageCode(video.language);
    orderedLangs.add(primaryLang);
    if (!orderedLangs.contains('en')) {
      orderedLangs.add('en');
    }

    // Add all languages that have existing subtitle URLs
    for (final lang in subs.keys) {
      final code = normalizeLanguageCode(lang);
      if (!orderedLangs.contains(code)) {
        orderedLangs.add(code);
      }
    }

    // Add pending translation languages from video.languages using comprehensive supportedLanguages
    for (final langName in video.languages) {
      final code = normalizeLanguageCode(langName);
      if (!orderedLangs.contains(code)) {
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
      final subUrl = subs[defaultLang] ??
          subs[video.language] ??
          (video.transcriptionUrl.isNotEmpty ? video.transcriptionUrl : null);
      parseCuesForLanguage(defaultLang, subUrl);
    }
    selectedVideo.refresh();
    initVideoPlayer(video);
    _inFlightSelectingVideoId = null;
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
    final normCode = normalizeLanguageCode(langCode);
    if (!availableLanguages.contains(langCode) &&
        !availableLanguages.contains(normCode) &&
        !configuredLanguages.contains(normCode)) {
      return;
    }
    if (!availableLanguages.contains(langCode)) {
      if (availableLanguages.contains(normCode)) {
        selectedLanguage.value = normCode;
      } else {
        availableLanguages.add(normCode);
        selectedLanguage.value = normCode;
      }
    } else {
      selectedLanguage.value = langCode;
    }
    hasUnsavedChanges.value = false;

    final targetLang = selectedLanguage.value;
    final video = selectedVideo.value;
    final subs = video?.mediaSubtitles ?? {};

    // 1. Resolve subtitle URL from mediaSubtitles (exact or normalized match)
    String? subUrl = subs[targetLang] ?? subs[normCode];
    if (subUrl == null || subUrl.isEmpty) {
      for (final entry in subs.entries) {
        if (normalizeLanguageCode(entry.key) == normCode) {
          subUrl = entry.value;
          break;
        }
      }
    }

    // 2. Auto-fallback to video.transcriptionUrl for the base/original language
    final isBaseLang = video != null &&
        (normCode == normalizeLanguageCode(video.language) ||
         normCode == 'en' ||
         targetLang == video.language);

    if ((subUrl == null || subUrl.isEmpty) && isBaseLang && video != null) {
      if (video.transcriptionUrl.isNotEmpty) {
        subUrl = video.transcriptionUrl;
      }
    }

    if (subUrl != null && subUrl.isNotEmpty) {
      parseCuesForLanguage(targetLang, subUrl);
    } else {
      parseCuesForLanguage(targetLang, null);
    }
  }
}
