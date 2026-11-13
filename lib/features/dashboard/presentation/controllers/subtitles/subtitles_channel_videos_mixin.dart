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

    final primaryLang = normalizeLanguageCode(video.language.isNotEmpty ? video.language : 'en');

    // If local mediaSubtitles is empty, await localization subcollection; otherwise load in parallel
    if (subs.isEmpty) {
      final loc = await VideoMediaService().getLocalization(video.id);
      if (loc.subtitles.isNotEmpty) {
        subs.addAll(loc.subtitles);
      }
    } else {
      unawaited(VideoMediaService().getLocalization(video.id).then((loc) {
        if (loc.subtitles.isNotEmpty && selectedVideo.value?.id == video.id) {
          final mergedSubs = Map<String, String>.from(selectedVideo.value!.mediaSubtitles)..addAll(loc.subtitles);
          if (!mergedSubs.containsKey(primaryLang) && !mergedSubs.containsKey(video.language)) {
            final origUrl = resolveSubtitleUrlForLanguage(video, primaryLang);
            if (origUrl != null && origUrl.isNotEmpty) {
              mergedSubs[primaryLang] = origUrl;
            }
          }
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

    // Ensure primary language subtitle track is populated if ready
    if (!subs.containsKey(primaryLang) && !subs.containsKey(video.language)) {
      final origUrl = resolveSubtitleUrlForLanguage(video, primaryLang);
      if (origUrl != null && origUrl.isNotEmpty) {
        subs[primaryLang] = origUrl;
      }
    }
    selectedVideo.value = video.copyWith(mediaSubtitles: subs);

    final orderedLangs = getOrderedLanguagesForVideo(video, subs);

    if (orderedLangs.isEmpty) {
      availableLanguages.value = ['en'];
      selectedLanguage.value = 'en';
      currentCues.clear();
    } else {
      availableLanguages.value = orderedLangs;
      final defaultLang = determineDefaultLanguage(video, subs, orderedLangs);
      selectedLanguage.value = defaultLang;
      final subUrl = resolveSubtitleUrlForLanguage(video, defaultLang);
      parseCuesForLanguage(defaultLang, subUrl);
    }
    selectedVideo.refresh();
    initVideoPlayer(video);
    _inFlightSelectingVideoId = null;
  }

  /// Generates the candidate ordered languages list for a video based on native language, subtitles, and localization.
  List<String> getOrderedLanguagesForVideo(
    Video video,
    Map<String, String> subs,
  ) {
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

    return orderedLangs;
  }

  /// Determines the optimal initial language track for a video:
  /// 1. Prefer original video language if it has subtitles or transcription
  /// 2. Else prefer first language in mediaSubtitles that has an existing track
  /// 3. Else prefer primaryLang if non-empty
  /// 4. Else prefer 'en' if present in orderedLangs
  /// 5. Fallback to orderedLangs.first
  String determineDefaultLanguage(
    Video video,
    Map<String, String> subs,
    List<String> orderedLangs,
  ) {
    if (orderedLangs.isEmpty) return 'en';

    final primaryLang = normalizeLanguageCode(video.language);
    var defaultLang = orderedLangs.first;
    final hasPrimarySubs = primaryLang.isNotEmpty &&
        (subs.containsKey(primaryLang) ||
            subs.containsKey(video.language) ||
            subs.keys.any((k) => normalizeLanguageCode(k) == primaryLang));
    final hasPrimaryTranscript =
        primaryLang.isNotEmpty && video.transcriptionUrl.isNotEmpty;

    if (primaryLang.isNotEmpty && (hasPrimarySubs || hasPrimaryTranscript)) {
      defaultLang = primaryLang;
    } else if (subs.isNotEmpty) {
      final firstSubKey = subs.keys.firstWhere(
        (k) => subs[k]?.isNotEmpty ?? false,
        orElse: () => '',
      );
      if (firstSubKey.isNotEmpty) {
        defaultLang = normalizeLanguageCode(firstSubKey);
      }
    } else if (primaryLang.isNotEmpty && orderedLangs.contains(primaryLang)) {
      defaultLang = primaryLang;
    } else if (orderedLangs.contains('en')) {
      defaultLang = 'en';
    }

    return defaultLang;
  }

  /// Resolves the subtitle URL for the specified language track.
  /// Falls back to the video's original transcriptionUrl ONLY if this track is the video's original spoken language.
  @override
  String? resolveSubtitleUrlForLanguage(Video video, String langCode) {
    final normCode = normalizeLanguageCode(langCode);
    final subs = video.mediaSubtitles;

    // 1. Direct or normalized match in mediaSubtitles
    var subUrl = subs[langCode] ?? subs[normCode];
    if (subUrl == null || subUrl.isEmpty) {
      for (final entry in subs.entries) {
        if (normalizeLanguageCode(entry.key) == normCode &&
            entry.value.isNotEmpty) {
          subUrl = entry.value;
          break;
        }
      }
    }

    // 2. Base/original language fallback: only if this track matches the video's native language
    if (subUrl == null || subUrl.isEmpty) {
      final videoLangCode = normalizeLanguageCode(
          video.language.isNotEmpty ? video.language : 'en');
      final isOriginalLang = normCode == videoLangCode ||
          langCode == video.language ||
          (videoLangCode == 'en' && normCode == 'en');
      if (isOriginalLang && video.transcriptionUrl.isNotEmpty) {
        subUrl = video.transcriptionUrl;
      }
    }

    // 3. In-memory localization cache check
    if (subUrl == null || subUrl.isEmpty) {
      final locSubs = VideoMediaService.localizationCache[video.id]?.subtitles ?? const {};
      subUrl = locSubs[langCode] ?? locSubs[normCode];
      if (subUrl == null || subUrl.isEmpty) {
        for (final entry in locSubs.entries) {
          if (normalizeLanguageCode(entry.key) == normCode && entry.value.isNotEmpty) {
            subUrl = entry.value;
            break;
          }
        }
      }
    }

    return subUrl;
  }

  void listenToLanguageRequests(String videoId) {
    requestsSubscription?.cancel();
    isLoadingRequests.value = true;
    try {
      requestsSubscription = firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('language_requests')
          .snapshots()
          .handleError((e) {
            logger.info(
              'Language requests stream subscription unavailable: $e',
              tag: SubtitlesControllerBase.subtitlesTag,
            );
            isLoadingRequests.value = false;
          })
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
              logger.info(
                'Error listening to language requests: $e',
                tag: SubtitlesControllerBase.subtitlesTag,
              );
              isLoadingRequests.value = false;
            },
            cancelOnError: false,
          );
    } catch (e) {
      logger.info(
        'Error initiating language requests listener: $e',
        tag: SubtitlesControllerBase.subtitlesTag,
      );
      isLoadingRequests.value = false;
    }
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
    final subUrl = video != null
        ? resolveSubtitleUrlForLanguage(video, targetLang)
        : null;

    parseCuesForLanguage(targetLang, subUrl);
  }

  /// Updates the original spoken language of the selected video.
  Future<void> updateOriginalVideoLanguage(String newLangCode) async {
    final v = selectedVideo.value;
    if (v == null || newLangCode.isEmpty) return;
    try {
      await firestore
          .collection(FirestoreCollections.videos)
          .doc(v.id)
          .update({'language': newLangCode});
      final updatedVideo = v.copyWith(language: newLangCode);
      selectedVideo.value = updatedVideo;
      final normCode = normalizeLanguageCode(newLangCode);
      if (!availableLanguages.contains(normCode) && !availableLanguages.contains(newLangCode)) {
        availableLanguages.insert(0, normCode);
      }
      selectedVideo.refresh();
      showSuccess('Original video language updated to ${getLanguageName(newLangCode)}.');
    } catch (e) {
      logger.error('Failed updating original video language', error: e, tag: 'SubtitlesController');
      showError('Unable to update video language. Please try again.');
    }
  }
}
