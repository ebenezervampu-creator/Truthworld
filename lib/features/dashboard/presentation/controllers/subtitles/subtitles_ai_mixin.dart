import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin handling Truthworld AI subtitle generation, Cloud Function triggers, and job monitoring
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

    isGeneratingAI.value = true;
    aiJobProgress.value = 10;
    aiJobStatus.value = 'Initiating Truthworld AI subtitle generation...';

    try {
      final token = await currentUser.getIdToken();
      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/triggerVideoAIFeatures',
      );

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
      );

      if (response.statusCode == 200) {
        showSuccess(
          'Truthworld AI has started generating subtitles for ${targetLanguages.join(", ").toUpperCase()}!',
        );
        listenToAIJob(video.id, targetLanguages);
      } else {
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
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'executionPlan': {
            'jobId': video.id,
            'languages': targetLanguages,
            'generateSubtitles': true,
            'genLangSubs': true,
            'enablePath2': true,
            'priorityMode': priorityMode,
          },
          'stages': {
            'onDemandAI': {
              'status': 'running',
              'progress': 15,
              'requestedFeatures': ['subtitles'],
              'requestedLanguages': targetLanguages,
              'startedAt': DateTime.now().millisecondsSinceEpoch,
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
      showError('Unable to start AI subtitle generation. Please try again.');
      isGeneratingAI.value = false;
    }
  }

  void listenToAIJob(String videoId, List<String> targetLanguages) {
    aiJobSubscription?.cancel();
    aiJobSubscription = firestore
        .collection('video_jobs')
        .doc(videoId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;
      final data = snapshot.data()!;
      final stages = (data['stages'] as Map<String, dynamic>?) ?? {};
      final onDemand = stages['onDemandAI'] as Map<String, dynamic>?;

      if (onDemand != null) {
        final status = (onDemand['status'] as String?)?.toLowerCase();
        final progress = (onDemand['progress'] as num?)?.toInt() ?? 25;
        aiJobProgress.value = progress;

        if (status == 'running') {
          isGeneratingAI.value = true;
          aiJobStatus.value = 'Generating subtitles ($progress%)...';
        } else if (status == 'completed') {
          isGeneratingAI.value = false;
          aiJobProgress.value = 100;
          aiJobStatus.value = 'Subtitles generated successfully!';
          showSuccess(
            'Subtitles ready for ${targetLanguages.join(", ").toUpperCase()}!',
          );
          aiJobSubscription?.cancel();
          refreshSelectedVideoLocalization();
        } else if (status == 'failed') {
          isGeneratingAI.value = false;
          aiJobStatus.value = 'AI generation encountered an issue.';
          aiJobSubscription?.cancel();
        }
      } else {
        final transcription = stages['transcription'] as Map<String, dynamic>?;
        if (transcription?['status'] == 'completed') {
          aiJobProgress.value = 60;
          aiJobStatus.value = 'Transcribing complete. Aligning subtitles...';
        }
      }
    }, onError: (e, stackTrace) {
      logger.error('Error listening to AI job', error: e, stackTrace: stackTrace, tag: SubtitlesControllerBase.subtitlesTag);
      isGeneratingAI.value = false;
      aiJobStatus.value = 'AI generation encountered an issue.';
      aiJobSubscription?.cancel();
    });
  }

  Future<void> refreshSelectedVideoLocalization() async {
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
      final defLang = orderedLangs.contains('en') ? 'en' : orderedLangs.first;
      selectedLanguage.value = defLang;
      if (subs.containsKey(defLang)) {
        await parseCuesForLanguage(defLang, subs[defLang]);
      }
      selectedVideo.refresh();
    }
  }
}
