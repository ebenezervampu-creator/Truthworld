import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin handling Truthworld AI subtitle generation, Cloud Function triggers,
/// live pipeline telemetry, per-language tracking, and cloud queue monitoring.
mixin SubtitlesAiMixin on SubtitlesControllerBase {
  Future<void> triggerSubtitlesGeneration({
    required List<String> targetLanguages,
    String priorityMode = 'accuracy',
  }) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return;
    }
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      showError('You must be signed in to generate subtitles.');
      return;
    }

    aiTargetLanguages.assignAll(targetLanguages);
    final initialStatuses = <String, String>{};
    for (final lang in targetLanguages) {
      initialStatuses[lang] = 'queued';
    }
    aiLanguageStatuses.assignAll(initialStatuses);

    final hasExistingSource = video.mediaSubtitles.isNotEmpty ||
        availableLanguages.isNotEmpty;

    isGeneratingAI.value = true;
    isAiJobPaused.value = false;
    aiJobProgress.value = hasExistingSource ? 35 : 15;
    aiCurrentStageName.value = hasExistingSource
        ? 'Neural Multilingual Translation'
        : 'Speech Extraction & Transcription';
    aiJobStatus.value = hasExistingSource
        ? 'Source transcript verified. Starting multilingual neural translation for ${targetLanguages.join(", ").toUpperCase()}...'
        : 'Initiating cloud speech pipeline...';

    for (final lang in targetLanguages) {
      aiLanguageStatuses[lang] =
          hasExistingSource ? 'translating' : 'transcribing';
    }

    startElapsedTimer();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    startQueueMonitor(video.id, nowMs);

    try {
      final token = await currentUser.getIdToken();
      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/triggerVideoAIFeatures',
      );

      var pipelineTriggered = false;
      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'videoId': video.id,
            'features': ['subtitles'],
            'targetLanguages': targetLanguages,
            'priorityMode': priorityMode,
            'autoChapters': false,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          pipelineTriggered = true;
          showSuccess(
            'Truthworld AI has started generating subtitles for ${targetLanguages.join(", ").toUpperCase()}!',
          );
          listenToAIJob(video.id, targetLanguages);
          return;
        } else {
          logger.warning(
            'triggerVideoAIFeatures returned HTTP ${response.statusCode}: ${response.body}',
            tag: SubtitlesControllerBase.subtitlesTag,
          );
        }
      } catch (httpError) {
        logger.warning(
          'triggerVideoAIFeatures HTTP failed, using Firestore fallback: $httpError',
          tag: SubtitlesControllerBase.subtitlesTag,
        );
      }

      if (!pipelineTriggered) {
        // Fallback: update Firestore document directly
        await firestore.collection('video_jobs').doc(video.id).set({
          'jobId': video.id,
          'videoId': video.id,
          'userId': currentUser.uid,
          'channelId':
              channelId.value.isNotEmpty ? channelId.value : currentUser.uid,
          'videoUrl': video.videoUrl,
          'fileName': video.title,
          'status': 'processing',
          'createdAt': nowMs,
          'updatedAt': nowMs,
          'executionPlan': {
            'jobId': video.id,
            'languages': targetLanguages,
            'generateSubtitles': true,
            'genLangSubs': true,
            'enablePath2': true,
            'priorityMode': priorityMode,
          },
          'stages': {
            'transcription': {
              'status': hasExistingSource ? 'completed' : 'running',
              'progress': hasExistingSource ? 100 : 20,
              'startedAt': nowMs,
              if (hasExistingSource) 'completedAt': nowMs,
            },
            'subtitles': {
              'status': 'running',
              'progress': hasExistingSource ? 35 : 10,
              'startedAt': nowMs,
            },
            'onDemandAI': {
              'status': 'running',
              'progress': hasExistingSource ? 35 : 15,
              'requestedFeatures': ['subtitles'],
              'requestedLanguages': targetLanguages,
              'startedAt': nowMs,
            },
          },
        }, SetOptions(merge: true));

        showSuccess(
          'AI subtitle job queued for ${targetLanguages.join(", ").toUpperCase()}!',
        );
        listenToAIJob(video.id, targetLanguages);
      }
    } catch (e) {
      logger.error('Error triggering AI subtitles', error: e, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to start AI subtitle generation. Please check your connection and try again.');
      isGeneratingAI.value = false;
      stopElapsedTimer();
    }
  }

  @override
  Future<void> checkAndResumeAIJob(String videoId) async {
    try {
      final doc = await firestore.collection('video_jobs').doc(videoId).get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final jobStatus = (data['status'] as String?)?.toLowerCase();
      final stages = (data['stages'] as Map<String, dynamic>?) ?? {};
      final onDemand = stages['onDemandAI'] as Map<String, dynamic>?;
      final onDemandStatus = (onDemand?['status'] as String?)?.toLowerCase();
      final outputs = (data['outputs'] as Map<String, dynamic>?) ?? {};
      final outputSubs = (outputs['subtitles'] as Map<String, dynamic>?) ?? {};

      final reqLangs = List<String>.from(
        onDemand?['requestedLanguages'] as List? ??
            (data['executionPlan']?['languages'] as List? ?? []),
      );

      final video = selectedVideo.value;
      final currentSubs = video?.mediaSubtitles ?? {};

      // If all requested target languages are already generated in outputs or video, complete immediately
      final allDone = reqLangs.isNotEmpty &&
          reqLangs.every((l) => outputSubs.containsKey(l) || currentSubs.containsKey(l));

      if (allDone || jobStatus == 'completed' || onDemandStatus == 'completed') {
        isGeneratingAI.value = false;
        aiJobProgress.value = 100;
        aiJobStatus.value = 'Subtitles generated successfully!';
        if (reqLangs.isNotEmpty) {
          aiTargetLanguages.assignAll(reqLangs);
          final finalStatuses = <String, String>{};
          for (final lang in reqLangs) {
            finalStatuses[lang] = 'completed';
          }
          aiLanguageStatuses.assignAll(finalStatuses);
        }
        await refreshSelectedVideoLocalization(reqLangs.isNotEmpty ? reqLangs.first : null);
        return;
      }

      // Check Failed or Cancelled states BEFORE processing check to avoid resurrecting dead jobs
      final isFailed = jobStatus == 'failed' ||
          onDemandStatus == 'failed' ||
          stages['subtitles']?['status']?.toString().toLowerCase() == 'failed' ||
          stages['dubbing']?['status']?.toString().toLowerCase() == 'failed';

      if (isFailed) {
        logger.info('Previous AI subtitle job failed, clearing generation state', tag: SubtitlesControllerBase.subtitlesTag);
        isGeneratingAI.value = false;
        aiJobProgress.value = 0;
        aiJobStatus.value = '';
        return;
      }

      final isCancelled = jobStatus == 'cancelled' ||
          onDemandStatus == 'cancelled' ||
          stages['subtitles']?['status']?.toString().toLowerCase() == 'cancelled';

      if (isCancelled) {
        logger.info('Previous AI subtitle job was cancelled, clearing generation state', tag: SubtitlesControllerBase.subtitlesTag);
        isGeneratingAI.value = false;
        aiJobProgress.value = 0;
        aiJobStatus.value = '';
        return;
      }

      final isProcessing = jobStatus == 'processing' ||
          jobStatus == 'queued' ||
          jobStatus == 'paused' ||
          onDemandStatus == 'running' ||
          onDemandStatus == 'queued' ||
          onDemandStatus == 'paused';

      if (isProcessing) {
        final createdAt = (data['createdAt'] as num?)?.toInt() ??
            (onDemand?['startedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Auto-recover stale jobs: if no progress updates for > 5 minutes, do not trap creator in progress screen
        final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? createdAt;
        if (now - updatedAt > 5 * 60 * 1000) {
          logger.warning('Stale AI subtitle job detected (>5m without updates), clearing UI state', tag: SubtitlesControllerBase.subtitlesTag);
          isGeneratingAI.value = false;
          aiJobProgress.value = 0;
          aiJobStatus.value = '';
          return;
        }

        if (reqLangs.isNotEmpty) {
          aiTargetLanguages.assignAll(reqLangs);
          final initialStatuses = <String, String>{};
          for (final lang in reqLangs) {
            initialStatuses[lang] = outputSubs.containsKey(lang) ? 'completed' : 'translating';
          }
          aiLanguageStatuses.assignAll(initialStatuses);
        }

        final hasExistingSource = (video != null &&
                (video.mediaSubtitles.isNotEmpty || video.transcriptionUrl.isNotEmpty)) ||
            stages['transcription']?['status'] == 'completed' ||
            stages['subtitles'] != null;

        isGeneratingAI.value = true;
        isAiJobPaused.value = jobStatus == 'paused' || onDemandStatus == 'paused';
        final rawProgress = (stages['subtitles']?['progress'] as num?)?.toInt() ??
            (onDemand?['progress'] as num?)?.toInt() ??
            (hasExistingSource ? 35 : 25);
        final progress = (hasExistingSource && rawProgress < 35) ? 35 : rawProgress;
        aiJobProgress.value = progress;
        aiCurrentStageName.value = hasExistingSource
            ? 'Neural Multilingual Translation'
            : 'Speech Extraction & Transcription';
        aiJobStatus.value = isAiJobPaused.value
            ? 'Subtitle generation is paused'
            : 'Processing AI subtitles ($progress%)...';

        startElapsedTimer();
        startQueueMonitor(videoId, createdAt);
        listenToAIJob(videoId, reqLangs);
      }
    } catch (e) {
      logger.warning(
        'Error checking existing AI subtitle job: $e',
        tag: SubtitlesControllerBase.subtitlesTag,
      );
    }
  }

  void listenToAIJob(String videoId, List<String> targetLanguages) {
    aiJobSubscription?.cancel();
    aiVideoSubscription?.cancel();

    void onSubtitlesFinished(List<String> finishedLangs) {
      if (!isGeneratingAI.value && aiJobProgress.value >= 100) return;
      isGeneratingAI.value = false;
      isAiJobPaused.value = false;
      aiJobProgress.value = 100;
      aiCurrentStageName.value = 'Precision Timestamp Alignment & VTT Export';
      aiJobStatus.value = 'Subtitles generated successfully!';
      for (final l in finishedLangs) {
        aiLanguageStatuses[l] = 'completed';
      }
      showSuccess(
        'Subtitles ready for ${finishedLangs.join(", ").toUpperCase()}!',
      );
      stopElapsedTimer();
      stopQueueMonitor();
      aiJobSubscription?.cancel();
      aiVideoSubscription?.cancel();
      final newlyGenerated = finishedLangs.firstWhere(
        (l) => l != (selectedVideo.value?.language ?? 'en'),
        orElse: () => finishedLangs.isNotEmpty ? finishedLangs.first : 'en',
      );
      refreshSelectedVideoLocalization(newlyGenerated);
    }

    // Direct Video Document Listener: Instantly detects when DubbingEngine writes subtitles to videos/{videoId}
    aiVideoSubscription = firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .snapshots()
        .listen((vSnap) {
      if (!vSnap.exists || vSnap.data() == null) return;
      final vData = vSnap.data()!;
      final mediaSubtitles = (vData['media'] != null && vData['media']['subtitles'] != null)
          ? Map<String, String>.from(vData['media']['subtitles'] as Map)
          : (vData['subtitles'] != null
              ? Map<String, String>.from(vData['subtitles'] as Map)
              : (vData['mediaSubtitles'] != null
                  ? Map<String, String>.from(vData['mediaSubtitles'] as Map)
                  : <String, String>{}));

      final langs = aiTargetLanguages.isNotEmpty
          ? aiTargetLanguages.toList()
          : targetLanguages;
      if (langs.isNotEmpty && langs.every(mediaSubtitles.containsKey)) {
        onSubtitlesFinished(langs);
      }
    }, onError: (_) {});

    // Video Job Listener: Tracks real-time stage progress across cloud pipeline
    aiJobSubscription = firestore
        .collection('video_jobs')
        .doc(videoId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;
      final data = snapshot.data()!;
      final jobStatus = (data['status'] as String?)?.toLowerCase();
      final stages = (data['stages'] as Map<String, dynamic>?) ?? {};
      final onDemand = stages['onDemandAI'] as Map<String, dynamic>?;
      final dubbing = stages['dubbing'] as Map<String, dynamic>?;
      final transcription = stages['transcription'] as Map<String, dynamic>?;
      final subtitlesStage = stages['subtitles'] as Map<String, dynamic>?;

      // Extract resolved target languages
      final langs = targetLanguages.isNotEmpty
          ? targetLanguages
          : List<String>.from(
              onDemand?['requestedLanguages'] as List? ??
                  (data['executionPlan']?['languages'] as List? ?? []),
            );
      if (langs.isNotEmpty && aiTargetLanguages.isEmpty) {
        aiTargetLanguages.assignAll(langs);
      }

      // Check outputs for completed per-language subtitles
      final outputs = (data['outputs'] as Map<String, dynamic>?) ?? {};
      final outputSubs = (outputs['subtitles'] as Map<String, dynamic>?) ?? {};
      final currentSubs = selectedVideo.value?.mediaSubtitles ?? {};

      // A target language has final subtitles ready if present in outputs or video doc
      final hasAllFinalSubs = langs.isNotEmpty &&
          langs.every((l) =>
              outputSubs.containsKey(l) ||
              currentSubs.containsKey(l));

      // Handle Cancelled State
      if (jobStatus == 'cancelled' ||
          onDemand?['status']?.toString().toLowerCase() == 'cancelled') {
        isGeneratingAI.value = false;
        isAiJobPaused.value = false;
        aiJobStatus.value = 'Subtitle generation was cancelled.';
        stopElapsedTimer();
        stopQueueMonitor();
        aiJobSubscription?.cancel();
        aiVideoSubscription?.cancel();
        return;
      }

      // Handle Paused State
      if (jobStatus == 'paused' ||
          onDemand?['status']?.toString().toLowerCase() == 'paused') {
        isAiJobPaused.value = true;
        aiJobStatus.value = 'Subtitle generation is paused.';
        return;
      } else {
        isAiJobPaused.value = false;
      }

      final isDubbingCompletedOrSkipped =
          dubbing?['status']?.toString().toLowerCase() == 'completed' ||
          dubbing?['status']?.toString().toLowerCase() == 'skipped';

      // Handle Completed State
      if (jobStatus == 'completed' ||
          onDemand?['status']?.toString().toLowerCase() == 'completed' ||
          subtitlesStage?['status']?.toString().toLowerCase() == 'completed' ||
          (isDubbingCompletedOrSkipped && hasAllFinalSubs) ||
          hasAllFinalSubs) {
        onSubtitlesFinished(langs);
        return;
      }

      // Handle Failed or Expired Zombie State
      final isSubtitlesFailed = subtitlesStage?['status']?.toString().toLowerCase() == 'failed';
      final isDubbingFailed = (data['executionPlan']?['generateDubbing'] == true) &&
          dubbing?['status']?.toString().toLowerCase() == 'failed';

      final now = DateTime.now().millisecondsSinceEpoch;
      int? jobTs;
      if (onDemand?['startedAt'] is num) {
        jobTs = (onDemand!['startedAt'] as num).toInt();
      } else if (data['updatedAt'] is num) {
        jobTs = (data['updatedAt'] as num).toInt();
      } else if (data['createdAt'] is num) {
        jobTs = (data['createdAt'] as num).toInt();
      }
      final isZombie = jobTs != null && (now - jobTs) > 5 * 60 * 1000;

      if (isZombie && !hasAllFinalSubs) {
        isGeneratingAI.value = false;
        aiJobStatus.value = 'Ready to generate subtitles.';
        stopElapsedTimer();
        stopQueueMonitor();
        aiJobSubscription?.cancel();
        aiVideoSubscription?.cancel();
        return;
      }

      if (jobStatus == 'failed' ||
          onDemand?['status']?.toString().toLowerCase() == 'failed' ||
          isSubtitlesFailed ||
          isDubbingFailed) {
        isGeneratingAI.value = false;
        aiJobStatus.value = 'AI generation encountered an issue. You can regenerate anytime.';
        stopElapsedTimer();
        stopQueueMonitor();
        aiJobSubscription?.cancel();
        aiVideoSubscription?.cancel();
        return;
      }

      // ─── DYNAMIC MULTI-STAGE PROGRESS RESOLUTION ───
      isGeneratingAI.value = true;

      final transStatus = (transcription?['status'] as String?)?.toLowerCase();
      final transProgress = (transcription?['progress'] as num?)?.toInt() ?? 0;
      final dubStatus = (dubbing?['status'] as String?)?.toLowerCase();
      final dubProgress = (dubbing?['progress'] as num?)?.toInt() ?? 0;
      final subProgress = (subtitlesStage?['progress'] as num?)?.toInt() ?? 0;
      final onDemandProgress = (onDemand?['progress'] as num?)?.toInt() ?? 0;

      final video = selectedVideo.value;
      final hasExistingSource = (video != null &&
              (video.mediaSubtitles.isNotEmpty || video.transcriptionUrl.isNotEmpty)) ||
          transStatus == 'completed' ||
          subtitlesStage != null;

      // Check per-language translation stages
      var activeLangProgressSum = 0;
      var activeLangCount = 0;
      for (final l in langs) {
        if (outputSubs.containsKey(l) || currentSubs.containsKey(l)) {
          aiLanguageStatuses[l] = 'completed';
          activeLangProgressSum += 100;
          activeLangCount++;
        } else {
          final transStage = stages['translating_$l'] as Map<String, dynamic>?;
          if (transStage != null) {
            final p = (transStage['progress'] as num?)?.toInt() ?? 0;
            activeLangProgressSum += p;
            activeLangCount++;
            aiLanguageStatuses[l] = (p >= 100 || transStage['status'] == 'completed')
                ? 'completed'
                : 'translating';
          } else {
            aiLanguageStatuses[l] = 'translating';
          }
        }
      }

      final avgLangProgress = activeLangCount > 0 ? (activeLangProgressSum / activeLangCount).round() : 0;

      int calculatedProgress;
      String currentStageTitle;
      String detailedStatus;

      if (!hasExistingSource && transStatus != 'completed' && dubStatus != 'running' && dubStatus != 'completed') {
        // Stage 1: Speech Extraction & Transcription (Only for brand new videos without audio transcript)
        currentStageTitle = 'Speech Extraction & Transcription';
        final base = transProgress > 0 ? transProgress : onDemandProgress;
        calculatedProgress = (base * 0.35).round().clamp(10, 35);
        detailedStatus = 'Extracting audio & transcribing dialogue ($calculatedProgress%)...';

        for (final l in langs) {
          aiLanguageStatuses[l] = 'transcribing';
        }
      } else if (subProgress < 75 && dubProgress < 75 && !hasAllFinalSubs) {
        // Stage 2: Neural Multilingual Translation
        currentStageTitle = 'Neural Multilingual Translation';
        final translationMapped = 35 + (avgLangProgress * 0.40).round();
        final rawProgress = math.max(subProgress, math.max(onDemandProgress, translationMapped));
        calculatedProgress = math.max(aiJobProgress.value, rawProgress).clamp(35, 74);
        detailedStatus = 'Translating dialogue into ${langs.length} target languages ($calculatedProgress%)...';
      } else {
        // Stage 3: Timestamp Alignment & VTT Export
        currentStageTitle = 'Precision Timestamp Alignment & VTT Export';
        final effective = math.max(subProgress, math.max(dubProgress, onDemandProgress));
        calculatedProgress = (effective >= 75)
            ? math.max(aiJobProgress.value, effective).clamp(75, 95)
            : (75 + (avgLangProgress * 0.20).round()).clamp(75, 95);
        detailedStatus = 'Formatting timestamps & generating standard VTT/SRT ($calculatedProgress%)...';

        for (final l in langs) {
          if (outputSubs.containsKey(l) || currentSubs.containsKey(l)) {
            aiLanguageStatuses[l] = 'completed';
          } else {
            aiLanguageStatuses[l] = 'aligning';
          }
        }
      }

      aiCurrentStageName.value = currentStageTitle;
      aiJobProgress.value = calculatedProgress;
      aiJobStatus.value = detailedStatus;
    }, onError: (e, stackTrace) {
      logger.error('Error listening to AI job', error: e, stackTrace: stackTrace, tag: SubtitlesControllerBase.subtitlesTag);
      isGeneratingAI.value = false;
      aiJobStatus.value = 'AI generation encountered a connection issue.';
      stopElapsedTimer();
      stopQueueMonitor();
      aiJobSubscription?.cancel();
      aiVideoSubscription?.cancel();
    });
  }

  @override
  Future<void> cancelAIJob() async {
    final video = selectedVideo.value;
    if (video == null) return;

    isCancellingAI.value = true;
    try {
      await firestore.collection('video_jobs').doc(video.id).set({
        'status': 'cancelled',
        'stages': {
          'onDemandAI': {
            'status': 'cancelled',
            'cancelledAt': DateTime.now().millisecondsSinceEpoch,
          },
          'subtitles': {
            'status': 'cancelled',
          },
          'dubbing': {
            'status': 'cancelled',
          },
          'transcription': {
            'status': 'cancelled',
          },
        },
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      isGeneratingAI.value = false;
      isAiJobPaused.value = false;
      aiJobProgress.value = 0;
      aiJobStatus.value = '';
      stopElapsedTimer();
      stopQueueMonitor();
      aiJobSubscription?.cancel();
      aiVideoSubscription?.cancel();
      showSuccess('Subtitle generation was cancelled.');
    } catch (e) {
      logger.error('Error cancelling AI job', error: e, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to cancel generation. Please try again.');
    } finally {
      isCancellingAI.value = false;
    }
  }

  @override
  Future<void> togglePauseAIJob() async {
    final video = selectedVideo.value;
    if (video == null) return;

    isPausingAI.value = true;
    try {
      final willPause = !isAiJobPaused.value;
      final targetStatus = willPause ? 'paused' : 'processing';
      final onDemandStatus = willPause ? 'paused' : 'running';

      await firestore.collection('video_jobs').doc(video.id).set({
        'status': targetStatus,
        'stages': {
          'onDemandAI': {
            'status': onDemandStatus,
            'pausedAt': willPause ? DateTime.now().millisecondsSinceEpoch : null,
          },
          'subtitles': {
            'status': willPause ? 'paused' : 'running',
          },
        },
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      isAiJobPaused.value = willPause;
      if (willPause) {
        aiJobStatus.value = 'Subtitle generation paused.';
        showSuccess('Subtitle generation paused.');
      } else {
        final currentProg = aiJobProgress.value;
        aiJobStatus.value = 'Processing AI subtitles ($currentProg%)...';
        showSuccess('Subtitle generation resumed.');
      }
    } catch (e) {
      logger.error('Error toggling pause for AI job', error: e, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to update pause state. Please try again.');
    } finally {
      isPausingAI.value = false;
    }
  }

  @override
  Future<void> regenerateAIJob() async {
    final video = selectedVideo.value;
    if (video == null) return;

    isRegeneratingAI.value = true;
    try {
      // Clear previous job document state
      await firestore.collection('video_jobs').doc(video.id).delete();

      final langs = aiTargetLanguages.isNotEmpty
          ? aiTargetLanguages.toList()
          : <String>['en', 'hi', 'te', 'es'];

      await triggerSubtitlesGeneration(targetLanguages: langs);
      showSuccess('AI subtitle generation restarted.');
    } catch (e) {
      logger.error('Error regenerating AI job', error: e, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to restart generation. Please try again.');
    } finally {
      isRegeneratingAI.value = false;
    }
  }

  void startElapsedTimer() {
    aiElapsedTimer?.cancel();
    aiElapsedSeconds.value = 0;
    aiElapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isAiJobPaused.value) {
        aiElapsedSeconds.value++;

        // Hard timeout guard: subtitles must never spin indefinitely (5 minutes max)
        if (aiElapsedSeconds.value > 300) {
          logger.warning('AI subtitle generation elapsed > 300s, declaring timeout', tag: SubtitlesControllerBase.subtitlesTag);
          isGeneratingAI.value = false;
          aiJobStatus.value = 'Subtitle generation timed out. Tap Regenerate to try again.';
          stopElapsedTimer();
          stopQueueMonitor();
          aiJobSubscription?.cancel();
          aiVideoSubscription?.cancel();
          showError('AI subtitle generation timed out. Please try again.');
          return;
        }

        final currentProg = aiJobProgress.value;
        if (currentProg >= 35 && currentProg < 74) {
          if (aiElapsedSeconds.value % 3 == 0) {
            aiJobProgress.value = (currentProg + 1).clamp(35, 74);
            final langsCount = aiTargetLanguages.length;
            aiJobStatus.value = 'Translating dialogue into $langsCount target languages (${aiJobProgress.value}%)...';
          }
        } else if (currentProg >= 75 && currentProg < 98) {
          if (aiElapsedSeconds.value % 4 == 0) {
            aiJobProgress.value = (currentProg + 1).clamp(75, 98);
            if (aiJobProgress.value >= 94) {
              aiJobStatus.value = 'Finalizing subtitles & precision alignment (${aiJobProgress.value}%)...';
            } else {
              aiJobStatus.value = 'Formatting timestamps & generating standard VTT/SRT (${aiJobProgress.value}%)...';
            }
          }
        }

        if (aiElapsedSeconds.value > 0 && aiElapsedSeconds.value % 15 == 0) {
          checkSilentVideoSubtitles();
        }
      }
    });
  }

  Future<void> checkSilentVideoSubtitles() async {
    final video = selectedVideo.value;
    if (video == null || !isGeneratingAI.value) return;
    try {
      final doc = await firestore.collection(FirestoreCollections.videos).doc(video.id).get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final mediaSubtitles = (data['media'] != null && data['media']['subtitles'] != null)
          ? Map<String, String>.from(data['media']['subtitles'] as Map)
          : (data['subtitles'] != null
              ? Map<String, String>.from(data['subtitles'] as Map)
              : (data['mediaSubtitles'] != null
                  ? Map<String, String>.from(data['mediaSubtitles'] as Map)
                  : <String, String>{}));

      final langs = aiTargetLanguages.isNotEmpty
          ? aiTargetLanguages.toList()
          : <String>[];
      if (langs.isNotEmpty && langs.every(mediaSubtitles.containsKey)) {
        isGeneratingAI.value = false;
        aiJobProgress.value = 100;
        aiCurrentStageName.value = 'Precision Timestamp Alignment & VTT Export';
        aiJobStatus.value = 'Subtitles generated successfully!';
        for (final l in langs) {
          aiLanguageStatuses[l] = 'completed';
        }
        showSuccess('Subtitles ready for ${langs.join(", ").toUpperCase()}!');
        stopElapsedTimer();
        stopQueueMonitor();
        aiJobSubscription?.cancel();
        aiVideoSubscription?.cancel();
        final newlyGenerated = langs.firstWhere(
          (l) => l != (selectedVideo.value?.language ?? 'en'),
          orElse: () => langs.isNotEmpty ? langs.first : 'en',
        );
        refreshSelectedVideoLocalization(newlyGenerated);
      }
    } catch (_) {}
  }

  void stopElapsedTimer() {
    aiElapsedTimer?.cancel();
    aiElapsedTimer = null;
  }

  void startQueueMonitor(String videoId, int myCreatedAt) {
    aiQueueSubscription?.cancel();
    aiQueueSubscription = firestore
        .collection('video_jobs')
        .where('status', whereIn: ['queued', 'processing', 'running'])
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs;
      aiQueueTotal.value = docs.isNotEmpty ? docs.length : 1;

      // Count jobs started before this job to determine queue position
      var position = 1;
      for (final doc in docs) {
        if (doc.id == videoId) continue;
        final jobCreated = (doc.data()['createdAt'] as num?)?.toInt() ?? 0;
        if (jobCreated < myCreatedAt && jobCreated > 0) {
          position++;
        }
      }
      aiQueuePosition.value = position;
    }, onError: (e) {
      logger.warning('Queue monitor warning: $e', tag: SubtitlesControllerBase.subtitlesTag);
    });
  }

  void stopQueueMonitor() {
    aiQueueSubscription?.cancel();
    aiQueueSubscription = null;
  }

  Future<void> refreshSelectedVideoLocalization([String? newlyGeneratedLang]) async {
    final video = selectedVideo.value;
    if (video == null) return;
    final doc = await firestore
        .collection(FirestoreCollections.videos)
        .doc(video.id)
        .get();
    if (doc.exists) {
      final updatedVideo = Video.fromDocumentSnapshot(doc);
      selectedVideo.value = updatedVideo;
      selectedLanguage.value = '';
      availableLanguages.clear();
      currentCues.clear();
      final subs = updatedVideo.mediaSubtitles;
      final orderedLangs = <String>['en'];
      for (final lang in subs.keys) {
        if (!orderedLangs.contains(lang)) orderedLangs.add(lang);
      }
      availableLanguages.value = orderedLangs;

      String targetLang;
      if (newlyGeneratedLang != null && subs.containsKey(newlyGeneratedLang)) {
        targetLang = newlyGeneratedLang;
      } else {
        targetLang = orderedLangs.contains('en') ? 'en' : orderedLangs.first;
      }
      selectedLanguage.value = targetLang;
      if (subs.containsKey(targetLang)) {
        await parseCuesForLanguage(targetLang, subs[targetLang]);
      }
      selectedVideo.refresh();
    }
  }
}
