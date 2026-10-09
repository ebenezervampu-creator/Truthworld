import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Professional Chapters Management Controller
class ChaptersController extends BaseController with ContentValidationMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _tag = 'ChaptersController';

  // Active channel context
  final RxString channelId = ''.obs;

  // Video list state
  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> filteredVideos = <Video>[].obs;
  final RxString searchQuery = ''.obs;
  final RxString filterType = 'all'.obs; // 'all', 'has_chapters', 'no_chapters'
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  StreamSubscription<QuerySnapshot>? _channelVideosSubscription;
  final Map<String, Video> _ownerVideosMap = {};
  final Map<String, Video> _channelVideosMap = {};

  // Selected video and chapters editing state
  final selectedVideo = Rxn<Video>();
  final RxList<VideoChapter> currentChapters = <VideoChapter>[].obs;
  final RxBool autoChaptersEnabled = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool isAnalyzing = false.obs;
  final RxBool hasUnsavedChanges = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeContext();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    _channelVideosSubscription?.cancel();
    super.onClose();
  }

  Future<void> _initializeContext() async {
    try {
      setViewState(ViewState.loading);
      final currentUser = _auth.currentUser;
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
        final userDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          channelId.value = userDoc.data()!['channelId'] ?? currentUser.uid;
        } else {
          channelId.value = currentUser.uid;
        }
      }

      _listenToChannelVideos();
    } catch (e, stack) {
      logger.error(
        'Failed to initialize chapters context',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      setError('Initialization failed');
    }
  }

  void setChannelContext(String id) {
    if (id.isNotEmpty && channelId.value != id) {
      channelId.value = id;
      _listenToChannelVideos();
    }
  }

  void _listenToChannelVideos() {
    final currentUser = _auth.currentUser;
    final targetOwnerId = currentUser?.uid ?? '';
    final targetChannelId = channelId.value;

    if (targetOwnerId.isEmpty && targetChannelId.isEmpty) {
      setError('User not authenticated and Channel ID is missing');
      return;
    }

    _videosSubscription?.cancel();
    _channelVideosSubscription?.cancel();
    _ownerVideosMap.clear();
    _channelVideosMap.clear();

    void updateVideosList() {
      final combinedMap = <String, Video>{
        ..._ownerVideosMap,
        ..._channelVideosMap,
      };
      final loadedVideos = combinedMap.values.toList();
      // Client-side sort to ensure consistent chronological ordering
      loadedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      videos.value = loadedVideos;
      _applyFilters();

      setViewState(
        loadedVideos.isEmpty ? ViewState.empty : ViewState.success,
      );

      // Preserve or auto-select a video
      if (selectedVideo.value != null) {
        final updatedVideo = loadedVideos.firstWhereOrNull(
          (v) => v.id == selectedVideo.value!.id,
        );
        if (updatedVideo != null) {
          selectedVideo.value = updatedVideo;
        } else {
          selectVideo(
            loadedVideos.isNotEmpty ? loadedVideos.first : null,
          );
        }
      } else if (loadedVideos.isNotEmpty) {
        selectVideo(loadedVideos.first);
      }
    }

    if (targetOwnerId.isNotEmpty) {
      _videosSubscription = _firestore
          .collection(FirestoreCollections.videos)
          .where('ownerId', isEqualTo: targetOwnerId)
          .snapshots()
          .listen(
            (snapshot) {
              _ownerVideosMap.clear();
              for (final doc in snapshot.docs) {
                final video = Video.fromDocumentSnapshot(doc);
                _ownerVideosMap[video.id] = video;
              }
              updateVideosList();
            },
            onError: (e) {
              logger.error('Error streaming owner videos', error: e, tag: _tag);
              if (_channelVideosMap.isEmpty) {
                setError('Failed to fetch videos');
              }
            },
          );
    }

    if (targetChannelId.isNotEmpty && targetChannelId != targetOwnerId) {
      _channelVideosSubscription = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: targetChannelId)
          .snapshots()
          .listen(
            (snapshot) {
              _channelVideosMap.clear();
              for (final doc in snapshot.docs) {
                final video = Video.fromDocumentSnapshot(doc);
                _channelVideosMap[video.id] = video;
              }
              updateVideosList();
            },
            onError: (e) {
              logger.error(
                'Error streaming channel videos',
                error: e,
                tag: _tag,
              );
            },
          );
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void setFilterType(String type) {
    filterType.value = type;
    _applyFilters();
  }

  void _applyFilters() {
    var list = <Video>[...videos];
    final q = searchQuery.value.toLowerCase().trim();

    if (q.isNotEmpty) {
      list = list.where((v) {
        return v.title.toLowerCase().contains(q) ||
            v.description.toLowerCase().contains(q) ||
            v.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    if (filterType.value == 'has_chapters') {
      list = list.where((v) => v.chapters.isNotEmpty).toList();
    } else if (filterType.value == 'no_chapters') {
      list = list.where((v) => v.chapters.isEmpty).toList();
    }

    filteredVideos.value = list;
  }

  Future<void> selectVideo(Video? video) async {
    selectedVideo.value = video;
    hasUnsavedChanges.value = false;
    if (video == null) {
      currentChapters.clear();
      return;
    }

    autoChaptersEnabled.value = video.autoChaptersEnabled;
    logger.info('Selected video for chapters: ${video.title}', tag: _tag);

    // Lazy-load streaming from subcollection first (contains chapters)
    await VideoMediaService().getStreaming(video.id);

    currentChapters.value = List<VideoChapter>.from(video.chapters);
    // Sort chapters by startTime just in case they aren't ordered in database
    currentChapters.sort((a, b) => a.startTime.compareTo(b.startTime));
    selectedVideo.refresh();
  }

  /// Toggles automatic chapters on/off following YouTube Studio rules:
  /// - When OFF: AI auto-chapters are suppressed (unless manual description/custom chapters exist).
  /// - When ON: AI auto-chapters are used as fallback if no manual chapters exist.
  Future<void> toggleAutoChapters(bool enabled) async {
    final video = selectedVideo.value;
    if (video == null) return;

    autoChaptersEnabled.value = enabled;
    try {
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .set({
            'autoChaptersEnabled': enabled,
            'aiFeatures': {'autoChapters': enabled},
          }, SetOptions(merge: true));

      final updatedVideo = video.copyWith(autoChaptersEnabled: enabled);
      selectedVideo.value = updatedVideo;

      final idx = videos.indexWhere((v) => v.id == video.id);
      if (idx != -1) {
        videos[idx] = updatedVideo;
        _applyFilters();
      }

      // If auto-chapters is disabled and no manual description timestamps or explicit chapters exist:
      final descChapters = VideoChapterParser.extractDescriptionChapters(
        video.description,
      );
      final streaming = await VideoMediaService().getStreaming(video.id);

      if (!enabled && descChapters.isEmpty && streaming.chapters.isEmpty) {
        currentChapters.clear();
        VideoMediaService.streamingCache[video.id] = VideoMediaStreaming(
          originalUrl: video.originalUrl,
          hlsUrl: video.hlsUrl,
          dashUrl: video.dashUrl,
          adaptiveResolutions: video.adaptiveResolutions,
          thumbnailVariants: video.thumbnailVariants,
          animatedPreviewUrl: video.animatedPreviewUrl,
        );
      } else if (enabled && currentChapters.isEmpty) {
        currentChapters.value = List<VideoChapter>.from(updatedVideo.chapters);
      }

      selectedVideo.refresh();
      showSuccess(
        enabled
            ? 'Automatic chapters enabled (when available).'
            : 'Automatic chapters turned off. Auto-chapters are hidden unless you provide description timestamps.',
      );
    } catch (e, stack) {
      logger.error(
        'Failed to toggle auto chapters',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      showError('Failed to update automatic chapters setting');
    }
  }

  bool addChapter(String title, Duration startTime) {
    if (startTime < Duration.zero) {
      showError('Chapter timestamp cannot be negative.');
      return false;
    }

    final video = selectedVideo.value;
    if (video != null && video.durationValue > Duration.zero) {
      if (startTime >= video.durationValue) {
        showError(
          'Chapter timestamp (${VideoDurationUtils.formatDuration(startTime)}) cannot exceed video duration (${video.duration}).',
        );
        return false;
      }
    }

    final newChapter = VideoChapter(title: title, startTime: startTime);

    // Check if start time is already in use
    final duplicateIndex = currentChapters.indexWhere(
      (c) => c.startTime == startTime,
    );
    if (duplicateIndex != -1) {
      showWarning(
        'A chapter already exists at this timestamp. Replaced existing chapter.',
      );
      currentChapters[duplicateIndex] = newChapter;
    } else {
      currentChapters.add(newChapter);
    }

    currentChapters.sort((a, b) => a.startTime.compareTo(b.startTime));
    hasUnsavedChanges.value = true;
    return true;
  }

  bool updateChapter(int index, {String? title, Duration? startTime}) {
    if (index < 0 || index >= currentChapters.length) return false;

    if (startTime != null) {
      if (startTime < Duration.zero) {
        showError('Chapter timestamp cannot be negative.');
        return false;
      }

      final video = selectedVideo.value;
      if (video != null && video.durationValue > Duration.zero) {
        if (startTime >= video.durationValue) {
          showError(
            'Chapter timestamp (${VideoDurationUtils.formatDuration(startTime)}) cannot exceed video duration (${video.duration}).',
          );
          return false;
        }
      }
    }

    final oldChapter = currentChapters[index];
    final updated = VideoChapter(
      title: title ?? oldChapter.title,
      startTime: startTime ?? oldChapter.startTime,
      thumbnailUrl: oldChapter.thumbnailUrl,
    );

    currentChapters[index] = updated;
    currentChapters.sort((a, b) => a.startTime.compareTo(b.startTime));
    hasUnsavedChanges.value = true;
    return true;
  }

  void deleteChapter(int index) {
    if (index < 0 || index >= currentChapters.length) return;
    currentChapters.removeAt(index);
    hasUnsavedChanges.value = true;
  }

  void shiftChapterTiming(int index, int shiftMilliseconds) {
    if (index < 0 || index >= currentChapters.length) return;
    final video = selectedVideo.value;
    final chapter = currentChapters[index];
    var newMs = chapter.startTime.inMilliseconds + shiftMilliseconds;
    if (newMs < 0) newMs = 0;

    if (video != null && video.durationValue > Duration.zero) {
      if (newMs >= video.durationValue.inMilliseconds) {
        showWarning(
          'Chapter cannot be shifted past video duration (${video.duration}).',
        );
        return;
      }
    }

    updateChapter(index, startTime: Duration(milliseconds: newMs));
  }

  Future<void> saveChapters() async {
    final video = selectedVideo.value;
    if (video == null) return;

    final videoDuration = video.durationValue;
    for (var i = 0; i < currentChapters.length; i++) {
      final ch = currentChapters[i];
      final titleVal = await validateContent(
        ch.title,
        fieldName: 'Chapter ${i + 1} Title',
      );
      if (!titleVal.isValid) {
        showWarning(titleVal.message);
        return;
      }

      if (videoDuration > Duration.zero && ch.startTime >= videoDuration) {
        showError(
          'Chapter "${ch.title}" at ${ch.formattedStartTime} cannot exceed video duration (${video.duration}). Please fix before saving.',
        );
        return;
      }
    }

    isSaving.value = true;
    try {
      final chapterMaps = currentChapters.map((c) => c.toMap()).toList();

      // Save to media/streaming subcollection
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('streaming')
          .set({
            'chapters': chapterMaps,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update static cache to reflect changes immediately
      VideoMediaService.streamingCache[video.id] = VideoMediaStreaming(
        originalUrl: video.originalUrl,
        hlsUrl: video.hlsUrl,
        dashUrl: video.dashUrl,
        adaptiveResolutions: video.adaptiveResolutions,
        thumbnailVariants: video.thumbnailVariants,
        animatedPreviewUrl: video.animatedPreviewUrl,
        chapters: currentChapters,
      );

      // Force reactive notification
      selectedVideo.refresh();

      hasUnsavedChanges.value = false;
      showSuccess('Video chapters saved successfully!');
    } catch (e, stack) {
      logger.error(
        'Failed to save chapters',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      handleError('Failed to save chapters');
    } finally {
      isSaving.value = false;
    }
  }

  void importFromTimestampFormat(String text) {
    final lines = text.split('\n');
    final parsedChapters = <VideoChapter>[];
    // Regular expression matching HH:MM:SS or MM:SS
    final regex = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})');

    final video = selectedVideo.value;
    final videoDuration = video?.durationValue ?? Duration.zero;
    var skippedExceedingCount = 0;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final match = regex.firstMatch(line);
      if (match != null) {
        var hours = 0;
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        if (match.group(1) != null) {
          hours = int.parse(match.group(1)!);
        }
        final duration = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );

        if (videoDuration > Duration.zero && duration >= videoDuration) {
          skippedExceedingCount++;
          continue;
        }

        // Extract title (everything remaining in the line)
        var title = line.replaceFirst(match.group(0)!, '').trim();
        // Remove typical separator chars like dashes, brackets, colons
        title = title.replaceAll(RegExp(r'^[\s\-–—:;\[\]\(\)]+'), '').trim();
        if (title.isEmpty) {
          title = 'Chapter ${parsedChapters.length + 1}';
        }
        parsedChapters.add(VideoChapter(title: title, startTime: duration));
      }
    }

    if (parsedChapters.isNotEmpty) {
      parsedChapters.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Merge into current chapters, preventing duplicate start times
      final existingMap = {for (final c in currentChapters) c.startTime: c};
      for (final pc in parsedChapters) {
        existingMap[pc.startTime] = pc;
      }

      currentChapters.value = existingMap.values.toList();
      currentChapters.sort((a, b) => a.startTime.compareTo(b.startTime));
      hasUnsavedChanges.value = true;
      if (skippedExceedingCount > 0) {
        showWarning(
          'Imported ${parsedChapters.length} chapter(s). Skipped $skippedExceedingCount timestamp(s) exceeding video duration (${video!.duration}).',
        );
      } else {
        showSuccess(
          'Successfully parsed and imported ${parsedChapters.length} chapters!',
        );
      }
    } else if (skippedExceedingCount > 0) {
      showError(
        'All found timestamps exceeded video duration (${video!.duration}).',
      );
    } else {
      showError(
        'Could not find any valid timestamps (e.g. 01:23) in the pasted text.',
      );
    }
  }

  void exportToClipboard() {
    if (currentChapters.isEmpty) {
      showError('No chapters available to export.');
      return;
    }
    final buffer = StringBuffer();
    for (final chapter in currentChapters) {
      buffer.writeln('${chapter.formattedStartTime} ${chapter.title}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showSuccess('Formatted timestamps copied to Clipboard!');
  }

  Future<void> autoDetectChapters() async {
    final video = selectedVideo.value;
    if (video == null) return;

    isAnalyzing.value = true;
    try {
      final description = video.description;
      final parsedChapters = VideoChapterParser.extractDescriptionChapters(
        description,
        maxDuration: video.durationValue,
      );

      if (parsedChapters.isNotEmpty) {
        final existingMap = {for (final c in currentChapters) c.startTime: c};
        for (final pc in parsedChapters) {
          existingMap[pc.startTime] = pc;
        }

        currentChapters.value = existingMap.values.toList();
        currentChapters.sort((a, b) => a.startTime.compareTo(b.startTime));
        hasUnsavedChanges.value = true;
        showSuccess(
          'Successfully imported ${parsedChapters.length} chapters matching YouTube standards from description!',
        );
      } else {
        // Detailed feedback on YouTube description chapter requirements
        final lines = description.split('\n');
        final rawMatches = lines.where(
          (l) => RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})').hasMatch(l),
        );
        if (rawMatches.isEmpty) {
          showError(
            'No timestamped chapters found in description. Format: 00:00 Intro, 01:30 Topic.',
          );
        } else if (!description.contains(RegExp(r'(?:^|\n)\s*0?0:00'))) {
          showWarning(
            'Timestamps found, but first chapter must start at 0:00 (YouTube standard).',
          );
        } else if (rawMatches.length < 3) {
          showWarning(
            'Found ${rawMatches.length} timestamp(s). At least 3 chapters are required (YouTube standard).',
          );
        } else {
          showWarning(
            'Each chapter must be at least 10 seconds apart (YouTube standard).',
          );
        }
      }
    } catch (e, s) {
      logger.error(
        'Failed to auto-detect chapters',
        error: e,
        stackTrace: s,
        tag: _tag,
      );
      showError('Unable to detect chapters from video details.');
    } finally {
      isAnalyzing.value = false;
    }
  }

  /// Reorders a chapter in the list with animated drag-and-drop feedback and sets unsaved changes flag.
  void reorderChapter(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = currentChapters.removeAt(oldIndex);
    currentChapters.insert(newIndex, item);
    hasUnsavedChanges.value = true;
  }
}
