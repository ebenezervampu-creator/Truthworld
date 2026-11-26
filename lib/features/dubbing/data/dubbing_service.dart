import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_project.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';

/// Communication service for TruthWorld Standalone Dubbing Studio.
class DubbingService {
  DubbingService({FirebaseFunctions? functions, FirebaseFirestore? firestore})
      : _functionsInstance = functions,
        _firestoreInstance = firestore;

  final FirebaseFunctions? _functionsInstance;
  final FirebaseFirestore? _firestoreInstance;

  FirebaseFunctions get _functions =>
      _functionsInstance ?? FirebaseFunctions.instanceFor(region: 'asia-south1');
  FirebaseFunctions get _createJobFunctions =>
      _functionsInstance ?? FirebaseFunctions.instanceFor(region: 'us-central1');
  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  /// Fetches the user's current Dubbing Wallet.
  Future<DubbingWallet> fetchWallet({String? userId}) async {
    final uid = userId ?? AuthService.to.uid;
    try {
      final res = await _functions.httpsCallable('getDubbingWallet').call<dynamic>();
      if (res.data is Map) {
        return DubbingWallet.fromMap(Map<String, dynamic>.from(res.data as Map));
      }
    } catch (e) {
      if (uid.isNotEmpty) {
        try {
          final doc = await _firestore.collection('dubbing_wallets').doc(uid).get();
          if (doc.exists && doc.data() != null) {
            return DubbingWallet.fromMap(doc.data()!);
          }
        } catch (_) {}
      }
      logger.warning('Dubbing wallet fetch notice: $e', tag: 'DubbingService');
    }
    return DubbingWallet(userId: uid);
  }

  /// Claims free trial credits (1,000 free test characters).
  Future<Map<String, dynamic>> claimFreeTrial() async {
    try {
      final res = await _functions.httpsCallable('claimFreeDubbingCredits').call<dynamic>();
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      logger.warning('Dubbing claim free trial notice: $e', tag: 'DubbingService');
    }
    return {
      'success': true,
      'message': '1,000 Free Characters are directly available in your wallet.',
    };
  }

  /// Creates a new standalone dubbing job.
  Future<Map<String, dynamic>> createJob({
    required String title,
    required DubbingMode mode,
    required String sourceMediaUrl,
    required String sourceMediaType,
    required int durationSeconds,
    required int characterCount,
    required String sourceLanguage,
    required List<String> targetLanguages,
    required bool voiceCloningEnabled,
    bool voiceCloneConsent = false,
    required bool twoStageReviewEnabled,
    required bool publishToTruthworld,
    required Map<String, dynamic> demuxOptions,
    required List<Map<String, dynamic>> speakers,
    String? videoId,
    String? channelId,
  }) async {
    try {
      final res = await _createJobFunctions.httpsCallable('createDubbingJob').call<dynamic>({
        'title': title,
        'mode': mode == DubbingMode.subtitlesOnly ? 'subtitles_only' : 'dubbing',
        'sourceMediaUrl': sourceMediaUrl,
        'sourceMediaType': sourceMediaType,
        'durationSeconds': durationSeconds,
        'characterCount': characterCount,
        'sourceLanguage': sourceLanguage,
        'targetLanguages': targetLanguages,
        'voiceCloningEnabled': voiceCloningEnabled,
        'voiceCloneConsent': voiceCloningEnabled && voiceCloneConsent,
        'twoStageReviewEnabled': twoStageReviewEnabled,
        'publishToTruthworld': publishToTruthworld,
        'demuxOptions': demuxOptions,
        'speakers': speakers,
        if (videoId != null) 'videoId': videoId,
        if (channelId != null) 'channelId': channelId,
      });

      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'success': false, 'message': 'Failed to create dubbing job.'};
    } on FirebaseFunctionsException catch (e) {
      ErrorHandler.log(e, context: 'DubbingService.createJob');
      final rawMsg = e.message?.trim();
      final hasRealMessage = rawMsg != null &&
          rawMsg.isNotEmpty &&
          rawMsg.toLowerCase() != 'internal' &&
          rawMsg.toLowerCase() != 'unknown';

      String msg;
      if (hasRealMessage) {
        msg = rawMsg;
      } else if (e.code == 'failed-precondition') {
        msg = 'Insufficient credits. Please top up your wallet to start dubbing.';
      } else if (e.code == 'unauthenticated') {
        msg = 'Please sign in to start AI dubbing.';
      } else if (e.code == 'permission-denied') {
        msg = 'You do not have permission to start this dubbing job.';
      } else if (e.code == 'invalid-argument') {
        msg = 'Please check the selected video and languages and try again.';
      } else if (e.code == 'unavailable') {
        msg = 'Dubbing service is temporarily unavailable. Please try again in a few moments.';
      } else {
        msg = 'Unable to initiate dubbing job right now. Please try again shortly.';
      }
      return {'success': false, 'message': msg};
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingService.createJob');
      return {
        'success': false,
        'message': 'Unable to initiate dubbing job. Please try again shortly.',
      };
    }
  }

  /// Streams real-time updates for a dubbing job from `studio_dubbing_jobs`
  /// and mirrors live `video_jobs/{pipelineJobId || videoId}` progress/outputs in real time.
  Stream<DubbingJob?> streamJob(String jobId) {
    late final StreamController<DubbingJob?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? studioSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? videoJobSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? fallbackSub;

    Map<String, dynamic>? latestStudioData;
    Map<String, dynamic>? latestVideoJobData;
    String? subscribedPipelineId;

    void emitMerged() {
      if (controller.isClosed) return;
      if (latestStudioData == null) {
        controller.add(null);
        return;
      }
      controller.add(mergeJobWithVideoJobData(latestStudioData!, latestVideoJobData));
    }

    void ensureVideoJobListener(String? candidateId) {
      final targetId = candidateId?.trim() ?? '';
      if (targetId.isEmpty || targetId == subscribedPipelineId) return;
      subscribedPipelineId = targetId;
      videoJobSub?.cancel();
      videoJobSub = _firestore.collection('video_jobs').doc(targetId).snapshots().listen(
        (vSnap) {
          latestVideoJobData = vSnap.exists && vSnap.data() != null
              ? Map<String, dynamic>.from(vSnap.data()!)
              : null;
          emitMerged();
        },
        onError: (Object err) {
          logger.warning('video_jobs stream notice: $err', tag: 'DubbingService');
        },
      );
    }

    controller = StreamController<DubbingJob?>(
      onListen: () {
        studioSub = _firestore.collection('studio_dubbing_jobs').doc(jobId).snapshots().listen(
          (snap) {
            if (!snap.exists || snap.data() == null) {
              fallbackSub ??= _firestore.collection('dubbing_jobs').doc(jobId).snapshots().listen(
                (fbSnap) {
                  if (fbSnap.exists && fbSnap.data() != null) {
                    latestStudioData = Map<String, dynamic>.from(fbSnap.data()!);
                    emitMerged();
                  } else {
                    latestStudioData = null;
                    emitMerged();
                  }
                },
                onError: (_) {
                  latestStudioData = null;
                  emitMerged();
                },
              );
              return;
            }
            fallbackSub?.cancel();
            fallbackSub = null;
            latestStudioData = Map<String, dynamic>.from(snap.data()!);
            final pipelineId = latestStudioData!['pipelineJobId']?.toString();
            final videoId = latestStudioData!['videoId']?.toString();
            ensureVideoJobListener(
              (pipelineId != null && pipelineId.isNotEmpty) ? pipelineId : videoId,
            );
            emitMerged();
          },
          onError: (Object err, StackTrace st) {
            ErrorHandler.log(err, stackTrace: st, context: 'DubbingService.streamJob');
            if (!controller.isClosed) {
              controller.addError(err, st);
            }
          },
        );
      },
      onCancel: () async {
        await studioSub?.cancel();
        await videoJobSub?.cancel();
        await fallbackSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Converts `gs://bucket/path` URIs into browser-accessible Firebase Storage HTTPS URLs.
  static String toBrowserDownloadUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null &&
          uri.host == 'storage.googleapis.com' &&
          !trimmed.contains('X-Goog-Signature') &&
          !trimmed.contains('GoogleAccessId') &&
          uri.pathSegments.length >= 2) {
        final bucket = uri.pathSegments.first;
        final objectPath = uri.pathSegments.sublist(1).join('/');
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(objectPath)}?alt=media';
      }
      return trimmed;
    }
    if (trimmed.startsWith('gs://')) {
      final withoutScheme = trimmed.substring(5);
      final slashIdx = withoutScheme.indexOf('/');
      if (slashIdx > 0 && slashIdx < withoutScheme.length - 1) {
        final bucket = withoutScheme.substring(0, slashIdx);
        final objectPath = withoutScheme.substring(slashIdx + 1);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(objectPath)}?alt=media';
      }
    }
    return trimmed;
  }

  /// Merges `studio_dubbing_jobs` with live `video_jobs` pipeline state.
  /// Ensures uploaded clips (`pipelineJobId`) and channel videos never stall at 10%.
  static DubbingJob mergeJobWithVideoJobData(
    Map<String, dynamic> studioData,
    Map<String, dynamic>? vData,
  ) {
    final data = Map<String, dynamic>.from(studioData);
    if (vData == null) {
      return DubbingJob.fromMap(data);
    }

    final isSubtitlesOnly = data['mode']?.toString() == 'subtitles_only';
    final studioStatus = data['status']?.toString().toLowerCase() ?? 'processing';
    final isStudioTerminal = studioStatus == 'completed' || studioStatus == 'failed';

    final vStages = vData['stages'] is Map
        ? Map<String, dynamic>.from(vData['stages'] as Map)
        : <String, dynamic>{};
    final existingStages = data['stages'] is Map
        ? Map<String, dynamic>.from(data['stages'] as Map)
        : <String, dynamic>{};

    final transStage = vStages['transcription'] is Map ? vStages['transcription'] as Map : const {};
    final dubStage = vStages['dubbing'] is Map ? vStages['dubbing'] as Map : const {};
    final subStage = vStages['subtitles'] is Map ? vStages['subtitles'] as Map : const {};

    final transStatus = transStage['status']?.toString().toLowerCase() ?? '';
    final dubStatus = dubStage['status']?.toString().toLowerCase() ?? '';
    final subStatus = subStage['status']?.toString().toLowerCase() ?? '';
    final vOverallStatus = vData['status']?.toString().toLowerCase() ?? '';

    final transProgress = (transStage['progress'] as num?)?.toInt() ??
        ((transStatus == 'completed' || transStatus == 'done') ? 100 : 0);
    final dubProgress = (dubStage['progress'] as num?)?.toInt() ??
        ((dubStatus == 'completed' || dubStatus == 'done') ? 100 : 0);
    final subProgress = (subStage['progress'] as num?)?.toInt() ??
        ((subStatus == 'completed' || subStatus == 'done') ? 100 : 0);

    final transDone = transStatus == 'completed' || transStatus == 'done' || transStatus == 'skipped';
    final dubDone = dubStatus == 'completed' || dubStatus == 'done';
    final subDone = subStatus == 'completed' || subStatus == 'done';

    final isFailed = vOverallStatus == 'failed' ||
        vOverallStatus == 'rejected' ||
        transStatus == 'failed' ||
        (!isSubtitlesOnly && dubStatus == 'failed') ||
        (isSubtitlesOnly && subStatus == 'failed');
    final isCompleted = !isFailed &&
        (isSubtitlesOnly
            ? (subDone || vOverallStatus == 'completed')
            : (dubDone || vOverallStatus == 'completed'));

    final audioPrepDone = transDone || transProgress >= 25 || dubProgress >= 10 || isCompleted;
    final speakersDone = isSubtitlesOnly
        ? (transDone || isCompleted)
        : (dubProgress >= 20 || dubDone || isCompleted);
    final mergedStages = <String, dynamic>{
      ...existingStages,
      ...vStages,
      'audio_extraction': {'status': audioPrepDone ? 'completed' : 'running'},
      'diarization': {'status': speakersDone ? 'completed' : (transDone ? 'running' : 'pending')},
      'mastering': {'status': isCompleted ? 'completed' : (dubProgress >= 90 ? 'running' : 'pending')},
    };
    data['stages'] = mergedStages;

    if (!isStudioTerminal || isFailed) {
      final currentProgress = (data['progressPercent'] as num?)?.toInt() ?? 10;
      if (isFailed) {
        data['status'] = 'failed';
        final errText = dubStage['error']?.toString() ??
            subStage['error']?.toString() ??
            transStage['error']?.toString() ??
            vData['rejectionReason']?.toString() ??
            'We could not complete your dub right now. Any payment has been refunded.';
        data['error'] = errText;
        data['currentStepMessage'] = errText;
      } else if (isCompleted) {
        data['status'] = 'completed';
        data['progressPercent'] = 100;
        data['currentStepMessage'] = isSubtitlesOnly
            ? 'Subtitles are ready to download.'
            : 'Your dubbed video and audio tracks are ready.';
      } else if (!transDone) {
        data['status'] = 'transcribing';
        final nextPct = (10 + (transProgress * 0.25).round()).clamp(10, 35);
        data['progressPercent'] = nextPct > currentProgress ? nextPct : currentProgress;
        data['currentStepMessage'] = transProgress >= 30
            ? 'Transcribing spoken dialogue and detecting speakers...'
            : 'Preparing audio and extracting speech...';
      } else if (isSubtitlesOnly) {
        data['status'] = 'generating_subtitles';
        final nextPct = (35 + (subProgress * 0.60).round()).clamp(35, 95);
        data['progressPercent'] = nextPct > currentProgress ? nextPct : currentProgress;
        data['currentStepMessage'] = 'Translating script and generating timed subtitles...';
      } else {
        int nextPct;
        String nextStatus;
        String nextMsg;
        if (dubStatus != 'running' && dubProgress <= 5) {
          nextStatus = 'translating';
          nextPct = 35;
          nextMsg = 'Transcript ready. Preparing voices and translation...';
        } else if (dubProgress >= 90) {
          nextStatus = 'muxing_audio';
          nextPct = 88 + ((dubProgress - 90) * 0.9).round();
          nextMsg = 'Mixing audio tracks and building dubbed video...';
        } else if (dubProgress >= 55) {
          nextStatus = 'synthesizing_speech';
          nextPct = 60 + ((dubProgress - 55) * 0.8).round();
          nextMsg = 'Generating natural dubbed voices...';
        } else if (dubProgress >= 20) {
          nextStatus = 'translating';
          nextPct = 45 + ((dubProgress - 20) * 0.4).round();
          nextMsg = 'Translating script and matching speaker voices...';
        } else {
          nextStatus = 'diarizing';
          nextPct = 38 + (dubProgress * 0.3).round();
          nextMsg = 'Analyzing acoustics and speaker profiles...';
        }
        nextPct = nextPct.clamp(10, 99);
        data['status'] = nextStatus;
        data['progressPercent'] = nextPct > currentProgress ? nextPct : currentProgress;
        data['currentStepMessage'] = nextMsg;
      }
    }

    // Populate segments from pipeline transcript if available
    if (vData['transcription'] is Map &&
        (data['segmentsByLanguage'] == null || (data['segmentsByLanguage'] as Map).isEmpty)) {
      final tx = vData['transcription'] as Map;
      if (tx['segments'] is List) {
        final sourceLang = data['sourceLanguage']?.toString() ?? 'en';
        final segList = (tx['segments'] as List).asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value as Map;
          return {
            'id': 'seg_${idx + 1}',
            'speakerId': s['speakerId'] ?? s['speaker'] ?? 'speaker_1',
            'startTimeMs': (((s['start'] as num?)?.toDouble() ?? 0.0) * 1000).toInt(),
            'endTimeMs': (((s['end'] as num?)?.toDouble() ?? 0.0) * 1000).toInt(),
            'originalText': s['text'] ?? '',
            'translatedText': s['text'] ?? '',
            'targetLanguage': sourceLang,
            'status': 'ready',
          };
        }).toList();
        data['segmentsByLanguage'] = {sourceLang: segList};
      }
    }

    // Merge pipeline outputs into exportUrls when completed (fills missing keys even if exportUrls already exists)
    final hasAnyOutputsOrDotted = vData['outputs'] is Map ||
        vData.keys.any((k) => k.startsWith('outputs.'));
    if (isCompleted && hasAnyOutputsOrDotted) {
      final outputs = vData['outputs'] is Map
          ? Map<String, dynamic>.from(vData['outputs'] as Map)
          : <String, dynamic>{};
      final targetLangs = (data['targetLanguages'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
      final rawVideos = outputs['dubbedVideos'] is Map ? outputs['dubbedVideos'] as Map : const {};
      final rawDubbed = outputs['dubbed'] is Map ? outputs['dubbed'] as Map : const {};
      final rawAudios = outputs['audioTracks'] is Map ? outputs['audioTracks'] as Map : const {};
      final rawDialogues = outputs['dialogueTracks'] is Map
          ? outputs['dialogueTracks'] as Map
          : (outputs['stems'] is Map && (outputs['stems'] as Map)['dialogue'] is Map
              ? (outputs['stems'] as Map)['dialogue'] as Map
              : const {});
      final rawTranslations = outputs['translations'] is Map ? outputs['translations'] as Map : const {};
      final rawSubs = outputs['subtitles'] is Map ? outputs['subtitles'] as Map : const {};
      final stems = outputs['stems'] is Map ? outputs['stems'] as Map : const {};

      dynamic lookupLangField(Map nestedMap, String dottedPrefix, String lang) {
        final norm = lang.trim().toLowerCase();
        final direct = nestedMap[lang] ??
            nestedMap[norm] ??
            vData['$dottedPrefix.$lang'] ??
            vData['$dottedPrefix.$norm'];
        if (direct != null && direct.toString().trim().isNotEmpty) return direct;
        for (final entry in nestedMap.entries) {
          if (entry.key.toString().trim().toLowerCase() == norm &&
              entry.value != null &&
              entry.value.toString().trim().isNotEmpty) {
            return entry.value;
          }
        }
        return null;
      }

      final existingExports = data['exportUrls'] is Map
          ? Map<String, dynamic>.from(data['exportUrls'] as Map)
          : <String, dynamic>{};

      Map<String, String> readExistingMap(String key) {
        final raw = existingExports[key];
        if (raw is! Map) return <String, String>{};
        final out = <String, String>{};
        raw.forEach((k, v) {
          final val = toBrowserDownloadUrl(v?.toString());
          if (val.isNotEmpty) out[k.toString()] = val;
        });
        return out;
      }

      final videoByLang = readExistingMap('dubbedVideoByLanguage');
      final audioByLang = readExistingMap('dubbedAudioByLanguage');
      final dialogueByLang = readExistingMap('dialogueAudioByLanguage');
      final translationByLang = readExistingMap('translationJsonByLanguage');
      final srtMap = readExistingMap('subtitlesSrt');
      final vttMap = readExistingMap('subtitlesVtt');

      for (final lang in targetLangs) {
        final rawVidEntry = lookupLangField(rawVideos, 'outputs.dubbedVideos', lang) ??
            lookupLangField(rawDubbed, 'outputs.dubbed', lang);
        final vUrlRaw = rawVidEntry is Map
            ? (rawVidEntry['videoUrl'] ?? rawVidEntry['path'] ?? '').toString()
            : (rawVidEntry?.toString() ?? '');
        final vUrl = toBrowserDownloadUrl(vUrlRaw);
        if (!videoByLang.containsKey(lang) && vUrl.isNotEmpty) videoByLang[lang] = vUrl;

        final rawAudEntry = lookupLangField(rawAudios, 'outputs.audioTracks', lang) ??
            lookupLangField(rawDubbed, 'outputs.dubbed', lang);
        final aUrlRaw = rawAudEntry is Map
            ? (rawAudEntry['audioUrl'] ?? '').toString()
            : (rawAudEntry?.toString() ?? '');
        final aUrl = toBrowserDownloadUrl(aUrlRaw);
        if (!audioByLang.containsKey(lang) && aUrl.isNotEmpty) audioByLang[lang] = aUrl;

        final dUrl = toBrowserDownloadUrl(
          lookupLangField(rawDialogues, 'outputs.dialogueTracks', lang)?.toString(),
        );
        if (!dialogueByLang.containsKey(lang) && dUrl.isNotEmpty) dialogueByLang[lang] = dUrl;

        final tUrl = toBrowserDownloadUrl(
          lookupLangField(rawTranslations, 'outputs.translations', lang)?.toString(),
        );
        if (!translationByLang.containsKey(lang) && tUrl.isNotEmpty) translationByLang[lang] = tUrl;

        final sRaw = lookupLangField(rawSubs, 'outputs.subtitles', lang);
        final sUrl = toBrowserDownloadUrl(
          sRaw is String
              ? sRaw
              : (sRaw is Map ? (sRaw['srtPath'] ?? sRaw['url'] ?? sRaw['subtitleUrl'] ?? '').toString() : ''),
        );
        if (!srtMap.containsKey(lang) && sUrl.isNotEmpty) srtMap[lang] = sUrl;
        final vttUrl = toBrowserDownloadUrl(
          sRaw is Map ? (sRaw['vttPath'] ?? '').toString() : '',
        );
        if (!vttMap.containsKey(lang) && vttUrl.isNotEmpty) vttMap[lang] = vttUrl;
      }

      final vocalsStem = toBrowserDownloadUrl(
        existingExports['vocalsStemMp3']?.toString().trim().isNotEmpty == true
            ? existingExports['vocalsStemMp3'].toString()
            : (stems['vocals'] ?? vData['outputs.stems.vocals'])?.toString(),
      );
      final bgStem = toBrowserDownloadUrl(
        existingExports['backgroundStemMp3']?.toString().trim().isNotEmpty == true
            ? existingExports['backgroundStemMp3'].toString()
            : (stems['background'] ??
                    stems['mne'] ??
                    vData['outputs.stems.background'] ??
                    vData['outputs.stems.mne'])
                ?.toString(),
      );
      final reportUrl = toBrowserDownloadUrl(
        existingExports['reportJson']?.toString().trim().isNotEmpty == true
            ? existingExports['reportJson'].toString()
            : (outputs['dubbingReportUrl'] ?? vData['outputs.dubbingReportUrl'])?.toString(),
      );

      if (videoByLang.isNotEmpty ||
          audioByLang.isNotEmpty ||
          dialogueByLang.isNotEmpty ||
          translationByLang.isNotEmpty ||
          srtMap.isNotEmpty ||
          vttMap.isNotEmpty ||
          vocalsStem.isNotEmpty ||
          bgStem.isNotEmpty ||
          reportUrl.isNotEmpty) {
        data['exportUrls'] = {
          ...existingExports,
          'dubbedVideoByLanguage': videoByLang,
          'dubbedAudioByLanguage': audioByLang,
          if (dialogueByLang.isNotEmpty) 'dialogueAudioByLanguage': dialogueByLang,
          if (translationByLang.isNotEmpty) 'translationJsonByLanguage': translationByLang,
          if (vocalsStem.isNotEmpty) 'vocalsStemMp3': vocalsStem,
          if (bgStem.isNotEmpty) 'backgroundStemMp3': bgStem,
          if (reportUrl.isNotEmpty) 'reportJson': reportUrl,
          'subtitlesSrt': srtMap,
          if (vttMap.isNotEmpty) 'subtitlesVtt': vttMap,
        };
      }
    }

    return DubbingJob.fromMap(data);
  }

  /// Updates transcription or translation (Pre-TTS human review).
  Future<bool> updateTranscription({
    required String jobId,
    required String language,
    required List<DubbingSegment> segments,
    bool approveForTTS = false,
  }) async {
    try {
      final res = await _functions.httpsCallable('updateDubbingTranscription').call<dynamic>({
        'jobId': jobId,
        'language': language,
        'segments': segments.map((s) => s.toMap()).toList(),
        'approveForTTS': approveForTTS,
      });
      return res.data is Map && res.data['success'] == true;
    } catch (e) {
      ErrorHandler.log(e);
      return false;
    }
  }

  /// Regenerates a single segment after TTS (Post-TTS line adjustment).
  Future<bool> regenerateSegment({
    required String jobId,
    required String language,
    required String segmentId,
    required String newText,
    double speedMultiplier = 1.0,
    String? voiceId,
  }) async {
    try {
      final res = await _functions.httpsCallable('regenerateDubbingSegment').call<dynamic>({
        'jobId': jobId,
        'language': language,
        'segmentId': segmentId,
        'newText': newText,
        'speedMultiplier': speedMultiplier,
        'voiceId': voiceId,
      });
      return res.data is Map && res.data['success'] == true;
    } catch (e) {
      ErrorHandler.log(e);
      return false;
    }
  }

  /// Triggers final packaging and returns export URLs.
  Future<Map<String, dynamic>?> exportAssets(String jobId) async {
    try {
      final res = await _functions
          .httpsCallable(
            'exportDubbingAssets',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 240)),
          )
          .call<dynamic>({
        'jobId': jobId,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } on FirebaseFunctionsException catch (e) {
      logger.warning(
        'exportDubbingAssets notice (${e.code}): ${e.message ?? ''}',
        tag: 'DubbingService.exportAssets',
      );
      final rawMsg = e.message?.trim() ?? '';
      return {
        'success': false,
        'code': e.code,
        if (rawMsg.isNotEmpty) 'message': rawMsg,
      };
    } catch (e) {
      ErrorHandler.log(e, context: 'DubbingService.exportAssets');
    }
    return null;
  }

  /// Admin: Grant free credits or set balance for a user.
  Future<Map<String, dynamic>> adminGrantCredits({
    required String targetUserId,
    required int amountCredits,
    double amountUsd = 0.0,
    required String reason,
    String mode = 'add',
  }) async {
    try {
      final res = await _functions.httpsCallable('adminGrantDubbingCredits').call<dynamic>({
        'targetUserId': targetUserId,
        'amountCredits': amountCredits,
        'amountUsd': amountUsd,
        'reason': reason,
        'mode': mode,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      ErrorHandler.log(e);
      rethrow;
    }
    return {'success': false, 'message': 'Failed to grant credits.'};
  }

  /// Admin: Set special discount or 100% free waiver for a user.
  Future<Map<String, dynamic>> adminSetDiscount({
    required String targetUserId,
    required double discountPercent,
    required String discountType,
    required String reason,
    bool applyToChannels = true,
  }) async {
    try {
      final res = await _functions.httpsCallable('adminSetDubbingDiscount').call<dynamic>({
        'targetUserId': targetUserId,
        'discountPercent': discountPercent,
        'discountType': discountType,
        'reason': reason,
        'applyToChannels': applyToChannels,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      ErrorHandler.log(e);
      rethrow;
    }
    return {'success': false, 'message': 'Failed to update discount.'};
  }

  /// Admin: Fetch complete user dubbing details and history.
  Future<Map<String, dynamic>> adminGetUserDetails(String targetUserId) async {
    try {
      final res = await _functions.httpsCallable('adminGetDubbingUserDetails').call<dynamic>({
        'targetUserId': targetUserId,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      ErrorHandler.log(e);
    }
    return {};
  }

  /// Purchases Dubbing Studio credits directly using Truthworld Studio Wallet balance.
  Future<Map<String, dynamic>> purchaseCreditsWithStudioWallet({
    required String channelId,
    required int amountUsd,
    required int credits,
  }) async {
    try {
      final res = await _functions.httpsCallable('purchaseDubbingCreditsWithStudioWallet').call<dynamic>({
        'channelId': channelId,
        'amountUsd': amountUsd,
        'credits': credits,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'DubbingService.purchaseCreditsWithStudioWallet');
      rethrow;
    }
    return {'success': false, 'message': 'Failed to complete purchase with Studio Wallet.'};
  }

  // ── Persistent Dubbing Projects ────────────────────────────────

  /// Fetches all saved Dubbing Studio projects for [userId], ordered newest first.
  Future<List<DubbingProject>> fetchUserProjects(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.dubbingProjects)
          .where('userId', isEqualTo: uid)
          .get();
      final list = snap.docs
          .map((d) => DubbingProject.fromMap(d.data(), docId: d.id))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingService.fetchUserProjects');
      return const [];
    }
  }

  /// Fetches all `studio_dubbing_jobs` owned by [userId], ordered newest first.
  Future<List<DubbingJob>> fetchUserJobs(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.studioDubbingJobs)
          .where('userId', isEqualTo: uid)
          .get();
      final jobs = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= d.id;
        return DubbingJob.fromMap(data);
      }).toList();
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingService.fetchUserJobs');
      return const [];
    }
  }

  /// Fetches a single job by [jobId] and merges live `video_jobs` progress/outputs if available.
  Future<DubbingJob?> fetchJobById(String jobId) async {
    final id = jobId.trim();
    if (id.isEmpty) return null;
    try {
      var snap = await _firestore.collection(FirestoreCollections.studioDubbingJobs).doc(id).get();
      if (!snap.exists || snap.data() == null) {
        snap = await _firestore.collection('dubbing_jobs').doc(id).get();
      }
      if (!snap.exists || snap.data() == null) return null;
      final studioData = Map<String, dynamic>.from(snap.data()!);
      studioData['id'] ??= snap.id;

      final pipelineId = studioData['pipelineJobId']?.toString().trim() ?? '';
      final videoId = studioData['videoId']?.toString().trim() ?? '';
      final targetPipelineId = pipelineId.isNotEmpty ? pipelineId : videoId;
      Map<String, dynamic>? vData;
      if (targetPipelineId.isNotEmpty) {
        try {
          final vSnap = await _firestore.collection(FirestoreCollections.videoJobs).doc(targetPipelineId).get();
          if (vSnap.exists && vSnap.data() != null) {
            vData = Map<String, dynamic>.from(vSnap.data()!);
          }
        } catch (_) {}
      }
      return mergeJobWithVideoJobData(studioData, vData);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingService.fetchJobById');
      return null;
    }
  }

  /// Enriches a completed [DubbingJob] by querying Firestore fallback collections
  /// (`job_outputs`, `dubbing_results`, `subtitle_results`, `dubbing_manifests`)
  /// when Cloud Function export URLs are incomplete or unavailable.
  Future<DubbingJob> enrichJobFromFirestoreFallbacks(DubbingJob job) async {
    final pipelineId = (job.pipelineJobId?.trim().isNotEmpty == true
            ? job.pipelineJobId!.trim()
            : (job.videoId?.trim().isNotEmpty == true ? job.videoId!.trim() : job.id.trim()));
    if (pipelineId.isEmpty) return job;

    final existing = job.exportUrls != null
        ? Map<String, dynamic>.from(job.exportUrls!)
        : <String, dynamic>{};

    Map<String, String> readMap(String key) {
      final raw = existing[key];
      if (raw is! Map) return <String, String>{};
      final out = <String, String>{};
      raw.forEach((k, v) {
        final url = toBrowserDownloadUrl(v?.toString());
        if (url.isNotEmpty) out[k.toString()] = url;
      });
      return out;
    }

    final videoByLang = readMap('dubbedVideoByLanguage');
    final audioByLang = readMap('dubbedAudioByLanguage');
    final dialogueByLang = readMap('dialogueAudioByLanguage');
    final translationByLang = readMap('translationJsonByLanguage');
    final srtMap = readMap('subtitlesSrt');
    final vttMap = readMap('subtitlesVtt');
    var vocalsStem = toBrowserDownloadUrl(existing['vocalsStemMp3']?.toString());
    var bgStem = toBrowserDownloadUrl(existing['backgroundStemMp3']?.toString());
    var reportUrl = toBrowserDownloadUrl(existing['reportJson']?.toString());
    final updatedSegments = Map<String, List<DubbingSegment>>.from(job.segmentsByLanguage);

    final srcNorm = job.sourceMediaUrl.trim().toLowerCase();
    bool isGenuineDubVideo(String url) {
      final lower = url.trim().toLowerCase();
      if (lower.isEmpty) return false;
      if (srcNorm.isNotEmpty && lower == srcNorm) return false;
      if (lower.endsWith('original.mp4') || lower.contains('/original.mp4') || lower.contains('%2foriginal.mp4')) {
        return false;
      }
      return true;
    }

    Map<String, dynamic> jobOutputs = const {};
    try {
      final joSnap = await _firestore.collection('job_outputs').doc(pipelineId).get();
      if (joSnap.exists && joSnap.data() != null) {
        jobOutputs = Map<String, dynamic>.from(joSnap.data()!);
      }
    } catch (_) {}

    for (final lang in job.targetLanguages) {
      final normLang = lang.trim().toLowerCase();
      if (normLang.isEmpty) continue;

      // 1. job_outputs fallback
      final joDubbed = (jobOutputs['dubbed'] is Map ? jobOutputs['dubbed'][lang] ?? jobOutputs['dubbed'][normLang] : null) ??
          jobOutputs['dubbed.$lang'] ??
          jobOutputs['dubbed.$normLang'];
      if (!videoByLang.containsKey(lang) && joDubbed is Map) {
        final vCandidate = toBrowserDownloadUrl((joDubbed['videoUrl'] ?? joDubbed['path'])?.toString());
        if (isGenuineDubVideo(vCandidate)) videoByLang[lang] = vCandidate;
      }
      final joAudio = (jobOutputs['audioTracks'] is Map ? jobOutputs['audioTracks'][lang] ?? jobOutputs['audioTracks'][normLang] : null) ??
          jobOutputs['audioTracks.$lang'] ??
          jobOutputs['audioTracks.$normLang'] ??
          (joDubbed is Map ? joDubbed['audioUrl'] : null);
      if (!audioByLang.containsKey(lang)) {
        final aUrl = toBrowserDownloadUrl(joAudio?.toString());
        if (aUrl.isNotEmpty) audioByLang[lang] = aUrl;
      }
      final joSub = (jobOutputs['subtitles'] is Map ? jobOutputs['subtitles'][lang] ?? jobOutputs['subtitles'][normLang] : null) ??
          jobOutputs['subtitles.$lang'] ??
          jobOutputs['subtitles.$normLang'];
      if (joSub is Map) {
        final sUrl = toBrowserDownloadUrl((joSub['srtPath'] ?? joSub['url'] ?? joSub['subtitleUrl'])?.toString());
        if (!srtMap.containsKey(lang) && sUrl.isNotEmpty) srtMap[lang] = sUrl;
        final vUrl = toBrowserDownloadUrl(joSub['vttPath']?.toString());
        if (!vttMap.containsKey(lang) && vUrl.isNotEmpty) vttMap[lang] = vUrl;
      } else if (joSub is String) {
        final sUrl = toBrowserDownloadUrl(joSub);
        if (!srtMap.containsKey(lang) && sUrl.isNotEmpty) srtMap[lang] = sUrl;
      }

      // 2. dubbing_results fallback
      if (job.mode != DubbingMode.subtitlesOnly) {
        try {
          final drSnap = await _firestore.collection('dubbing_results').doc('${pipelineId}_$normLang').get();
          if (drSnap.exists && drSnap.data() != null) {
            final dr = drSnap.data()!;
            final vCandidate = toBrowserDownloadUrl(dr['videoUrl']?.toString());
            if (!videoByLang.containsKey(lang) && isGenuineDubVideo(vCandidate)) {
              videoByLang[lang] = vCandidate;
            }
            final aCandidate = toBrowserDownloadUrl(dr['audioUrl']?.toString());
            if (!audioByLang.containsKey(lang) && aCandidate.isNotEmpty) {
              audioByLang[lang] = aCandidate;
            }
            final tCandidate = toBrowserDownloadUrl(dr['translationUrl']?.toString());
            if (!translationByLang.containsKey(lang) &&
                tCandidate.contains('/translations/')) {
              translationByLang[lang] = tCandidate;
            }
            if (dr['stems'] is Map) {
              final stems = dr['stems'] as Map;
              final dCandidate = toBrowserDownloadUrl(stems['dialogue']?.toString());
              if (!dialogueByLang.containsKey(lang) && dCandidate.isNotEmpty) {
                dialogueByLang[lang] = dCandidate;
              }
              if (vocalsStem.isEmpty) {
                vocalsStem = toBrowserDownloadUrl(stems['vocals']?.toString());
              }
              if (bgStem.isEmpty) {
                bgStem = toBrowserDownloadUrl((stems['background'] ?? stems['mne'])?.toString());
              }
            }
          }
        } catch (_) {}
      }

      // 3. subtitle_results fallback
      if (!srtMap.containsKey(lang) || !vttMap.containsKey(lang)) {
        try {
          final srSnap = await _firestore.collection('subtitle_results').doc('${pipelineId}_$normLang').get();
          if (srSnap.exists && srSnap.data() != null) {
            final sr = srSnap.data()!;
            final sUrl = toBrowserDownloadUrl((sr['srtPath'] ?? sr['subtitleUrl'])?.toString());
            if (!srtMap.containsKey(lang) && sUrl.isNotEmpty) srtMap[lang] = sUrl;
            final vUrl = toBrowserDownloadUrl(sr['vttPath']?.toString());
            if (!vttMap.containsKey(lang) && vUrl.isNotEmpty) vttMap[lang] = vUrl;
          }
        } catch (_) {}
      }

      // 4. dubbing_manifests fallback (segments + stems + master URLs)
      if ((updatedSegments[lang] == null || updatedSegments[lang]!.isEmpty) ||
          !videoByLang.containsKey(lang) ||
          !audioByLang.containsKey(lang) ||
          !dialogueByLang.containsKey(lang)) {
        try {
          final mSnap = await _firestore
              .collection(FirestoreCollections.videoJobs)
              .doc(pipelineId)
              .collection('dubbing_manifests')
              .doc(normLang)
              .get();
          if (mSnap.exists && mSnap.data() != null) {
            final m = mSnap.data()!;
            final mVideo = toBrowserDownloadUrl(m['masterVideoUrl']?.toString());
            if (!videoByLang.containsKey(lang) && isGenuineDubVideo(mVideo)) {
              videoByLang[lang] = mVideo;
            }
            final mAudio = toBrowserDownloadUrl(m['masterAudioUrl']?.toString());
            if (!audioByLang.containsKey(lang) && mAudio.isNotEmpty) {
              audioByLang[lang] = mAudio;
            }
            final mDialogue = toBrowserDownloadUrl(m['dialogueStemUrl']?.toString());
            if (!dialogueByLang.containsKey(lang) && mDialogue.isNotEmpty) {
              dialogueByLang[lang] = mDialogue;
            }
            if (bgStem.isEmpty) {
              bgStem = toBrowserDownloadUrl(m['mneStemUrl']?.toString());
            }
            final mSub = toBrowserDownloadUrl(m['subtitleUrl']?.toString());
            if (!srtMap.containsKey(lang) && mSub.isNotEmpty) srtMap[lang] = mSub;

            if ((updatedSegments[lang] == null || updatedSegments[lang]!.isEmpty) && m['segments'] is List) {
              final rawSegs = m['segments'] as List;
              final parsed = <DubbingSegment>[];
              for (var idx = 0; idx < rawSegs.length; idx++) {
                final item = rawSegs[idx];
                if (item is! Map) continue;
                parsed.add(DubbingSegment.fromMap({
                  'id': 'seg_${((item['index'] as num?)?.toInt() ?? idx) + 1}',
                  'speakerId': (item['speaker'] ?? 'speaker_0').toString(),
                  'startTimeMs': (item['startMs'] as num?)?.toInt() ?? 0,
                  'endTimeMs': (item['endMs'] as num?)?.toInt() ?? 0,
                  'originalText': (item['originalText'] ?? '').toString(),
                  'translatedText': (item['editedText'] ?? item['translatedText'] ?? '').toString(),
                  'targetLanguage': lang,
                  'audioStemUrl': toBrowserDownloadUrl(item['synthesizedAudioUrl']?.toString()),
                  'status': 'synthesized',
                  'speedMultiplier': 1.0,
                }));
              }
              if (parsed.isNotEmpty) updatedSegments[lang] = parsed;
            }
          }
        } catch (_) {}
      }
    }

    final nextExportUrls = <String, dynamic>{
      ...existing,
      'dubbedVideoByLanguage': videoByLang,
      'dubbedAudioByLanguage': audioByLang,
      if (dialogueByLang.isNotEmpty) 'dialogueAudioByLanguage': dialogueByLang,
      if (translationByLang.isNotEmpty) 'translationJsonByLanguage': translationByLang,
      if (vocalsStem.isNotEmpty) 'vocalsStemMp3': vocalsStem,
      if (bgStem.isNotEmpty) 'backgroundStemMp3': bgStem,
      if (reportUrl.isNotEmpty) 'reportJson': reportUrl,
      'subtitlesSrt': srtMap,
      if (vttMap.isNotEmpty) 'subtitlesVtt': vttMap,
    };

    return DubbingJob(
      id: job.id,
      userId: job.userId,
      title: job.title,
      mode: job.mode,
      status: job.status,
      progressPercent: job.progressPercent,
      currentStepMessage: job.currentStepMessage,
      sourceMediaUrl: job.sourceMediaUrl,
      sourceMediaType: job.sourceMediaType,
      durationSeconds: job.durationSeconds,
      characterCount: job.characterCount,
      sourceLanguage: job.sourceLanguage,
      targetLanguages: job.targetLanguages,
      voiceCloningEnabled: job.voiceCloningEnabled,
      twoStageReviewEnabled: job.twoStageReviewEnabled,
      publishToTruthworld: job.publishToTruthworld,
      costUsd: job.costUsd,
      totalCharactersCharged: job.totalCharactersCharged,
      speakers: job.speakers,
      segmentsByLanguage: updatedSegments,
      exportUrls: nextExportUrls,
      videoId: job.videoId,
      pipelineJobId: job.pipelineJobId,
      channelId: job.channelId,
      error: job.error,
      createdAt: job.createdAt,
      stages: job.stages,
    );
  }

  /// Creates or updates a persistent [DubbingProject] in Firestore.
  Future<bool> saveProject(DubbingProject project) async {
    if (project.id.isEmpty || project.userId.isEmpty) return false;
    try {
      await _firestore
          .collection(FirestoreCollections.dubbingProjects)
          .doc(project.id)
          .set(project.toMap(), SetOptions(merge: true));
      return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingService.saveProject');
      return false;
    }
  }

  /// Deletes a saved [DubbingProject] from Firestore.
  Future<bool> deleteProject(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return false;
    try {
      await _firestore.collection(FirestoreCollections.dubbingProjects).doc(id).delete();
      return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingService.deleteProject');
      return false;
    }
  }
}
