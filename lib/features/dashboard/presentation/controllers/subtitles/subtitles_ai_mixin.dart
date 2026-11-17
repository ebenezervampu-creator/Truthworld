import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Mixin handling Truthworld AI subtitle generation, Cloud Function triggers,
/// live pipeline telemetry, per-language tracking, and cloud queue monitoring.
mixin SubtitlesAiMixin on SubtitlesControllerBase {
  Future<void> triggerSubtitlesGeneration({
    required List<String> targetLanguages,
    String priorityMode = 'accuracy',
    String subtitleTier = 'ultra',
    bool isDirectlyPaid = false,
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

    // Resolve channel context
    final targetChanId = channelId.value.isNotEmpty
        ? channelId.value
        : (video.channelId.isNotEmpty ? video.channelId : currentUser.uid);
    Channel? chan;
    try {
      final chanDoc = await firestore.collection(FirestoreCollections.channels).doc(targetChanId).get();
      if (chanDoc.exists && chanDoc.data() != null) {
        chan = Channel.fromMap(chanDoc.data()!, chanDoc.id);
      }
    } catch (e) {
      logger.warning('Could not resolve channel for subtitles: $e', tag: SubtitlesControllerBase.subtitlesTag);
    }

    final durationSecs = video.durationSeconds > 0
        ? video.durationSeconds
        : (video.durationValue.inSeconds > 0 ? video.durationValue.inSeconds : 120);
    final channelType = chan?.channelType ?? ChannelType.standard;
    final subtitleCost = ChannelWalletService.calculateSubtitleCost(
      languageCount: targetLanguages.length,
      durationSeconds: durationSecs,
      channelType: channelType,
      channel: chan,
      tierId: subtitleTier,
    );

    WalletTransaction? walletTx;
    if (subtitleCost > 0 && !isDirectlyPaid) {
      if (chan == null) {
        showError('Unable to verify channel revenue account. Please ensure you have a valid channel to proceed with AI subtitles.');
        return;
      }
      final walletService = ChannelWalletService();
      final balance = await walletService.getSpendableBalanceForChannelId(chan.id);
      if (!balance.canAfford(subtitleCost)) {
        final rate = ChannelWalletService.getFlatSubtitlePricePerLanguage(
          durationSeconds: durationSecs,
          channelType: channelType,
          tierId: subtitleTier,
        );
        showError(
          'Subtitles are not free. Channel revenue of \$${balance.totalSpendableBalance.toStringAsFixed(2)} is insufficient for the subtitle cost of \$${subtitleCost.toStringAsFixed(2)} (\$${rate.toStringAsFixed(3)}/lang × ${targetLanguages.length} languages for ${durationSecs}s video). Please pay directly to proceed.',
        );
        return;
      }

      walletTx = await walletService.spendBalance(
        channel: chan,
        userId: currentUser.uid,
        amount: subtitleCost,
        category: WalletTransactionCategory.aiSubtitles,
        description: 'Ultra AI Subtitles for "${video.title}" (${targetLanguages.length} langs, ${durationSecs}s)',
        metadata: {
          'videoId': video.id,
          'targetLanguages': targetLanguages,
          'durationSeconds': durationSecs,
          'costUSD': subtitleCost,
          'subtitleTier': subtitleTier,
          'paidFromRevenue': true,
        },
      );

      if (walletTx == null) {
        showError('Unable to deduct subtitle payment from channel revenue. Please ensure your account has sufficient funds.');
        return;
      }
      unawaited(refreshSpendableBalance());
    }

    aiTargetLanguages.assignAll(targetLanguages);
    final initialStatuses = <String, String>{};
    for (final lang in targetLanguages) {
      initialStatuses[lang] = 'queued';
    }
    aiLanguageStatuses.assignAll(initialStatuses);

    final hasExistingSource = video.mediaSubtitles.values.any((s) => s.isNotEmpty) ||
        video.transcriptionUrl.isNotEmpty;

    final initialProgress = hasExistingSource ? 35 : 15;
    isGeneratingAI.value = true;
    isAiJobPaused.value = false;
    aiJobProgress.value = initialProgress;
    aiCurrentStageName.value = hasExistingSource
        ? 'Neural Multilingual Translation'
        : 'Speech Extraction & Transcription';
    aiJobStatus.value = hasExistingSource
        ? 'Source transcript verified. Starting multilingual neural translation for ${targetLanguages.join(", ").toUpperCase()}...'
        : 'Initiating cloud speech pipeline...';

    for (final lang in targetLanguages) {
      final norm = normalizeLanguageCode(lang);
      final stage = hasExistingSource ? 'translating' : 'transcribing';
      aiLanguageStatuses[norm] = stage;
      aiLanguageStatuses[lang] = stage;
      generatingSubtitleLanguages.add(norm);
      if (!availableLanguages.contains(norm)) availableLanguages.add(norm);
      subtitleProgress[norm] = SubtitleTrackProgressState(
        langCode: norm,
        progress: initialProgress,
        stageStep: hasExistingSource ? 2 : 1,
        totalStepsText: 'Step ${hasExistingSource ? 2 : 1} of 3',
        stageTitle: hasExistingSource
            ? 'Translating speech to ${getLanguageName(norm)}'
            : 'Analyzing audio & transcribing dialogue',
        etaText: '~15-20 sec',
      );
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
            'sourceLanguage': video.language.isNotEmpty ? normalizeLanguageCode(video.language) : 'en',
            'primaryLanguage': video.language.isNotEmpty ? normalizeLanguageCode(video.language) : 'en',
            'priorityMode': priorityMode,
            'subtitleTier': subtitleTier,
            'autoChapters': false,
            if (walletTx != null) 'walletTransactionId': walletTx.id,
            if (subtitleCost > 0) 'paidFromRevenue': true,
            if (isDirectlyPaid) 'paidDirectly': true,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          pipelineTriggered = true;
          if (walletTx != null) {
            await firestore.collection('videos').doc(video.id).set({
              'subtitlesPaid': true,
              'subtitlesCostUSD': subtitleCost,
              'subtitlesDurationSeconds': durationSecs,
              'subtitlesWalletTxId': walletTx.id,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
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
          'sourceLanguage': video.language.isNotEmpty ? normalizeLanguageCode(video.language) : 'en',
          'primaryLanguage': video.language.isNotEmpty ? normalizeLanguageCode(video.language) : 'en',
          'paidFromRevenue': walletTx != null,
          if (isDirectlyPaid) 'paidDirectly': true,
          if (walletTx != null) 'walletTransactionId': walletTx.id,
          'createdAt': nowMs,
          'updatedAt': nowMs,
          'executionPlan': {
            'jobId': video.id,
            'languages': targetLanguages,
            'sourceLanguage': video.language.isNotEmpty ? normalizeLanguageCode(video.language) : 'en',
            'primaryLanguage': video.language.isNotEmpty ? normalizeLanguageCode(video.language) : 'en',
            'generateSubtitles': true,
            'genLangSubs': true,
            'enableSubtitles': true,
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

        if (walletTx != null) {
          await firestore.collection('videos').doc(video.id).set({
            'subtitlesPaid': true,
            'subtitlesCostUSD': subtitleCost,
            'subtitlesDurationSeconds': durationSecs,
            'subtitlesWalletTxId': walletTx.id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

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
      final currentVideo = selectedVideo.value;
      final resolvedJobId = (currentVideo?.jobId?.isNotEmpty == true)
          ? currentVideo!.jobId!
          : videoId;

      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        final mainDoc = await firestore.collection('video_jobs').doc(resolvedJobId).get();
        if (mainDoc.exists && mainDoc.data() != null) {
          doc = mainDoc;
        } else if (resolvedJobId != videoId) {
          final fallbackDoc = await firestore.collection('video_jobs').doc(videoId).get();
          if (fallbackDoc.exists && fallbackDoc.data() != null) {
            doc = fallbackDoc;
          }
        }
        if (doc == null) {
          final query = await firestore
              .collection('video_jobs')
              .where('videoId', isEqualTo: videoId)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            doc = query.docs.first;
          }
        }
      } catch (e) {
        logger.warning(
          'Error fetching video_jobs document ($resolvedJobId / $videoId): $e',
          tag: SubtitlesControllerBase.subtitlesTag,
        );
      }

      final data = doc?.data() ?? <String, dynamic>{};
      final jobStatus = (data['status'] as String?)?.toLowerCase();
      final stages = (data['stages'] as Map<String, dynamic>?) ?? {};
      final onDemand = stages['onDemandAI'] as Map<String, dynamic>?;
      final onDemandStatus = (onDemand?['status'] as String?)?.toLowerCase();
      final outputs = (data['outputs'] as Map<String, dynamic>?) ?? {};
      final outputSubs = (outputs['subtitles'] as Map<String, dynamic>?) ?? {};
      final executionPlan = (data['executionPlan'] as Map<String, dynamic>?) ?? {};
      final config = (data['config'] as Map<String, dynamic>?) ?? {};

      final planLangs = (executionPlan['subtitleLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          (executionPlan['languages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          (config['languages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          [];
      final onDemandLangs = (onDemand?['requestedLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          [];
      final videoLangs = (currentVideo?.languages ?? [])
          .map((e) => e.trim().toLowerCase())
          .where((l) => normalizeLanguageCode(l) != normalizeLanguageCode(currentVideo?.language ?? 'en'))
          .toList();

      final allJobLangs = <String>{
        ...planLangs,
        ...onDemandLangs,
        ...videoLangs,
        ...generatingSubtitleLanguages,
        ...failedSubtitleLanguages,
      };

      for (final stageKey in stages.keys) {
        if (stageKey.startsWith('translating_')) {
          allJobLangs.add(stageKey.replaceFirst('translating_', '').trim().toLowerCase());
        }
      }

      // If document is not in Firestore yet, but video indicates pending AI localization
      if (doc == null || !doc.exists) {
        if (currentVideo != null &&
            (currentVideo.status == VideoStatus.processing || currentVideo.jobId?.isNotEmpty == true)) {
          final pendingLangs = <String>[];
          for (final l in videoLangs) {
            final norm = normalizeLanguageCode(l);
            if (currentVideo.mediaSubtitles.containsKey(l) || currentVideo.mediaSubtitles.containsKey(norm)) {
              continue;
            }
            pendingLangs.add(norm);
            generatingSubtitleLanguages.add(norm);
            if (!availableLanguages.contains(norm)) availableLanguages.add(norm);
            subtitleProgress[norm] = SubtitleTrackProgressState(
              langCode: norm,
              stageTitle: 'Preparing subtitle generation in ${getLanguageName(norm)}...',
              etaText: '~1-2 min',
            );
          }
          if (pendingLangs.isNotEmpty) {
            isGeneratingAI.value = true;
            aiTargetLanguages.assignAll(pendingLangs);
            aiJobProgress.value = 15;
            aiJobStatus.value = 'Preparing subtitle generation...';
            startElapsedTimer();
            listenToAIJob(videoId, pendingLangs, resolvedJobId);
            return;
          }
        }
        return;
      }

      final currentSubs = currentVideo?.mediaSubtitles ?? {};
      var anyActivelyRunning = false;
      final newlyCompleted = <String>[];

      for (final lang in allJobLangs) {
        final norm = normalizeLanguageCode(lang);
        final baseNorm = normalizeLanguageCode(currentVideo?.language ?? 'en');
        if (norm == baseNorm) continue;

        // 1. Check if finished
        final hasOutputSub = (outputSubs.containsKey(lang) && (outputSubs[lang] as String? ?? '').isNotEmpty) ||
            (outputSubs.containsKey(norm) && (outputSubs[norm] as String? ?? '').isNotEmpty) ||
            ((data['outputs.subtitles.$lang'] as String? ?? '').isNotEmpty) ||
            ((data['outputs.subtitles.$norm'] as String? ?? '').isNotEmpty);
        final hasVideoSub = (currentSubs.containsKey(lang) && (currentSubs[lang] ?? '').isNotEmpty) ||
            (currentSubs.containsKey(norm) && (currentSubs[norm] ?? '').isNotEmpty) ||
            (currentVideo != null && (resolveSubtitleUrlForLanguage(currentVideo, lang)?.isNotEmpty ?? false));

        if (hasOutputSub || hasVideoSub) {
          generatingSubtitleLanguages.remove(norm);
          generatingSubtitleLanguages.remove(lang);
          failedSubtitleLanguages.remove(norm);
          failedSubtitleLanguages.remove(lang);
          subtitleProgress.remove(norm);
          subtitleProgress.remove(lang);
          aiLanguageStatuses[norm] = 'completed';
          aiLanguageStatuses[lang] = 'completed';
          if (!availableLanguages.contains(norm)) availableLanguages.add(norm);
          newlyCompleted.add(norm);
          continue;
        }

        // 2. Check stage status
        final transStage = (stages['translating_$lang'] ?? stages['translating_$norm']) as Map<String, dynamic>?;
        final transStatus = (transStage?['status'] as String?)?.toLowerCase();
        final subStageStatus = (stages['subtitles']?['status'] as String?)?.toLowerCase();

        // Failure detection
        final isLangFailed = transStatus == 'failed';
        final isJobFailed = jobStatus == 'failed' || onDemandStatus == 'failed' || subStageStatus == 'failed';

        if (isLangFailed || isJobFailed) {
          generatingSubtitleLanguages.remove(norm);
          generatingSubtitleLanguages.remove(lang);
          failedSubtitleLanguages.add(norm);
          aiLanguageStatuses[norm] = 'failed';
          aiLanguageStatuses[lang] = 'failed';
          if (!availableLanguages.contains(norm)) availableLanguages.add(norm);

          final rawErr = transStage?['error']?.toString() ??
              data['error']?.toString() ??
              stages['subtitles']?['error']?.toString() ?? '';
          final friendlyError = rawErr.isNotEmpty
              ? UserFeedbackSanitizer.sanitizeMessage(rawErr)
              : 'Subtitle generation for ${getLanguageName(norm)} encountered an issue. Tap Retry to generate again.';

          subtitleProgress[norm] = SubtitleTrackProgressState(
            langCode: norm,
            progress: 0,
            totalStepsText: 'Failed',
            stageTitle: 'Generation Failed',
            etaText: 'Failed',
            isGenerating: false,
            isFailed: true,
            errorMessage: friendlyError,
          );
          continue;
        }

        // Processing detection: accepted, queued, pending, running, processing, in_progress
        final isProcessing = jobStatus == 'accepted' ||
            jobStatus == 'queued' ||
            jobStatus == 'pending' ||
            jobStatus == 'running' ||
            jobStatus == 'processing' ||
            jobStatus == 'in_progress' ||
            transStatus == 'running' ||
            transStatus == 'pending' ||
            transStatus == 'queued' ||
            transStatus == 'processing' ||
            onDemandStatus == 'running' ||
            onDemandStatus == 'queued';

        if (isProcessing) {
          anyActivelyRunning = true;
          failedSubtitleLanguages.remove(norm);
          failedSubtitleLanguages.remove(lang);
          generatingSubtitleLanguages.add(norm);
          if (!availableLanguages.contains(norm)) availableLanguages.add(norm);

          final transProgress = (stages['transcription']?['progress'] as num?)?.toInt() ?? 0;
          final langProg = (transStage?['progress'] as num?)?.toInt();
          final overallProg = (stages['subtitles']?['progress'] as num?)?.toInt() ??
              (onDemand?['progress'] as num?)?.toInt() ??
              (data['progress'] as num?)?.toInt() ?? 0;

          int calcProgress;
          int stageStep;
          String stageTitle;
          String eta;

          if (stages['transcription']?['status'] != 'completed' && overallProg < 35) {
            stageStep = 1;
            stageTitle = 'Analyzing audio & transcribing dialogue';
            final derived = (transProgress > 0 ? (transProgress * 0.35).round() : (overallProg * 0.35).round()).clamp(10, 35);
            calcProgress = math.max(aiJobProgress.value, derived).clamp(10, 35);
            eta = '~20-30 sec';
          } else if (overallProg < 75) {
            stageStep = 2;
            stageTitle = 'Translating speech to ${getLanguageName(norm)}';
            final p = langProg ?? ((overallProg - 35) / 40 * 100).round().clamp(0, 100);
            final derived = 35 + (p * 0.40).round().clamp(0, 40);
            calcProgress = math.max(aiJobProgress.value, derived).clamp(35, 75);
            eta = '~10-15 sec';
          } else {
            stageStep = 3;
            stageTitle = 'Aligning timestamps & formatting captions';
            final p = (overallProg >= 75) ? overallProg : 75 + (langProg != null ? (langProg * 0.20).round() : 10);
            calcProgress = math.max(aiJobProgress.value, p).clamp(75, 98);
            eta = 'Finalizing shortly...';
          }

          subtitleProgress[norm] = SubtitleTrackProgressState(
            langCode: norm,
            progress: calcProgress,
            stageStep: stageStep,
            totalStepsText: 'Step $stageStep of 3',
            stageTitle: stageTitle,
            etaText: eta,
          );
          aiLanguageStatuses[norm] = stageStep == 1 ? 'transcribing' : (stageStep == 2 ? 'translating' : 'aligning');
        }
      }

      if (anyActivelyRunning) {
        isGeneratingAI.value = true;
        aiTargetLanguages.assignAll(generatingSubtitleLanguages);
        final firstActiveProg = subtitleProgress[generatingSubtitleLanguages.first];
        aiJobProgress.value = firstActiveProg?.progress ?? 25;
        aiJobStatus.value = firstActiveProg?.stageTitle ?? 'Processing AI subtitles...';
        startElapsedTimer();
        final createdAt = (data['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        startQueueMonitor(videoId, createdAt);
        listenToAIJob(videoId, generatingSubtitleLanguages.toList(), resolvedJobId);
      } else {
        isGeneratingAI.value = false;
        if (newlyCompleted.isNotEmpty) {
          aiJobProgress.value = 100;
          aiJobStatus.value = 'Subtitles generated successfully!';
          await refreshSelectedVideoLocalization(newlyCompleted.first);
        } else if (failedSubtitleLanguages.isNotEmpty) {
          aiJobProgress.value = 0;
          aiJobStatus.value = 'Subtitle generation encountered an issue.';
        }
      }
    } catch (e) {
      logger.warning(
        'Error checking existing AI subtitle job: $e',
        tag: SubtitlesControllerBase.subtitlesTag,
      );
    }
  }

  void listenToAIJob(String videoId, List<String> targetLanguages, [String? actualJobId]) {
    aiJobSubscription?.cancel();
    aiVideoSubscription?.cancel();
    aiLocSubscription?.cancel();

    final currentVideo = selectedVideo.value;
    final resolvedJobId = (actualJobId?.isNotEmpty == true)
        ? actualJobId!
        : ((currentVideo?.jobId?.isNotEmpty == true) ? currentVideo!.jobId! : videoId);

    void processJobSnapshot(Map<String, dynamic> data) {
      final jobStatus = (data['status'] as String?)?.toLowerCase();
      final stages = (data['stages'] as Map<String, dynamic>?) ?? {};
      final onDemand = stages['onDemandAI'] as Map<String, dynamic>?;
      final onDemandStatus = (onDemand?['status'] as String?)?.toLowerCase();
      final outputs = (data['outputs'] as Map<String, dynamic>?) ?? {};
      final outputSubs = (outputs['subtitles'] as Map<String, dynamic>?) ?? {};
      final v = selectedVideo.value;
      final currentSubs = v?.mediaSubtitles ?? {};
      final executionPlan = (data['executionPlan'] as Map<String, dynamic>?) ?? {};
      final config = (data['config'] as Map<String, dynamic>?) ?? {};

      final planLangs = (executionPlan['subtitleLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          (executionPlan['languages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          (config['languages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          [];
      final onDemandLangs = (onDemand?['requestedLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .toList() ??
          [];

      final allLangs = <String>{
        ...targetLanguages.map((e) => e.trim().toLowerCase()),
        ...planLangs,
        ...onDemandLangs,
        ...generatingSubtitleLanguages,
      };

      for (final stageKey in stages.keys) {
        if (stageKey.startsWith('translating_')) {
          allLangs.add(stageKey.replaceFirst('translating_', '').trim().toLowerCase());
        }
      }

      final newlyCompletedLangs = <String>[];

      for (final lang in allLangs) {
        final norm = normalizeLanguageCode(lang);
        final baseNorm = normalizeLanguageCode(v?.language ?? 'en');
        if (norm == baseNorm) continue;

        final hasOutputSub = (outputSubs.containsKey(lang) && (outputSubs[lang] as String? ?? '').isNotEmpty) ||
            (outputSubs.containsKey(norm) && (outputSubs[norm] as String? ?? '').isNotEmpty) ||
            ((data['outputs.subtitles.$lang'] as String? ?? '').isNotEmpty) ||
            ((data['outputs.subtitles.$norm'] as String? ?? '').isNotEmpty);
        final hasVideoSub = (currentSubs.containsKey(lang) && (currentSubs[lang] ?? '').isNotEmpty) ||
            (currentSubs.containsKey(norm) && (currentSubs[norm] ?? '').isNotEmpty) ||
            (v != null && (resolveSubtitleUrlForLanguage(v, lang)?.isNotEmpty ?? false));

        if (hasOutputSub || hasVideoSub) {
          final wasGenerating = generatingSubtitleLanguages.contains(norm) || generatingSubtitleLanguages.contains(lang);
          generatingSubtitleLanguages.remove(norm);
          generatingSubtitleLanguages.remove(lang);
          failedSubtitleLanguages.remove(norm);
          failedSubtitleLanguages.remove(lang);
          subtitleProgress.remove(norm);
          subtitleProgress.remove(lang);
          aiLanguageStatuses[norm] = 'completed';
          aiLanguageStatuses[lang] = 'completed';
          if (!availableLanguages.contains(norm)) availableLanguages.add(norm);

          if (wasGenerating) {
            newlyCompletedLangs.add(norm);
          }
          continue;
        }

        final transStage = (stages['translating_$lang'] ?? stages['translating_$norm']) as Map<String, dynamic>?;
        final transStatus = (transStage?['status'] as String?)?.toLowerCase();
        final subStageStatus = (stages['subtitles']?['status'] as String?)?.toLowerCase();

        final isLangFailed = transStatus == 'failed';
        final isJobFailed = jobStatus == 'failed' || onDemandStatus == 'failed' || subStageStatus == 'failed';

        if (isLangFailed || isJobFailed) {
          generatingSubtitleLanguages.remove(norm);
          generatingSubtitleLanguages.remove(lang);
          failedSubtitleLanguages.add(norm);
          aiLanguageStatuses[norm] = 'failed';
          aiLanguageStatuses[lang] = 'failed';
          if (!availableLanguages.contains(norm)) availableLanguages.add(norm);

          final rawErr = transStage?['error']?.toString() ??
              data['error']?.toString() ??
              stages['subtitles']?['error']?.toString() ?? '';
          final friendlyError = rawErr.isNotEmpty
              ? UserFeedbackSanitizer.sanitizeMessage(rawErr)
              : 'Subtitle generation for ${getLanguageName(norm)} encountered an issue. Tap Retry to generate again.';

          subtitleProgress[norm] = SubtitleTrackProgressState(
            langCode: norm,
            progress: 0,
            totalStepsText: 'Failed',
            stageTitle: 'Generation Failed',
            etaText: 'Failed',
            isGenerating: false,
            isFailed: true,
            errorMessage: friendlyError,
          );
          continue;
        }

        // Active processing
        failedSubtitleLanguages.remove(norm);
        failedSubtitleLanguages.remove(lang);
        generatingSubtitleLanguages.add(norm);
        if (!availableLanguages.contains(norm)) availableLanguages.add(norm);

        final transProgress = (stages['transcription']?['progress'] as num?)?.toInt() ?? 0;
        final langProg = (transStage?['progress'] as num?)?.toInt();
        final overallProg = (stages['subtitles']?['progress'] as num?)?.toInt() ??
            (onDemand?['progress'] as num?)?.toInt() ??
            (data['progress'] as num?)?.toInt() ?? 0;

        int calcProgress;
        int stageStep;
        String stageTitle;
        String eta;

        if (stages['transcription']?['status'] != 'completed' && overallProg < 35) {
          stageStep = 1;
          stageTitle = 'Analyzing audio & transcribing dialogue';
          final derived = (transProgress > 0 ? (transProgress * 0.35).round() : (overallProg * 0.35).round()).clamp(10, 35);
          calcProgress = math.max(aiJobProgress.value, derived).clamp(10, 35);
          eta = '~20-30 sec';
        } else if (overallProg < 75) {
          stageStep = 2;
          stageTitle = 'Translating speech to ${getLanguageName(norm)}';
          final p = langProg ?? ((overallProg - 35) / 40 * 100).round().clamp(0, 100);
          final derived = 35 + (p * 0.40).round().clamp(0, 40);
          calcProgress = math.max(aiJobProgress.value, derived).clamp(35, 75);
          eta = '~10-15 sec';
        } else {
          stageStep = 3;
          stageTitle = 'Aligning timestamps & formatting captions';
          final p = (overallProg >= 75) ? overallProg : 75 + (langProg != null ? (langProg * 0.20).round() : 10);
          calcProgress = math.max(aiJobProgress.value, p).clamp(75, 98);
          eta = 'Finalizing shortly...';
        }

        subtitleProgress[norm] = SubtitleTrackProgressState(
          langCode: norm,
          progress: calcProgress,
          stageStep: stageStep,
          totalStepsText: 'Step $stageStep of 3',
          stageTitle: stageTitle,
          etaText: eta,
        );
        aiLanguageStatuses[norm] = stageStep == 1 ? 'transcribing' : (stageStep == 2 ? 'translating' : 'aligning');
      }

      if (generatingSubtitleLanguages.isNotEmpty) {
        isGeneratingAI.value = true;
        final firstActiveProg = subtitleProgress[generatingSubtitleLanguages.first];
        aiJobProgress.value = firstActiveProg?.progress ?? 25;
        aiJobStatus.value = firstActiveProg?.stageTitle ?? 'Processing AI subtitles...';
      } else {
        isGeneratingAI.value = false;
        aiJobProgress.value = 100;
        aiJobStatus.value = 'Subtitles generated successfully!';
        aiCurrentStageName.value = 'Precision Timestamp Alignment & VTT Export';
        stopElapsedTimer();
        stopQueueMonitor();
        if (newlyCompletedLangs.isNotEmpty) {
          for (final l in newlyCompletedLangs) {
            showSuccess('${getLanguageName(l)} subtitles are ready!');
          }
          refreshSelectedVideoLocalization(newlyCompletedLangs.first);
        }
      }
    }

    aiJobSubscription = firestore
        .collection('video_jobs')
        .doc(resolvedJobId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;
      processJobSnapshot(snapshot.data()!);
    }, onError: (e) {
      logger.warning('Error streaming video_jobs ($resolvedJobId): $e', tag: SubtitlesControllerBase.subtitlesTag);
    });

    if (resolvedJobId != videoId) {
      aiVideoSubscription = firestore
          .collection('video_jobs')
          .doc(videoId)
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return;
        processJobSnapshot(snapshot.data()!);
      }, onError: (_) {});
    }

    aiLocSubscription = firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('media')
        .doc('localization')
        .snapshots()
        .listen((locSnap) {
      if (!locSnap.exists || locSnap.data() == null) return;
      final locData = locSnap.data()!;
      final locSubs = locData['subtitles'] as Map<String, dynamic>? ?? {};
      final newlyReady = <String>[];
      for (final l in generatingSubtitleLanguages.toList()) {
        final norm = normalizeLanguageCode(l);
        if (locSubs.containsKey(l) || locSubs.containsKey(norm)) {
          generatingSubtitleLanguages.remove(l);
          generatingSubtitleLanguages.remove(norm);
          subtitleProgress.remove(l);
          subtitleProgress.remove(norm);
          aiLanguageStatuses[l] = 'completed';
          aiLanguageStatuses[norm] = 'completed';
          newlyReady.add(norm);
        }
      }
      if (newlyReady.isNotEmpty) {
        isGeneratingAI.value = generatingSubtitleLanguages.isNotEmpty;
        if (generatingSubtitleLanguages.isEmpty) {
          aiJobProgress.value = 100;
          aiJobStatus.value = 'Subtitles generated successfully!';
          aiCurrentStageName.value = 'Precision Timestamp Alignment & VTT Export';
          stopElapsedTimer();
          stopQueueMonitor();
        }
        for (final r in newlyReady) {
          showSuccess('${getLanguageName(r)} subtitles are ready!');
        }
        refreshSelectedVideoLocalization(newlyReady.first);
      }
    }, onError: (_) {});
  }

  @override
  Future<void> retrySubtitleGeneration(String langCode) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return;
    }
    final norm = normalizeLanguageCode(langCode);
    failedSubtitleLanguages.remove(norm);
    failedSubtitleLanguages.remove(langCode);

    subtitleProgress[norm] = SubtitleTrackProgressState(
      langCode: norm,
      stageTitle: 'Preparing subtitle retry in ${getLanguageName(norm)}...',
      etaText: '~1-2 min',
    );
    generatingSubtitleLanguages.add(norm);
    aiLanguageStatuses[norm] = 'queued';
    isGeneratingAI.value = true;
    aiJobProgress.value = 15;
    aiJobStatus.value = 'Preparing subtitle generation in ${getLanguageName(norm)}...';

    await triggerSubtitlesGeneration(
      targetLanguages: [norm],
      isDirectlyPaid: true,
    );
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

  void _syncSubtitleProgress(int prog, int step, String stageTitle, String eta) {
    final targets = generatingSubtitleLanguages.isNotEmpty ? generatingSubtitleLanguages : aiTargetLanguages;
    for (final lang in targets) {
      final norm = normalizeLanguageCode(lang);
      subtitleProgress[norm] = SubtitleTrackProgressState(
        langCode: norm,
        progress: prog,
        stageStep: step,
        totalStepsText: 'Step $step of 3',
        stageTitle: stageTitle,
        etaText: eta,
      );
    }
  }

  void startElapsedTimer() {
    aiElapsedTimer?.cancel();
    aiElapsedSeconds.value = 0;
    aiElapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isAiJobPaused.value) {
        aiElapsedSeconds.value++;

        final currentProg = aiJobProgress.value;
        if (currentProg >= 15 && currentProg < 35) {
          if (aiElapsedSeconds.value % 2 == 0) {
            final nextProg = (currentProg + 1).clamp(15, 35);
            aiJobProgress.value = nextProg;
            aiJobStatus.value = 'Analyzing audio & extracting dialogue ($nextProg%)...';
            _syncSubtitleProgress(nextProg, 1, aiJobStatus.value, '~15-20 sec');
          }
        } else if (currentProg >= 35 && currentProg < 75) {
          if (aiElapsedSeconds.value % 2 == 0) {
            final nextProg = (currentProg + 1).clamp(35, 75);
            final langsCount = aiTargetLanguages.length;
            aiJobProgress.value = nextProg;
            aiJobStatus.value = 'Translating dialogue into $langsCount target languages ($nextProg%)...';
            _syncSubtitleProgress(nextProg, 2, aiJobStatus.value, '~10-15 sec');
          }
        } else if (currentProg >= 75 && currentProg < 98) {
          if (aiElapsedSeconds.value % 2 == 0) {
            final nextProg = (currentProg + 1).clamp(75, 98);
            aiJobProgress.value = nextProg;
            final statusMsg = nextProg >= 92
                ? 'Finalizing subtitles & precision alignment ($nextProg%)...'
                : 'Formatting timestamps & generating standard VTT/SRT ($nextProg%)...';
            aiJobStatus.value = statusMsg;
            _syncSubtitleProgress(nextProg, 3, statusMsg, 'Finalizing shortly...');
          }
        } else if (currentProg >= 98 && currentProg < 100) {
          // If all target languages are already marked completed in statuses, finalize to 100%
          final allDone = aiTargetLanguages.isNotEmpty &&
              aiTargetLanguages.every((l) =>
                  aiLanguageStatuses[l] == 'completed' ||
                  aiLanguageStatuses[normalizeLanguageCode(l)] == 'completed');
          if (allDone) {
            aiJobProgress.value = 100;
            isGeneratingAI.value = false;
            aiJobStatus.value = 'Subtitles generated successfully!';
            aiCurrentStageName.value = 'Precision Timestamp Alignment & VTT Export';
            stopElapsedTimer();
            stopQueueMonitor();
            if (aiTargetLanguages.isNotEmpty) {
              refreshSelectedVideoLocalization(aiTargetLanguages.first);
            }
          }
        }

        if (aiElapsedSeconds.value > 0 && aiElapsedSeconds.value % 3 == 0) {
          checkSilentVideoSubtitles();
        }

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
      }
    });
  }

  Future<void> checkSilentVideoSubtitles() async {
    final video = selectedVideo.value;
    if (video == null || !isGeneratingAI.value) return;
    try {
      final langs = aiTargetLanguages.isNotEmpty
          ? aiTargetLanguages.toList()
          : <String>[];
      if (langs.isEmpty) return;

      // 1. Check if all target languages are marked completed in aiLanguageStatuses
      final allCompletedInStatuses = langs.every((l) =>
          aiLanguageStatuses[l] == 'completed' ||
          aiLanguageStatuses[normalizeLanguageCode(l)] == 'completed');

      // 2. Check root video document
      final doc = await firestore.collection(FirestoreCollections.videos).doc(video.id).get();
      final data = doc.data() ?? <String, dynamic>{};
      final mediaSubtitles = (data['media'] != null && data['media']['subtitles'] != null)
          ? Map<String, String>.from(data['media']['subtitles'] as Map)
          : (data['subtitles'] != null
              ? Map<String, String>.from(data['subtitles'] as Map)
              : (data['mediaSubtitles'] != null
                  ? Map<String, String>.from(data['mediaSubtitles'] as Map)
                  : <String, String>{}));

      // 3. Check media/localization subcollection
      final locDoc = await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .get()
          .catchError((_) => doc);
      final locSubs = (locDoc.data()?['subtitles'] as Map<String, dynamic>?) ?? {};

      // 4. Check video_jobs outputs.subtitles and stages.subtitles
      final resolvedJobId = (video.jobId?.isNotEmpty == true) ? video.jobId! : video.id;
      final jobDoc = await firestore
          .collection('video_jobs')
          .doc(resolvedJobId)
          .get()
          .catchError((_) => doc);
      final jobData = jobDoc.data() ?? <String, dynamic>{};
      final jobOutputs = (jobData['outputs'] as Map<String, dynamic>?) ?? {};
      final jobSubs = (jobOutputs['subtitles'] as Map<String, dynamic>?) ?? {};
      final jobStages = (jobData['stages'] as Map<String, dynamic>?) ?? {};
      final subStage = jobStages['subtitles'] as Map<String, dynamic>?;
      final isSubStageCompleted = subStage?['status'] == 'completed' || subStage?['progress'] == 100;

      final hasAllFinal = allCompletedInStatuses ||
          isSubStageCompleted ||
          langs.every((l) {
            final norm = normalizeLanguageCode(l);
            return mediaSubtitles.containsKey(l) ||
                mediaSubtitles.containsKey(norm) ||
                locSubs.containsKey(l) ||
                locSubs.containsKey(norm) ||
                jobSubs.containsKey(l) ||
                jobSubs.containsKey(norm);
          });

      if (hasAllFinal) {
        isGeneratingAI.value = false;
        aiJobProgress.value = 100;
        aiCurrentStageName.value = 'Precision Timestamp Alignment & VTT Export';
        aiJobStatus.value = 'Subtitles generated successfully!';
        for (final l in langs) {
          final norm = normalizeLanguageCode(l);
          aiLanguageStatuses[l] = 'completed';
          aiLanguageStatuses[norm] = 'completed';
          generatingSubtitleLanguages.remove(l);
          generatingSubtitleLanguages.remove(norm);
          subtitleProgress.remove(l);
          subtitleProgress.remove(norm);
        }
        showSuccess('Subtitles ready for ${langs.join(", ").toUpperCase()}!');
        stopElapsedTimer();
        stopQueueMonitor();
        aiJobSubscription?.cancel();
        aiVideoSubscription?.cancel();
        aiLocSubscription?.cancel();
        final newlyGenerated = langs.firstWhere(
          (l) => normalizeLanguageCode(l) != normalizeLanguageCode(selectedVideo.value?.language ?? 'en'),
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
      final now = DateTime.now().millisecondsSinceEpoch;
      const maxAgeMs = 15 * 60 * 1000; // 15 mins active window
      final activeDocs = docs.where((doc) {
        final d = doc.data();
        final created = (d['createdAt'] as num?)?.toInt() ?? 0;
        final updated = (d['updatedAt'] as num?)?.toInt() ?? created;
        return (now - updated <= maxAgeMs) || (now - created <= maxAgeMs);
      }).toList();

      aiQueueTotal.value = activeDocs.isNotEmpty ? activeDocs.length : 1;

      // Count jobs started before this job to determine queue position
      var position = 1;
      for (final doc in activeDocs) {
        if (doc.id == videoId) continue;
        final jobCreated = (doc.data()['createdAt'] as num?)?.toInt() ?? 0;
        if (jobCreated < myCreatedAt && jobCreated > 0) {
          position++;
        }
      }
      // If the job is already actively processing in Phase 2 or Phase 3, position is active processing slot (1)
      aiQueuePosition.value = (aiJobProgress.value >= 35) ? 1 : position.clamp(1, aiQueueTotal.value);
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
      var updatedVideo = Video.fromDocumentSnapshot(doc);
      final loc = await VideoMediaService().getLocalization(video.id, forceRefresh: true);
      final subs = Map<String, String>.from(updatedVideo.mediaSubtitles);
      if (loc.subtitles.isNotEmpty) {
        subs.addAll(loc.subtitles);
        updatedVideo = updatedVideo.copyWith(mediaSubtitles: subs);
      }
      selectedVideo.value = updatedVideo;
      selectedLanguage.value = '';
      availableLanguages.clear();
      currentCues.clear();
      final orderedLangs = <String>[];
      final baseLang = normalizeLanguageCode(updatedVideo.language);
      orderedLangs.add(baseLang);
      if (!orderedLangs.contains('en')) orderedLangs.add('en');
      for (final lang in subs.keys) {
        final norm = normalizeLanguageCode(lang);
        if (!orderedLangs.contains(norm)) orderedLangs.add(norm);
      }
      availableLanguages.value = orderedLangs;

      String targetLang;
      final normNew = newlyGeneratedLang != null ? normalizeLanguageCode(newlyGeneratedLang) : null;
      if (newlyGeneratedLang != null && (subs.containsKey(newlyGeneratedLang) || (normNew != null && subs.containsKey(normNew)))) {
        targetLang = subs.containsKey(newlyGeneratedLang) ? newlyGeneratedLang : normNew!;
      } else {
        targetLang = orderedLangs.contains(baseLang) ? baseLang : (orderedLangs.contains('en') ? 'en' : orderedLangs.first);
      }
      selectedLanguage.value = targetLang;
      final subUrl = subs[targetLang] ?? (normNew != null ? subs[normNew] : null);
      if (subUrl != null && subUrl.isNotEmpty) {
        await parseCuesForLanguage(targetLang, subUrl);
      }
      selectedVideo.refresh();
    }
  }
}
