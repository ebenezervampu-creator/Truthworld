import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Sub-controller responsible for fetching, downloading, parsing, and caching
/// video transcripts, subtitle segments, and AI moderation summaries.
class VideoTranscriptController extends BaseController {
  final RxBool isTranscriptVisible = false.obs;
  final RxList<SubtitleSegment> transcriptSegments = <SubtitleSegment>[].obs;
  final RxBool isLoadingTranscript = false.obs;

  final RxBool isSummaryVisible = false.obs;
  final RxString moderationSummary = ''.obs;
  final RxBool isLoadingSummary = false.obs;

  final ScrollController transcriptScrollController = ScrollController();
  final RxInt activeSegmentIndex = (-1).obs;
  final RxBool autoScrollEnabled = true.obs;
  DateTime _lastAutoScroll = DateTime(2000);

  void toggleTranscriptVisibility() {
    isTranscriptVisible.value = !isTranscriptVisible.value;
  }

  void toggleSummaryVisibility() {
    isSummaryVisible.value = !isSummaryVisible.value;
  }

  void updateActiveSegment(SubtitleSegment? seg) {
    if (seg == null) {
      if (activeSegmentIndex.value != -1) activeSegmentIndex.value = -1;
      return;
    }
    final idx = transcriptSegments.indexOf(seg);
    if (idx != -1 && idx != activeSegmentIndex.value) {
      activeSegmentIndex.value = idx;
      if (autoScrollEnabled.value && isTranscriptVisible.value) {
        _smoothScrollToIndex(idx);
      }
    }
  }

  void _smoothScrollToIndex(int index) {
    final now = DateTime.now();
    if (now.difference(_lastAutoScroll).inMilliseconds < 150) return;
    _lastAutoScroll = now;

    if (transcriptScrollController.hasClients) {
      final target = (index * 52.0 - 120.0).clamp(
        0.0,
        transcriptScrollController.position.maxScrollExtent,
      );
      transcriptScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Proactively finds, downloads, and parses the transcript/subtitles for [video].
  Future<void> loadTranscriptForVideo(Video video, {String? defaultSubtitleUrl}) async {
    final playerCtrl = TowerPlayerController.getForTagOrActive(video.id);

    // 0. Fast-path memory cache checks
    if (transcriptSegments.isNotEmpty) {
      if (playerCtrl != null && playerCtrl.subtitleSegments.isEmpty) {
        playerCtrl.subtitleSegments.assignAll(transcriptSegments);
      }
      return;
    }
    if (playerCtrl != null && playerCtrl.subtitleSegments.isNotEmpty) {
      transcriptSegments.assignAll(playerCtrl.subtitleSegments);
      return;
    }

    if (isLoadingTranscript.value) return;

    isLoadingTranscript.value = true;
    playerCtrl?.isLoadingSubtitles.value = true;
    try {
      // 1. Check existing availableSubtitles or mediaSubtitles
      var candidateUrl = video.mediaSubtitles['en'] ??
          (video.mediaSubtitles.isNotEmpty ? video.mediaSubtitles.values.first : null) ??
          (video.transcriptionUrl.isNotEmpty ? video.transcriptionUrl : null) ??
          defaultSubtitleUrl;

      // 2. If null, fetch from localization subcollection
      if (candidateUrl == null || candidateUrl.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        if (loc.subtitles.isNotEmpty) {
          candidateUrl = loc.subtitles['en'] ?? loc.subtitles.values.first;
        }
      }

      // 3. If still null, check root video document in Firestore
      if (candidateUrl == null || candidateUrl.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .get();
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final media = data['media'] as Map<String, dynamic>?;
          candidateUrl = (media?['transcriptionUrl'] as String?) ??
              (data['transcriptionUrl'] as String?) ??
              (data['transcriptUrl'] as String?);
          if (candidateUrl == null || candidateUrl.isEmpty) {
            final subs = (media?['subtitles'] ?? data['subtitles']) as Map?;
            if (subs != null && subs.isNotEmpty) {
              candidateUrl = subs['en']?.toString() ?? subs.values.first?.toString();
            }
          }
        }
      }

      // 4. If candidate URL found, fetch and parse
      if (candidateUrl != null && candidateUrl.isNotEmpty) {
        if (playerCtrl != null) {
          await playerCtrl.fetchAndParseSubtitles(candidateUrl);
          if (playerCtrl.subtitleSegments.isNotEmpty) {
            transcriptSegments.assignAll(playerCtrl.subtitleSegments);
            return;
          }
        }
        final segs = await downloadAndParseTranscript(candidateUrl);
        if (segs.isNotEmpty) {
          transcriptSegments.assignAll(segs);
          playerCtrl?.subtitleSegments.assignAll(segs);
          return;
        }
      }

      // 5. Direct probe into Firebase Storage for pipeline-generated transcripts
      final storage = FirebaseStorage.instance;
      final probePaths = [
        'transcripts/${video.id}/full.json',
        'subtitles/${video.id}/en.vtt',
        'subtitles/${video.id}/en.srt',
        'subtitles/${video.id}/transcript.json',
        'subtitles/${video.id}/transcription.json',
        'transcripts/${video.id}.json',
        'transcripts/${video.id}.vtt',
        'transcripts/${video.id}.srt',
        'videos/${video.id}/transcript.json',
        'videos/${video.id}/transcription.json',
      ];

      for (final p in probePaths) {
        try {
          final data = await storage.ref(p).getData();
          if (data != null && data.isNotEmpty) {
            final content = utf8.decode(data, allowMalformed: true);
            final segs = await parseTranscriptContent(content);
            if (segs.isNotEmpty) {
              transcriptSegments.assignAll(segs);
              playerCtrl?.subtitleSegments.assignAll(segs);
              debugPrint('[VideoTranscriptController] ✅ Found transcript via storage probe: $p');
              return;
            }
          }
        } catch (e, stackTrace) {
          // Probe not found, log low-level diagnostic and continue to next probe
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'VideoTranscriptController.loadTranscript.probe',
          );
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoTranscriptController.loadTranscript',
      );
    } finally {
      isLoadingTranscript.value = false;
      playerCtrl?.isLoadingSubtitles.value = false;
    }
  }

  Future<List<SubtitleSegment>> downloadAndParseTranscript(String url) async {
    try {
      String? content;
      try {
        final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
        final response = await AppHttpClient.get(Uri.parse(resolvedUrl));
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoTranscriptController.downloadHttpTranscript',
        );
      }

      if (content == null || content.isEmpty) {
        Uint8List? data;
        if (url.startsWith('gs://') ||
            url.startsWith('https://storage.googleapis.com/') ||
            url.startsWith('https://firebasestorage.googleapis.com/')) {
          data = await FirebaseStorage.instance.refFromURL(url).getData();
        } else if (url.startsWith('subtitles/') || url.startsWith('transcripts/') || url.startsWith('videos/')) {
          data = await FirebaseStorage.instance.ref(url).getData();
        }
        if (data != null && data.isNotEmpty) {
          content = utf8.decode(data, allowMalformed: true);
        }
      }

      if (content != null && content.isNotEmpty) {
        return await parseTranscriptContent(content);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoTranscriptController.downloadAndParseTranscript',
      );
    }
    return [];
  }

  Future<List<SubtitleSegment>> parseTranscriptContent(String content) {
    return IsolateComputeUtils.parseSubtitlesAsync(content);
  }

  /// Fetches the AI Summary from moderation.summary in the video document or credibility cache
  Future<void> fetchSummary(Video video) async {
    if (moderationSummary.value.isNotEmpty) return;
    isLoadingSummary.value = true;
    try {
      // 1. Direct check on video.moderationSummary from Video model
      if (video.moderationSummary.isNotEmpty) {
        moderationSummary.value = video.moderationSummary;
        isLoadingSummary.value = false;
        return;
      }

      // 2. Check VideoMediaService credibility cache
      final credibility = await VideoMediaService().getCredibility(video.id);
      if (credibility.summary.isNotEmpty) {
        moderationSummary.value = credibility.summary;
        isLoadingSummary.value = false;
        return;
      }

      // 3. Fallback: Fetch directly from videos/{videoId} document in Firestore
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final mod = data['moderation'] as Map<String, dynamic>?;
        final summary = (mod != null && mod['summary'] != null && (mod['summary'] as String).isNotEmpty)
            ? (mod['summary'] as String)
            : ((data['summary'] as String?)?.isNotEmpty == true
                ? (data['summary'] as String)
                : ((mod != null && mod['explanation'] != null)
                    ? (mod['explanation'] as String)
                    : (data['description'] as String? ?? '')));
        if (summary.isNotEmpty) {
          moderationSummary.value = summary;
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoTranscriptController.fetchSummary',
      );
    } finally {
      isLoadingSummary.value = false;
    }
  }

  @override
  void onClose() {
    transcriptScrollController.dispose();
    super.onClose();
  }
}
