import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/repositories/advertiser_repository_impl.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdvertiserPortalController extends BaseController {
  final AdvertiserRepository _advertiserRepository = AdvertiserRepositoryImpl();
  StreamSubscription<DocumentSnapshot>? _subtitlesJobSub;
  StreamSubscription<DocumentSnapshot>? _dubbingJobSub;

  final RxInt selectedIndex = 0.obs;
  final RxString selectedMetric = 'spend'.obs; // 'spend', 'impressions', 'clicks', 'ctr'
  final RxList<Map<String, dynamic>> channelVideos = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingVideos = false.obs;
  final RxBool isSigningIn = false.obs;

  // Subtitles view state
  final selectedAdForSubtitles = Rxn<AdItem>();
  final RxString selectedLanguageForSubtitles = 'en'.obs;
  final RxList<Map<String, String>> currentSubtitleCues = <Map<String, String>>[].obs;
  final RxBool isSavingSubtitles = false.obs;
  final RxBool isTranslatingSubtitles = false.obs;
  final RxDouble subtitleProgress = 0.0.obs;
  final RxString subtitleStatusText = ''.obs;

  // Audio Dubs view state
  final selectedAdForAudio = Rxn<AdItem>();
  final RxString selectedLanguageForAudio = 'hi'.obs;
  final RxBool isTranslatingAudio = false.obs;
  final RxDouble audioProgress = 0.0.obs;
  final RxString audioStatusText = ''.obs;

  final List<String> tabTitles = [
    'Advertiser Dashboard',
    'My Campaigns',
    'Performance Reports',
    'AI Video Subtitles',
    'AI Audio Dubbing',
  ];

  final List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'te', 'name': 'Telugu'},
  ];

  @override
  void onInit() {
    super.onInit();
    fetchChannelVideos();
    // Fetch videos when user gets authenticated
    addWorker(ever(AuthService.to.isAuthenticated, (_) {
      fetchChannelVideos();
    }));
    // Sync active campaign selections with real-time AdService campaigns list
    addWorker(ever(AdService.to.customCampaigns, _syncSelectedAds));
  }

  @override
  void onClose() {
    _subtitlesJobSub?.cancel();
    _dubbingJobSub?.cancel();
    super.onClose();
  }

  void _syncSelectedAds(List<AdItem> campaigns) {
    if (selectedAdForSubtitles.value != null) {
      final updated = campaigns.firstWhereOrNull((a) => a.id == selectedAdForSubtitles.value!.id);
      if (updated != null) {
        selectedAdForSubtitles.value = updated;
      }
    }
    if (selectedAdForAudio.value != null) {
      final updated = campaigns.firstWhereOrNull((a) => a.id == selectedAdForAudio.value!.id);
      if (updated != null) {
        selectedAdForAudio.value = updated;
      }
    }
  }

  String getLanguageName(String code) {
    final found = supportedLanguages.firstWhereOrNull((l) => l['code'] == code);
    return found?['name'] ?? code.toUpperCase();
  }

  Future<void> fetchChannelVideos() async {
    if (!AuthService.to.isAuthenticated.value ||
        !AuthService.to.hasChannel.value) {
      return;
    }
    final channelId = AuthService.to.userChannel?.id;
    if (channelId == null || channelId.isEmpty) return;

    isLoadingVideos.value = true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .where('visibility', isEqualTo: 'public')
          .limit(10)
          .get();

      channelVideos.value = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Video',
          'description': data['description'] ?? '',
          'videoUrl': data['videoUrl'] ?? '',
          'thumbnailUrl': data['thumbnailUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching channel videos for promotion: $e');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> handleGoogleSignIn() async {
    isSigningIn.value = true;

    try {
      await AuthService.to.signInWithGoogle();
      await fetchChannelVideos();
      AppSnackbar.show(
        'Welcome',
        'Signed in successfully as ${AuthService.to.currentUser.value?.displayName ?? "Advertiser"}',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      debugPrint('Error signing in for Ads: $e');
      AppSnackbar.show(
        'Sign In Failed',
        'Unable to complete Google Sign In: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isSigningIn.value = false;
    }
  }

  void loadCuesForAd(AdItem ad, String langCode) {
    final subs = ad.subtitles ?? {};
    final content = subs[langCode] ?? '';
    if (content.isEmpty) {
      currentSubtitleCues.value = [
        {
          'id': '1',
          'startTime': '00:00:01.000',
          'endTime': '00:00:05.000',
          'text': 'Welcome to ${ad.advertiser}!',
        },
        {
          'id': '2',
          'startTime': '00:00:05.000',
          'endTime': '00:00:10.000',
          'text': ad.description,
        },
        {
          'id': '3',
          'startTime': '00:00:10.000',
          'endTime': '00:00:15.000',
          'text': 'Click the link to ${ad.ctaText}!',
        },
      ];
      return;
    }

    final lines = content.split('\n');
    final cues = <Map<String, String>>[];
    var pendingStart = '';
    var pendingEnd = '';
    final pendingText = StringBuffer();

    for (final line in lines) {
      if (line.contains('-->')) {
        if (pendingStart.isNotEmpty) {
          cues.add({
            'id': '${DateTime.now().millisecondsSinceEpoch}_${cues.length}',
            'startTime': pendingStart,
            'endTime': pendingEnd,
            'text': pendingText.toString().trim(),
          });
          pendingText.clear();
        }
        final parts = line.split('-->');
        pendingStart = parts[0].trim();
        pendingEnd = parts.length > 1 ? parts[1].trim() : '00:00:05.000';
      } else if (line.trim().isNotEmpty && !line.startsWith('WEBVTT')) {
        pendingText.writeln(line.trim());
      }
    }
    if (pendingStart.isNotEmpty) {
      cues.add({
        'id': '${DateTime.now().millisecondsSinceEpoch}_${cues.length}',
        'startTime': pendingStart,
        'endTime': pendingEnd,
        'text': pendingText.toString().trim(),
      });
    }

    currentSubtitleCues.value = cues;
  }

  String exportCuesToVtt() {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    for (final cue in currentSubtitleCues) {
      buffer.writeln('${cue['startTime']} --> ${cue['endTime']}');
      buffer.writeln(cue['text']);
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<void> saveSubtitlesForAd() async {
    if (selectedAdForSubtitles.value == null) return;
    isSavingSubtitles.value = true;

    try {
      final vttContent = exportCuesToVtt();
      final updatedSubtitles = Map<String, String>.from(
        selectedAdForSubtitles.value!.subtitles ?? {},
      );
      updatedSubtitles[selectedLanguageForSubtitles.value] = vttContent;

      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(selectedAdForSubtitles.value!.id)
          .update({'subtitles': updatedSubtitles});

      AppSnackbar.show(
        'Success',
        'Subtitles for ${getLanguageName(selectedLanguageForSubtitles.value)} saved successfully.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      debugPrint('Error saving subtitles: $e');
      AppSnackbar.show(
        'Error',
        'Failed to save subtitles: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isSavingSubtitles.value = false;
    }
  }

  Future<void> requestAdSubtitles(String targetLang) async {
    final ad = selectedAdForSubtitles.value;
    if (ad == null) return;

    isTranslatingSubtitles.value = true;
    subtitleProgress.value = 0.15;
    subtitleStatusText.value =
        'Connecting to AI pipeline for ${getLanguageName(targetLang)}...';

    try {
      final result = await _advertiserRepository.triggerAdAIFeatures(
        campaignId: ad.id,
        features: ['subtitles'],
        targetLanguages: [targetLang],
      );

      if (result.isSuccess) {
        subtitleStatusText.value =
            'Translating and aligning cues for ${getLanguageName(targetLang)}...';
        subtitleProgress.value = 0.4;

        _subtitlesJobSub?.cancel();
        _subtitlesJobSub = FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(ad.id)
            .snapshots()
            .listen((snapshot) {
              if (!snapshot.exists) return;
              final data = snapshot.data();
              if (data == null) return;

              final stages = data['stages'] as Map<String, dynamic>?;
              final aiStage = stages?['ai'] as Map<String, dynamic>?;

              if (aiStage != null) {
                final progress =
                    (aiStage['progress'] as num?)?.toDouble() ?? 0.0;
                final stageText = aiStage['currentStage'] as String? ?? '';
                final status = aiStage['status'] as String? ?? '';

                if (progress > 0) {
                  subtitleProgress.value = progress / 100.0;
                }
                if (stageText.isNotEmpty) {
                  subtitleStatusText.value = stageText;
                }

                if (status == 'completed') {
                  isTranslatingSubtitles.value = false;
                  subtitleProgress.value = 1.0;
                  selectedLanguageForSubtitles.value = targetLang;
                  final updatedAd = AdItem.fromMap(
                    Map<String, dynamic>.from(data),
                  );
                  selectedAdForSubtitles.value = updatedAd;
                  loadCuesForAd(updatedAd, targetLang);
                  AppSnackbar.show(
                    'Translation Ready',
                    'AI subtitles in ${getLanguageName(targetLang)} generated successfully!',
                    backgroundColor: AppColors.success,
                    colorText: AppColors.textPrimary,
                  );
                  _subtitlesJobSub?.cancel();
                } else if (status == 'failed') {
                  isTranslatingSubtitles.value = false;
                  final errorMsg =
                      aiStage['error'] ?? 'Subtitle translation failed';
                  AppSnackbar.show(
                    'AI Pipeline Error',
                    '$errorMsg',
                    backgroundColor: AppColors.error,
                    colorText: AppColors.textPrimary,
                  );
                  _subtitlesJobSub?.cancel();
                }
              }
            });
      } else {
        isTranslatingSubtitles.value = false;
        AppSnackbar.show(
          'Request Failed',
          result.exceptionOrNull?.message ??
              'Failed to trigger AI subtitle translation',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
      }
    } catch (e) {
      isTranslatingSubtitles.value = false;
      debugPrint('Error triggering subtitle translation: $e');
      AppSnackbar.show(
        'Error',
        'Could not trigger AI translation: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> requestAdAudioDub(
    String targetLang, {
    String voiceStyle = 'natural',
  }) async {
    final ad = selectedAdForAudio.value;
    if (ad == null) return;

    isTranslatingAudio.value = true;
    audioProgress.value = 0.15;
    audioStatusText.value =
        'Synthesizing voice dubbing for ${getLanguageName(targetLang)}...';

    try {
      final result = await _advertiserRepository.triggerAdAIFeatures(
        campaignId: ad.id,
        features: ['dubbing', 'subtitles'],
        targetLanguages: [targetLang],
        voiceStyle: voiceStyle,
      );

      if (result.isSuccess) {
        audioStatusText.value =
            'Rendering vocal patterns & audio layers...';
        audioProgress.value = 0.4;

        _dubbingJobSub?.cancel();
        _dubbingJobSub = FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(ad.id)
            .snapshots()
            .listen((snapshot) {
              if (!snapshot.exists) return;
              final data = snapshot.data();
              if (data == null) return;

              final stages = data['stages'] as Map<String, dynamic>?;
              final aiStage = stages?['ai'] as Map<String, dynamic>?;

              if (aiStage != null) {
                final progress =
                    (aiStage['progress'] as num?)?.toDouble() ?? 0.0;
                final stageText = aiStage['currentStage'] as String? ?? '';
                final status = aiStage['status'] as String? ?? '';

                if (progress > 0) {
                  audioProgress.value = progress / 100.0;
                }
                if (stageText.isNotEmpty) {
                  audioStatusText.value = stageText;
                }

                if (status == 'completed') {
                  isTranslatingAudio.value = false;
                  audioProgress.value = 1.0;
                  final updatedAd = AdItem.fromMap(
                    Map<String, dynamic>.from(data),
                  );
                  selectedAdForAudio.value = updatedAd;
                  AppSnackbar.show(
                    'Dubbing Completed',
                    'AI voice dubbing in ${getLanguageName(targetLang)} is now live!',
                    backgroundColor: AppColors.success,
                    colorText: AppColors.textPrimary,
                  );
                  _dubbingJobSub?.cancel();
                } else if (status == 'failed') {
                  isTranslatingAudio.value = false;
                  final errorMsg =
                      aiStage['error'] ?? 'Voice dubbing failed';
                  AppSnackbar.show(
                    'AI Pipeline Error',
                    '$errorMsg',
                    backgroundColor: AppColors.error,
                    colorText: AppColors.textPrimary,
                  );
                  _dubbingJobSub?.cancel();
                }
              }
            });
      } else {
        isTranslatingAudio.value = false;
        AppSnackbar.show(
          'Request Failed',
          result.exceptionOrNull?.message ??
              'Failed to trigger AI voice dubbing',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
      }
    } catch (e) {
      isTranslatingAudio.value = false;
      debugPrint('Error triggering audio dubbing: $e');
      AppSnackbar.show(
        'Error',
        'Could not trigger AI voice dubbing: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  void startSubtitleTranslationSimulation(String targetLang) {
    requestAdSubtitles(targetLang);
  }

  void startAudioDubbingSimulation(
    String targetLang, [
    String voiceStyle = 'natural',
  ]) {
    requestAdAudioDub(targetLang, voiceStyle: voiceStyle);
  }
}

