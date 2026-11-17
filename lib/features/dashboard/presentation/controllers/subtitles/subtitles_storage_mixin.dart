import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart' show UniqueKey;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Mixin handling subtitle parsing, file imports, storage uploads, and saving
mixin SubtitlesStorageMixin on SubtitlesControllerBase {
  /// In-memory cache of parsed subtitle cues by "${videoId}_${langCode}"
  static final Map<String, List<SubtitleCue>> _cuesCache = {};

  /// Public accessor for cached subtitle cues
  static Map<String, List<SubtitleCue>> get cuesCache => _cuesCache;

  /// In-flight dedup map to eliminate redundant parallel download and parse cascades
  static final Map<String, Future<void>> _inFlightParses = {};

  static void clearCuesCache([String? videoId]) {
    if (videoId != null) {
      _cuesCache.removeWhere((k, _) => k.startsWith('${videoId}_'));
      _inFlightParses.removeWhere((k, _) => k.startsWith('${videoId}_'));
    } else {
      _cuesCache.clear();
      _inFlightParses.clear();
    }
  }

  @override
  Future<void> parseCuesForLanguage(String langCode, String? urlOrData) async {
    final video = selectedVideo.value;
    final parseKey = '${video?.id ?? ""}_${langCode}_${urlOrData ?? ""}';
    if (_inFlightParses.containsKey(parseKey)) {
      await _inFlightParses[parseKey];
      return;
    }

    final future = _parseCuesForLanguageInternal(langCode, urlOrData);
    _inFlightParses[parseKey] = future;
    try {
      await future;
    } finally {
      _inFlightParses.remove(parseKey);
    }
  }

  Future<void> _parseCuesForLanguageInternal(String langCode, String? urlOrData) async {
    final video = selectedVideo.value;
    final cacheKey = video != null ? '${video.id}_$langCode' : null;

    // Fast-path: return cached cues immediately to avoid repeated network round-trips
    if (cacheKey != null && _cuesCache.containsKey(cacheKey) && _cuesCache[cacheKey]!.isNotEmpty) {
      final cachedList = _cuesCache[cacheKey]!
          .map((c) => c.copyWith(id: UniqueKey().toString()))
          .toList();
      safeStateAction(() {
        currentCues.value = cachedList;
      });
      setViewState(ViewState.success);
      return;
    }

    if (urlOrData == null || urlOrData.trim().isEmpty) {
      // Execute robust multi-source fallback before clearing cues
      if (video != null) {
        final fallbackCues = await _resolveFallbackCues(video, langCode);
        if (fallbackCues.isNotEmpty) {
          if (cacheKey != null) {
            _cuesCache[cacheKey] = fallbackCues;
          }
          safeStateAction(() {
            currentCues.value = fallbackCues;
          });
          setViewState(ViewState.success);
          return;
        }
      }
      safeStateAction(currentCues.clear);
      setViewState(ViewState.success);
      return;
    }

    var contentToParse = urlOrData;

    if (urlOrData.startsWith('gs://') ||
        urlOrData.startsWith('http://') ||
        urlOrData.startsWith('https://') ||
        urlOrData.startsWith('subtitles/') ||
        urlOrData.startsWith('videos/') ||
        urlOrData.startsWith('transcripts/')) {
      try {
        setViewState(ViewState.loading);

        final isHttp = urlOrData.startsWith('http://') || urlOrData.startsWith('https://');

        // 1. Direct fast HTTP/CDN download on web or HTTP URLs (eliminates SDK CORS & token hangs)
        if (isHttp || kIsWeb) {
          try {
            final fastUrl = StorageUtils.getFastDownloadUrl(urlOrData);
            final targetUrl = fastUrl.isNotEmpty ? fastUrl : await StorageUtils.resolveUrl(urlOrData);
            final headers = await StorageUtils.getMediaHeaders(targetUrl: targetUrl);
            final response = await AppHttpClient.get(
              Uri.parse(targetUrl),
              headers: headers.isNotEmpty ? headers : null,
            );
            if (response.statusCode == 200) {
              contentToParse = utf8.decode(response.bodyBytes, allowMalformed: true);
            }
          } catch (_) {}
        }

        // Abort early if user navigated or selected another video
        if (selectedVideo.value?.id != video?.id) return;

        // 2. Storage SDK download with timeout if HTTP direct download did not resolve
        if (contentToParse == urlOrData) {
          final ref = StorageUtils.getStorageRef(urlOrData);
          if (ref != null) {
            try {
              final rawBytes = await StorageUtils.getDataWithTimeout(
                ref,
                timeout: const Duration(seconds: 3),
              );
              if (rawBytes != null && rawBytes.isNotEmpty) {
                contentToParse = utf8.decode(rawBytes, allowMalformed: true);
              }
            } catch (storageErr) {
              logger.info(
                'ref.getData fallback to resolved download URL: $storageErr',
                tag: SubtitlesControllerBase.subtitlesTag,
              );
            }
          }
        }

        // Abort early if user navigated or selected another video
        if (selectedVideo.value?.id != video?.id) return;

        // 3. Fallback: Resolve HTTP/CDN tokenized download URL if still unparsed
        if (contentToParse == urlOrData) {
          final downloadUrl = await StorageUtils.resolveUrl(urlOrData);
          final targetUrl = downloadUrl.isNotEmpty ? downloadUrl : urlOrData;
          final headers = await StorageUtils.getMediaHeaders(targetUrl: targetUrl);

          try {
            final response = await AppHttpClient.get(
              Uri.parse(targetUrl),
              headers: headers.isNotEmpty ? headers : null,
            );
            if (response.statusCode == 200) {
              contentToParse = utf8.decode(response.bodyBytes, allowMalformed: true);
            } else {
              logger.info(
                'Primary subtitle file not found at $targetUrl (HTTP ${response.statusCode}), checking fallback transcripts/probes...',
                tag: SubtitlesControllerBase.subtitlesTag,
              );
            }
          } catch (_) {}
        }
      } catch (e) {
        logger.info(
          'Error downloading remote subtitle link: $urlOrData ($e), checking fallbacks...',
          tag: SubtitlesControllerBase.subtitlesTag,
        );
      }
    }

    // Abort early if user navigated or selected another video
    if (selectedVideo.value?.id != video?.id) return;

    if (contentToParse != urlOrData) {
      final segments = await IsolateComputeUtils.parseSubtitlesAsync(contentToParse);
      if (selectedVideo.value?.id != video?.id) return;
      if (segments.isNotEmpty) {
        final cues = segments.map((seg) {
          return SubtitleCue(
            id: UniqueKey().toString(),
            startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
            endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
            text: seg.text,
          );
        }).toList();
        if (cacheKey != null) {
          _cuesCache[cacheKey] = cues;
        }
        currentCues.value = cues;
        setViewState(ViewState.success);
        return;
      }
    }

    // If direct content parsing did not produce cues and content was raw VTT/SRT text
    if (contentToParse == urlOrData &&
        !urlOrData.startsWith('http') &&
        !urlOrData.startsWith('gs://') &&
        !urlOrData.startsWith('subtitles/') &&
        !urlOrData.startsWith('videos/') &&
        !urlOrData.startsWith('transcripts/')) {
      final segments = await IsolateComputeUtils.parseSubtitlesAsync(contentToParse);
      if (selectedVideo.value?.id != video?.id) return;
      if (segments.isNotEmpty) {
        final cues = segments.map((seg) {
          return SubtitleCue(
            id: UniqueKey().toString(),
            startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
            endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
            text: seg.text,
          );
        }).toList();
        if (cacheKey != null) {
          _cuesCache[cacheKey] = cues;
        }
        safeStateAction(() {
          currentCues.value = cues;
        });
        setViewState(ViewState.success);
        return;
      }
    }

    // 4. Comprehensive multi-source fallback recovery
    if (selectedVideo.value?.id != video?.id) return;
    if (video != null) {
      final fallbackCues = await _resolveFallbackCues(video, langCode);
      if (selectedVideo.value?.id != video.id) return;
      if (fallbackCues.isNotEmpty) {
        if (cacheKey != null) {
          _cuesCache[cacheKey] = fallbackCues;
        }
        safeStateAction(() {
          currentCues.value = fallbackCues;
        });
        setViewState(ViewState.success);
        return;
      }
    }

    if (selectedVideo.value?.id != video?.id) return;
    safeStateAction(currentCues.clear);
    setViewState(ViewState.success);
  }

  /// Extracts subtitle cues from Firestore transcript document payload
  Future<List<SubtitleCue>> _extractCuesFromTranscriptData(Map<String, dynamic> data) async {
    try {
      if (data['utterances'] != null ||
          data['segments'] != null ||
          data['words'] != null) {
        final segs = await IsolateComputeUtils.parseSubtitlesAsync(jsonEncode(data));
        if (segs.isNotEmpty) {
          return segs.map((seg) => SubtitleCue(
            id: UniqueKey().toString(),
            startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
            endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
            text: seg.text,
          )).toList();
        }
      }
      if (data['text'] != null && (data['text'] as String).trim().isNotEmpty) {
        final segs = await IsolateComputeUtils.parseSubtitlesAsync(data['text'] as String);
        if (segs.isNotEmpty) {
          return segs.map((seg) => SubtitleCue(
            id: UniqueKey().toString(),
            startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
            endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
            text: seg.text,
          )).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Resolves subtitle cues from Firestore transcripts, video_jobs, or Storage candidate probes
  Future<List<SubtitleCue>> _resolveFallbackCues(Video video, String langCode) async {
    final normCode = normalizeLanguageCode(langCode);
    final videoLangCode = normalizeLanguageCode(video.language);
    final isOriginalLang = normCode == videoLangCode ||
        langCode == video.language ||
        (videoLangCode == 'en' && normCode == 'en');

    var retrievedJobId = video.jobId;

    // 1. If jobId is not on local model, retrieve from root video doc in Firestore
    if (retrievedJobId == null || retrievedJobId.isEmpty) {
      try {
        final vSnap = await firestore
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .get();
        if (vSnap.exists && vSnap.data() != null) {
          final data = vSnap.data()!;
          retrievedJobId = (data['jobId'] as String?)?.trim();
        }
      } catch (_) {}
    }

    // 2. If track is for original spoken language, check Firestore transcripts collection (authenticated users only)
    if (isOriginalLang && FirebaseAuth.instance.currentUser != null) {
      // 2.1 Check transcripts/{video.id}
      try {
        final tSnap = await firestore.collection('transcripts').doc(video.id).get();
        if (tSnap.exists && tSnap.data() != null) {
          final cues = await _extractCuesFromTranscriptData(tSnap.data()!);
          if (cues.isNotEmpty) return cues;
        }
      } catch (_) {}

      // 2.2 Check transcripts/{jobId}
      if (retrievedJobId != null && retrievedJobId.isNotEmpty && retrievedJobId != video.id) {
        try {
          final jSnap = await firestore.collection('transcripts').doc(retrievedJobId).get();
          if (jSnap.exists && jSnap.data() != null) {
            final cues = await _extractCuesFromTranscriptData(jSnap.data()!);
            if (cues.isNotEmpty) return cues;
          }
        } catch (_) {}
      }

      // 2.3 Check video_jobs/{jobId} artifacts.transcription
      if (retrievedJobId != null && retrievedJobId.isNotEmpty) {
        try {
          final jobSnap = await firestore.collection('video_jobs').doc(retrievedJobId).get();
          if (jobSnap.exists && jobSnap.data() != null) {
            final jobData = jobSnap.data()!;
            final artifacts = jobData['artifacts'] as Map<String, dynamic>?;
            final transcription = artifacts?['transcription'] as Map<String, dynamic>?;
            if (transcription != null) {
              final cues = await _extractCuesFromTranscriptData(transcription);
              if (cues.isNotEmpty) return cues;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Check Firestore video_jobs/{jobId} outputs.subtitles for this target language
    if (retrievedJobId != null && retrievedJobId.isNotEmpty) {
      try {
        final jobSnap = await firestore.collection('video_jobs').doc(retrievedJobId).get();
        if (jobSnap.exists && jobSnap.data() != null) {
          final jobData = jobSnap.data()!;
          final outputs = jobData['outputs'] as Map<String, dynamic>?;
          final subs = outputs?['subtitles'] as Map<String, dynamic>?;
          final targetSub = subs?[langCode] ?? subs?[normCode];
          if (targetSub != null && targetSub is String && targetSub.isNotEmpty) {
            final segs = await IsolateComputeUtils.parseSubtitlesAsync(targetSub);
            if (segs.isNotEmpty) {
              return segs.map((seg) => SubtitleCue(
                id: UniqueKey().toString(),
                startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
                endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
                text: seg.text,
              )).toList();
            }
          }
        }
      } catch (_) {}
    }

    // 4. Parallel storage probe across canonical candidate paths
    final storage = FirebaseStorage.instance;
    final probePaths = <String>[
      'videos/${video.id}/subtitles/$normCode.vtt',
      'videos/${video.id}/subtitles/$normCode.srt',
      if (langCode != normCode) ...[
        'videos/${video.id}/subtitles/$langCode.vtt',
        'videos/${video.id}/subtitles/$langCode.srt',
      ],
      'subtitles/${video.id}/$normCode.vtt',
      'subtitles/${video.id}/$normCode.srt',
      if (langCode != normCode) ...[
        'subtitles/${video.id}/$langCode.vtt',
        'subtitles/${video.id}/$langCode.srt',
      ],
      if (isOriginalLang) ...[
        'transcripts/${video.id}/full.json',
        'transcripts/${video.id}.json',
      ],
      if (retrievedJobId != null && retrievedJobId.isNotEmpty && retrievedJobId != video.id) ...[
        'videos/$retrievedJobId/subtitles/$normCode.vtt',
        'videos/$retrievedJobId/subtitles/$normCode.srt',
        if (langCode != normCode) ...[
          'videos/$retrievedJobId/subtitles/$langCode.vtt',
          'videos/$retrievedJobId/subtitles/$langCode.srt',
        ],
        'subtitles/$retrievedJobId/$normCode.vtt',
        'subtitles/$retrievedJobId/$normCode.srt',
        if (langCode != normCode) ...[
          'subtitles/$retrievedJobId/$langCode.vtt',
          'subtitles/$retrievedJobId/$langCode.srt',
        ],
        if (isOriginalLang) ...[
          'transcripts/$retrievedJobId/full.json',
          'transcripts/$retrievedJobId.json',
        ],
      ],
    ];

    try {
      final probeFutures = probePaths.map((p) async {
        try {
          final bytes = await StorageUtils.getDataWithTimeout(
            storage.ref(p),
            timeout: const Duration(milliseconds: 1500),
          );
          if (bytes != null && bytes.isNotEmpty) {
            return utf8.decode(bytes, allowMalformed: true);
          }
        } catch (_) {}
        return null;
      });

      final probeResults = await Future.wait(probeFutures);
      for (final raw in probeResults) {
        if (raw != null && raw.isNotEmpty) {
          final segs = await IsolateComputeUtils.parseSubtitlesAsync(raw);
          if (segs.isNotEmpty) {
            return segs.map((seg) => SubtitleCue(
              id: UniqueKey().toString(),
              startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
              endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
              text: seg.text,
            )).toList();
          }
        }
      }
    } catch (_) {}

    return [];
  }

  Future<void> saveCurrentSubtitles() async {
    final video = selectedVideo.value;
    final lang = selectedLanguage.value;
    if (video == null || lang.isEmpty) return;

    for (var i = 0; i < currentCues.length; i++) {
      final cue = currentCues[i];
      if (cue.text.trim().isNotEmpty) {

        final v = ContentValidator.validate(
          cue.text,
          fieldName: 'Subtitle Cue ${i + 1}',

        );
        if (!v.isValid) {
          showWarning(v.message);
          return;
        }
      }
    }

    isSaving.value = true;
    try {
      final buffer = StringBuffer();
      buffer.writeln('WEBVTT');
      buffer.writeln();
      for (final cue in currentCues) {
        buffer.writeln('${cue.startTime} --> ${cue.endTime}');
        buffer.writeln(cue.text);
        buffer.writeln();
      }
      final vttContent = buffer.toString();

      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);

      final existingValue = updatedSubs[lang] ?? '';
      final isAlreadyUrl = existingValue.startsWith('http') ||
          existingValue.startsWith('gs://') ||
          existingValue.startsWith('https://');

      if (currentCues.isNotEmpty || !isAlreadyUrl) {
        final storagePath = 'videos/${video.id}/subtitles/$lang.vtt';
        final storageRef = FirebaseStorage.instance.ref().child(storagePath);
        final vttBytes = vttContent.codeUnits;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        await storageRef.putData(
          Uint8List.fromList(vttBytes),
          SettableMetadata(
            contentType: 'text/vtt',
            customMetadata: {
              'uploaderId': ?currentUid,
            },
          ),
        );

        final bucket = FirebaseStorage.instance.ref().bucket;
        final gsUrl = 'gs://$bucket/$storagePath';
        updatedSubs[lang] = gsUrl;
      }

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'dubbedVideos': video.dubbedVideos,
            'audioTracks': video.audioTracks,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .update({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      _cuesCache.removeWhere((k, _) => k.startsWith('${video.id}_'));

      final updatedVideo = video.copyWith(mediaSubtitles: updatedSubs);
      selectedVideo.value = updatedVideo;
      if (ownerVideosMap.containsKey(video.id)) {
        ownerVideosMap[video.id] = updatedVideo;
      }
      if (channelVideosMap.containsKey(video.id)) {
        channelVideosMap[video.id] = updatedVideo;
      }
      final vIdx = videos.indexWhere((v) => v.id == video.id);
      if (vIdx != -1) {
        videos[vIdx] = updatedVideo;
      }
      final fIdx = filteredVideos.indexWhere((v) => v.id == video.id);
      if (fIdx != -1) {
        filteredVideos[fIdx] = updatedVideo;
      }
      selectedVideo.refresh();

      hasUnsavedChanges.value = false;
      showSuccess('${getLanguageName(lang)} subtitles saved successfully!');
    } catch (e, stack) {
      logger.error(
        'Failed to save subtitles',
        error: e,
        stackTrace: stack,
        tag: SubtitlesControllerBase.subtitlesTag,
      );
      handleError('Failed to save subtitle track');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> uploadSubtitleTrack({
    required String languageCode,
    required String title,
    required PlatformFile file,
  }) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return;
    }

    isUploadingFile.value = true;
    try {
      final valResult = await validateContent(title, fieldName: 'Track Title');
      if (!valResult.isValid) {
        showError(valResult.message);
        return;
      }

      final Uint8List fileBytes;
      if (kIsWeb) {
        if (file.bytes == null) {
          showError('Invalid file: no bytes read.');
          return;
        }
        fileBytes = file.bytes!;
      } else {
        if (file.path == null) {
          showError('Invalid file: path is null.');
          return;
        }
        final localFile = File(file.path!);
        if (!localFile.existsSync()) {
          showError('File does not exist locally.');
          return;
        }
        fileBytes = await localFile.readAsBytes();
      }

      final sanitizedTitle = title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final extension = file.extension ?? 'vtt';
      final storagePath =
          'videos/${video.id}/subtitles/${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'text/vtt',
        customMetadata: {
          'uploaderId': ?currentUid,
        },
      );

      final uploadTask = storageRef.putData(fileBytes, metadata);
      await uploadTask;

      final bucket = FirebaseStorage.instance.ref().bucket;
      final gsUrl = 'gs://$bucket/$storagePath';

      final trackKey = languageCode.isNotEmpty ? languageCode : title;
      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);
      updatedSubs[trackKey] = gsUrl;

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      _cuesCache.removeWhere((k, _) => k.startsWith('${video.id}_'));

      final updatedVideo = video.copyWith(mediaSubtitles: updatedSubs);
      selectedVideo.value = updatedVideo;
      if (ownerVideosMap.containsKey(video.id)) {
        ownerVideosMap[video.id] = updatedVideo;
      }
      if (channelVideosMap.containsKey(video.id)) {
        channelVideosMap[video.id] = updatedVideo;
      }
      final vIdx = videos.indexWhere((v) => v.id == video.id);
      if (vIdx != -1) {
        videos[vIdx] = updatedVideo;
      }
      final fIdx = filteredVideos.indexWhere((v) => v.id == video.id);
      if (fIdx != -1) {
        filteredVideos[fIdx] = updatedVideo;
      }
      selectedVideo.refresh();

      if (!availableLanguages.contains(trackKey)) {
        availableLanguages.add(trackKey);
      }
      selectedLanguage.value = trackKey;
      hasUnsavedChanges.value = false;
      if (updatedSubs.containsKey(trackKey)) {
        parseCuesForLanguage(trackKey, updatedSubs[trackKey]);
      }

      showSuccess('Subtitle track "$title" uploaded successfully!');
    } catch (e, stack) {
      logger.error(
        'Failed to upload subtitle track',
        error: e,
        stackTrace: stack,
        tag: SubtitlesControllerBase.subtitlesTag,
      );
      showError('Unable to upload subtitle track. Please try again.');
    } finally {
      isUploadingFile.value = false;
    }
  }

  Future<void> deleteLanguageTrack(String langCode) async {
    final video = selectedVideo.value;
    if (video == null) return;

    final cleanCode = langCode.trim().toLowerCase();
    final normCode = normalizeLanguageCode(cleanCode);
    final baseLang = normalizeLanguageCode(video.language);

    if (cleanCode == baseLang || normCode == baseLang) {
      showError('Cannot remove original video subtitle.');
      return;
    }

    try {
      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);
      var trackUrl = updatedSubs[langCode] ??
          updatedSubs[cleanCode] ??
          updatedSubs[normCode] ??
          '';
      if (trackUrl.isEmpty) {
        for (final entry in updatedSubs.entries) {
          final kLower = entry.key.trim().toLowerCase();
          final kNorm = normalizeLanguageCode(kLower);
          if (kLower == cleanCode || kNorm == normCode || kLower == normCode) {
            trackUrl = entry.value;
            break;
          }
        }
      }
      updatedSubs.remove(langCode);
      updatedSubs.remove(cleanCode);
      updatedSubs.remove(normCode);
      updatedSubs.removeWhere((k, _) {
        final kLower = k.trim().toLowerCase();
        final kNorm = normalizeLanguageCode(kLower);
        return kLower == cleanCode ||
            kNorm == normCode ||
            kLower == normCode ||
            kNorm == cleanCode;
      });

      availableLanguages.remove(langCode);
      availableLanguages.remove(cleanCode);
      availableLanguages.remove(normCode);
      availableLanguages.removeWhere((l) {
        final lLower = l.trim().toLowerCase();
        final lNorm = normalizeLanguageCode(lLower);
        return lLower == cleanCode ||
            lNorm == normCode ||
            lLower == normCode ||
            lNorm == cleanCode;
      });

      aiTargetLanguages.remove(langCode);
      aiTargetLanguages.remove(cleanCode);
      aiTargetLanguages.remove(normCode);
      aiTargetLanguages.removeWhere((l) {
        final lNorm = normalizeLanguageCode(l);
        return lNorm == normCode || l.trim().toLowerCase() == cleanCode;
      });
      aiLanguageStatuses.remove(langCode);
      aiLanguageStatuses.remove(cleanCode);
      aiLanguageStatuses.remove(normCode);
      aiLanguageStatuses.removeWhere((k, _) {
        final kNorm = normalizeLanguageCode(k);
        return kNorm == normCode || k.trim().toLowerCase() == cleanCode;
      });

      // Always remove the deleted language track from video.languages
      final updatedLanguages = List<String>.from(video.languages)
        ..removeWhere((l) {
          final lLower = l.trim().toLowerCase();
          final lNorm = normalizeLanguageCode(lLower);
          return lLower == cleanCode ||
              lNorm == normCode ||
              lLower == normCode ||
              lNorm == cleanCode;
        });

      final updatedVideo = video.copyWith(
        mediaSubtitles: updatedSubs,
        languages: updatedLanguages,
      );
      selectedVideo.value = updatedVideo;

      if (ownerVideosMap.containsKey(video.id)) {
        ownerVideosMap[video.id] = updatedVideo;
      }
      if (channelVideosMap.containsKey(video.id)) {
        channelVideosMap[video.id] = updatedVideo;
      }
      final vIdx = videos.indexWhere((v) => v.id == video.id);
      if (vIdx != -1) {
        videos[vIdx] = updatedVideo;
        videos.refresh();
      }
      final fIdx = filteredVideos.indexWhere((v) => v.id == video.id);
      if (fIdx != -1) {
        filteredVideos[fIdx] = updatedVideo;
        filteredVideos.refresh();
      }

      final cachedLoc = VideoMediaService.localizationCache[video.id];
      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: cachedLoc?.dubbedVideos ?? video.dubbedVideos,
        audioTracks: cachedLoc?.audioTracks ?? video.audioTracks,
        commentaryVideos: cachedLoc?.commentaryVideos ?? const {},
      );

      _cuesCache.removeWhere((k, _) {
        if (!k.startsWith('${video.id}_')) return false;
        final kCode = k.substring('${video.id}_'.length).toLowerCase();
        return kCode == cleanCode ||
            kCode == normCode ||
            normalizeLanguageCode(kCode) == normCode;
      });
      _inFlightParses.removeWhere((k, _) {
        if (!k.startsWith('${video.id}_')) return false;
        final kCode = k.substring('${video.id}_'.length).toLowerCase();
        return kCode == cleanCode ||
            kCode == normCode ||
            normalizeLanguageCode(kCode) == normCode;
      });

      final currentSelected = selectedLanguage.value.trim().toLowerCase();
      if (currentSelected == cleanCode ||
          normalizeLanguageCode(currentSelected) == normCode ||
          currentSelected == langCode.toLowerCase()) {
        if (availableLanguages.isNotEmpty) {
          selectedLanguage.value = availableLanguages.first;
          hasUnsavedChanges.value = false;
          final subs = updatedSubs;
          if (subs.containsKey(availableLanguages.first)) {
            parseCuesForLanguage(
              availableLanguages.first,
              subs[availableLanguages.first],
            );
          } else {
            currentCues.clear();
          }
        } else {
          selectedLanguage.value = baseLang;
          currentCues.clear();
        }
      }

      selectedVideo.refresh();

      // Cloud Persistence: media/localization subcollection
      try {
        final locRef = firestore
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .collection('media')
            .doc('localization');

        final locSnap = await locRef.get();
        if (locSnap.exists) {
          await locRef.update({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final locData = locSnap.data() ?? {};
          final flatKeys = locData.keys.where((k) {
            final lk = k.toLowerCase();
            return lk == 'subtitles.$cleanCode' ||
                lk == 'subtitles.$normCode' ||
                lk == 'subtitles.$langCode' ||
                lk == 'media.subtitles.$cleanCode' ||
                lk == 'media.subtitles.$normCode' ||
                lk == 'media.subtitles.$langCode';
          }).toList();
          if (flatKeys.isNotEmpty) {
            final flatDeletes = <String, dynamic>{};
            for (final k in flatKeys) {
              flatDeletes[k] = FieldValue.delete();
            }
            await locRef.update(flatDeletes).catchError((_) {});
          }
        } else {
          await locRef.set({
            'subtitles': updatedSubs,
            'dubbedVideos': cachedLoc?.dubbedVideos ?? video.dubbedVideos,
            'audioTracks': cachedLoc?.audioTracks ?? video.audioTracks,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        logger.warning(
          'Failed to update localization doc on delete: $e',
          tag: SubtitlesControllerBase.subtitlesTag,
        );
      }

      // Cloud Persistence: main video doc
      try {
        final videoRef = firestore
            .collection(FirestoreCollections.videos)
            .doc(video.id);

        final videoSnap = await videoRef.get();
        if (videoSnap.exists) {
          final vData = videoSnap.data() ?? {};
          final videoUpdates = <String, dynamic>{
            'subtitles': updatedSubs,
            'mediaSubtitles': updatedSubs,
            'languages': updatedLanguages,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (vData['media'] is Map) {
            videoUpdates['media.subtitles'] = updatedSubs;
          }
          if (vData['aiFeatures'] is Map) {
            final aiFeatures = Map<String, dynamic>.from(vData['aiFeatures'] as Map);
            var aiFeaturesChanged = false;
            if (aiFeatures['subtitleLanguages'] is List) {
              final subLangs = List<dynamic>.from(aiFeatures['subtitleLanguages'] as List)
                ..removeWhere((l) {
                  final lNorm = normalizeLanguageCode(l.toString());
                  final lStr = l.toString().trim().toLowerCase();
                  return lNorm == cleanCode || lNorm == normCode || lStr == cleanCode;
                });
              aiFeatures['subtitleLanguages'] = subLangs;
              aiFeaturesChanged = true;
            }
            if (aiFeatures['translationLanguages'] is List) {
              final transLangs = List<dynamic>.from(aiFeatures['translationLanguages'] as List)
                ..removeWhere((l) {
                  final lNorm = normalizeLanguageCode(l.toString());
                  final lStr = l.toString().trim().toLowerCase();
                  return lNorm == cleanCode || lNorm == normCode || lStr == cleanCode;
                });
              aiFeatures['translationLanguages'] = transLangs;
              aiFeaturesChanged = true;
            }
            if (aiFeaturesChanged) {
              videoUpdates['aiFeatures'] = aiFeatures;
            }
          }
          await videoRef.update(videoUpdates);

          final flatKeys = vData.keys.where((k) {
            final lk = k.toLowerCase();
            return lk == 'subtitles.$cleanCode' ||
                lk == 'subtitles.$normCode' ||
                lk == 'subtitles.$langCode' ||
                lk == 'media.subtitles.$cleanCode' ||
                lk == 'media.subtitles.$normCode' ||
                lk == 'media.subtitles.$langCode' ||
                lk == 'mediasubtitles.$cleanCode' ||
                lk == 'mediasubtitles.$normCode' ||
                lk == 'mediasubtitles.$langCode';
          }).toList();
          if (flatKeys.isNotEmpty) {
            final flatDeletes = <String, dynamic>{};
            for (final k in flatKeys) {
              flatDeletes[k] = FieldValue.delete();
            }
            await videoRef.update(flatDeletes).catchError((_) {});
          }
        } else {
          await videoRef.set({
            'subtitles': updatedSubs,
            'mediaSubtitles': updatedSubs,
            'languages': updatedLanguages,
            'media': {
              'subtitles': updatedSubs,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        logger.warning(
          'Failed to update video doc on delete: $e',
          tag: SubtitlesControllerBase.subtitlesTag,
        );
      }

      // Clean video_jobs document
      try {
        final jobIdsToClean = <String>{video.id};
        final vJobId = video.jobId;
        if (vJobId != null && vJobId.isNotEmpty) {
          jobIdsToClean.add(vJobId);
        }
        final vSnap = await firestore
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .get();
        if (vSnap.exists && vSnap.data() != null) {
          final jId = (vSnap.data()!['jobId'] as String?)?.trim();
          if (jId != null && jId.isNotEmpty) {
            jobIdsToClean.add(jId);
          }
        }

        for (final jId in jobIdsToClean) {
          final jobRef = firestore.collection('video_jobs').doc(jId);
          final jobSnap = await jobRef.get();
          if (jobSnap.exists) {
            final jData = jobSnap.data() ?? {};
            final jobUpdates = <String, dynamic>{};
            final outputs = jData['outputs'];
            if (outputs is Map && outputs['subtitles'] is Map) {
              final curOut =
                  Map<String, dynamic>.from(outputs['subtitles'] as Map);
              curOut.remove(cleanCode);
              curOut.remove(normCode);
              curOut.remove(langCode);
              curOut.removeWhere((k, _) {
                final kStr = k.toLowerCase();
                return kStr == cleanCode ||
                    kStr == normCode ||
                    normalizeLanguageCode(kStr) == normCode;
              });
              jobUpdates['outputs.subtitles'] = curOut;
            }
            if (jData['subtitles'] is Map) {
              final curSubs =
                  Map<String, dynamic>.from(jData['subtitles'] as Map);
              curSubs.remove(cleanCode);
              curSubs.remove(normCode);
              curSubs.remove(langCode);
              curSubs.removeWhere((k, _) {
                final kStr = k.toLowerCase();
                return kStr == cleanCode ||
                    kStr == normCode ||
                    normalizeLanguageCode(kStr) == normCode;
              });
              jobUpdates['subtitles'] = curSubs;
            }
            final stages = jData['stages'];
            if (stages is Map) {
              for (final code in [cleanCode, normCode, langCode]) {
                if (stages.containsKey('subtitles_$code')) {
                  jobUpdates['stages.subtitles_$code'] = FieldValue.delete();
                }
                if (stages.containsKey('translating_$code')) {
                  jobUpdates['stages.translating_$code'] = FieldValue.delete();
                }
              }
            }
            final executionPlan = jData['executionPlan'];
            if (executionPlan is Map) {
              if (executionPlan['subtitleLanguages'] is List) {
                final list =
                    List<dynamic>.from(executionPlan['subtitleLanguages'] as List)
                      ..removeWhere((item) {
                        final itemStr = item.toString().toLowerCase();
                        return itemStr == cleanCode ||
                            itemStr == normCode ||
                            normalizeLanguageCode(itemStr) == normCode;
                      });
                jobUpdates['executionPlan.subtitleLanguages'] = list;
              }
              if (executionPlan['languages'] is List &&
                  executionPlan['dubbingLanguages'] is! List) {
                final list =
                    List<dynamic>.from(executionPlan['languages'] as List)
                      ..removeWhere((item) {
                        final itemStr = item.toString().toLowerCase();
                        return itemStr == cleanCode ||
                            itemStr == normCode ||
                            normalizeLanguageCode(itemStr) == normCode;
                      });
                jobUpdates['executionPlan.languages'] = list;
              }
            }
            if (jobUpdates.isNotEmpty) {
              await jobRef.update(jobUpdates).catchError((_) {});
            }
          }
        }
      } catch (_) {}

      // Clean separate video_jobs matching videoId
      try {
        final jobsSnap = await firestore
            .collection(FirestoreCollections.videoJobs)
            .where('videoId', isEqualTo: video.id)
            .get();

        for (final doc in jobsSnap.docs) {
          final data = doc.data();
          final jobTarget =
              (data['targetLanguage'] ?? '').toString().toLowerCase();
          final jobFeature =
              (data['feature'] ?? data['type'] ?? '').toString().toLowerCase();
          if ((jobTarget == cleanCode || jobTarget == normCode) &&
              (jobFeature.contains('sub') || jobFeature.isEmpty)) {
            await doc.reference.delete().catchError((_) {});
          }
        }
      } catch (_) {}

      // Delete storage files if available
      try {
        final storage = FirebaseStorage.instance;
        final candidateStoragePaths = <String>[
          'videos/${video.id}/subtitles/$cleanCode.vtt',
          'videos/${video.id}/subtitles/$cleanCode.srt',
          'videos/${video.id}/subtitles/$normCode.vtt',
          'videos/${video.id}/subtitles/$normCode.srt',
          'subtitles/${video.id}/$cleanCode.vtt',
          'subtitles/${video.id}/$cleanCode.srt',
          'subtitles/${video.id}/$normCode.vtt',
          'subtitles/${video.id}/$normCode.srt',
        ];
        final vJobId = video.jobId;
        if (vJobId != null && vJobId.isNotEmpty && vJobId != video.id) {
          candidateStoragePaths.addAll([
            'videos/$vJobId/subtitles/$cleanCode.vtt',
            'videos/$vJobId/subtitles/$cleanCode.srt',
            'videos/$vJobId/subtitles/$normCode.vtt',
            'videos/$vJobId/subtitles/$normCode.srt',
            'subtitles/$vJobId/$cleanCode.vtt',
            'subtitles/$vJobId/$cleanCode.srt',
            'subtitles/$vJobId/$normCode.vtt',
            'subtitles/$vJobId/$normCode.srt',
          ]);
        }
        for (final sp in candidateStoragePaths) {
          await storage.ref().child(sp).delete().catchError((_) {});
        }

        if (trackUrl.isNotEmpty &&
            (trackUrl.startsWith('gs://') ||
                trackUrl.contains('firebasestorage.googleapis.com'))) {
          await storage.refFromURL(trackUrl).delete().catchError((_) {});
        }
      } catch (_) {}

      final langDisplayName = getLanguageName(langCode);
      showSuccess('Removed $langDisplayName subtitle');
    } catch (e, stack) {
      logger.error('Failed to remove subtitle track', error: e, stackTrace: stack, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to remove subtitle track. Please try again.');
    }
  }

  Future<void> importSubtitleFile({
    bool replaceCurrentTrack = true,
    String? asNewLanguageCode,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vtt', 'srt', 'txt', 'json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String content;
      if (kIsWeb || file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        showError('Unable to read subtitle file content.');
        return;
      }

      final segments = SubtitleParser.parse(content);
      if (segments.isEmpty) {
        showError('No valid subtitle cues found in selected file.');
        return;
      }

      final newCues = segments.map((seg) {
        return SubtitleCue(
          id: UniqueKey().toString(),
          startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
          endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
          text: seg.text,
        );
      }).toList();

      if (asNewLanguageCode != null && asNewLanguageCode.isNotEmpty) {
        if (!availableLanguages.contains(asNewLanguageCode)) {
          availableLanguages.add(asNewLanguageCode);
        }
        selectedLanguage.value = asNewLanguageCode;
        currentCues.value = newCues;
      } else if (replaceCurrentTrack) {
        currentCues.value = newCues;
      } else {
        currentCues.addAll(newCues);
        currentCues.sort((a, b) {
          final aMs = SubtitleParser.parseTimeDuration(a.startTime).inMilliseconds;
          final bMs = SubtitleParser.parseTimeDuration(b.startTime).inMilliseconds;
          return aMs.compareTo(bMs);
        });
        currentCues.refresh();
      }

      hasUnsavedChanges.value = true;
      showSuccess('Successfully imported ${newCues.length} subtitle cues!');
    } catch (e) {
      logger.error('Error importing subtitle file', error: e, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to parse subtitle file. Please verify the file format.');
    }
  }
}
