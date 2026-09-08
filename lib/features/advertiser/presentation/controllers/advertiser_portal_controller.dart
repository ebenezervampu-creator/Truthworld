import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
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
  final RxBool isUploadingSubtitles = false.obs;
  final RxBool isTranslatingSubtitles = false.obs;
  final RxDouble subtitleProgress = 0.0.obs;
  final RxString subtitleStatusText = ''.obs;

  // Audio Dubs view state
  final selectedAdForAudio = Rxn<AdItem>();
  final RxString selectedLanguageForAudio = 'hi'.obs;
  final RxBool isTranslatingAudio = false.obs;
  final RxDouble audioProgress = 0.0.obs;
  final RxBool isUploadingAudioTrack = false.obs;
  final RxDouble audioUploadProgress = 0.0.obs;
  final RxString audioStatusText = ''.obs;

  final List<String> tabTitles = [
    'Advertiser Dashboard',
    'My Campaigns',
    'Performance Reports',
    'AI Video Subtitles',
    'AI Audio Dubbing',
    'Billing & Invoices',
    'Audience & Targeting',
    'Creator Sponsorships',
    'Creative Assets',
    'A/B Testing & Optimization',
    'Brand Settings',
  ];

  final List<Map<String, String>> supportedLanguages = [
    // Top Global & Major Languages (by total speakers / popularity)
    {'code': 'en', 'name': 'English'},
    {'code': 'zh', 'name': 'Chinese (Simplified)'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'ur', 'name': 'Urdu'},
    {'code': 'id', 'name': 'Indonesian'},
    {'code': 'de', 'name': 'German'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'mr', 'name': 'Marathi'},
    {'code': 'te', 'name': 'Telugu'},
    {'code': 'tr', 'name': 'Turkish'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'vi', 'name': 'Vietnamese'},
    {'code': 'tl', 'name': 'Filipino (Tagalog)'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'fa', 'name': 'Persian (Farsi)'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'gu', 'name': 'Gujarati'},
    {'code': 'pl', 'name': 'Polish'},
    {'code': 'kn', 'name': 'Kannada'},
    {'code': 'ml', 'name': 'Malayalam'},
    {'code': 'pa', 'name': 'Punjabi'},
    {'code': 'or', 'name': 'Odia'},
    {'code': 'my', 'name': 'Burmese'},
    {'code': 'uk', 'name': 'Ukrainian'},
    {'code': 'th', 'name': 'Thai'},
    {'code': 'nl', 'name': 'Dutch'},
    {'code': 'ro', 'name': 'Romanian'},
    {'code': 'as', 'name': 'Assamese'},
    {'code': 'el', 'name': 'Greek'},
    {'code': 'cs', 'name': 'Czech'},
    {'code': 'sv', 'name': 'Swedish'},
    {'code': 'hu', 'name': 'Hungarian'},
    {'code': 'he', 'name': 'Hebrew'},
    {'code': 'da', 'name': 'Danish'},
    {'code': 'fi', 'name': 'Finnish'},
    {'code': 'no', 'name': 'Norwegian'},
    {'code': 'sk', 'name': 'Slovak'},
    {'code': 'hr', 'name': 'Croatian'},
    {'code': 'bg', 'name': 'Bulgarian'},
    {'code': 'sr', 'name': 'Serbian'},
    {'code': 'lt', 'name': 'Lithuanian'},
    {'code': 'sl', 'name': 'Slovenian'},
    {'code': 'lv', 'name': 'Latvian'},
    {'code': 'et', 'name': 'Estonian'},
    {'code': 'ne', 'name': 'Nepali'},
    {'code': 'si', 'name': 'Sinhala'},
    {'code': 'sw', 'name': 'Swahili'},
    {'code': 'ms', 'name': 'Malay'},
    {'code': 'kk', 'name': 'Kazakh'},
    {'code': 'uz', 'name': 'Uzbek'},
    {'code': 'az', 'name': 'Azerbaijani'},
    {'code': 'hy', 'name': 'Armenian'},
    {'code': 'ka', 'name': 'Georgian'},
    {'code': 'mn', 'name': 'Mongolian'},
    {'code': 'km', 'name': 'Khmer'},
    {'code': 'lo', 'name': 'Lao'},
    {'code': 'am', 'name': 'Amharic'},
    {'code': 'so', 'name': 'Somali'},
    {'code': 'zu', 'name': 'Zulu'},
    {'code': 'af', 'name': 'Afrikaans'},
    {'code': 'ca', 'name': 'Catalan'},
    {'code': 'eu', 'name': 'Basque'},
    {'code': 'gl', 'name': 'Galician'},
    {'code': 'is', 'name': 'Icelandic'},
    {'code': 'ga', 'name': 'Irish'},
    {'code': 'cy', 'name': 'Welsh'},
    {'code': 'mt', 'name': 'Maltese'},
    {'code': 'la', 'name': 'Latin'},
  ];

  /// 74 languages supported by ElevenLabs (Flash v2.5 / Multilingual v2 / Eleven v3)
  final List<Map<String, String>> supportedAudioLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'zh', 'name': 'Chinese (Mandarin)'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'ur', 'name': 'Urdu'},
    {'code': 'id', 'name': 'Indonesian'},
    {'code': 'de', 'name': 'German'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'pa', 'name': 'Punjabi'},
    {'code': 'mr', 'name': 'Marathi'},
    {'code': 'te', 'name': 'Telugu'},
    {'code': 'tr', 'name': 'Turkish'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'vi', 'name': 'Vietnamese'},
    {'code': 'tl', 'name': 'Filipino (Tagalog)'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'fa', 'name': 'Persian (Farsi)'},
    {'code': 'ha', 'name': 'Hausa'},
    {'code': 'sw', 'name': 'Swahili'},
    {'code': 'jv', 'name': 'Javanese'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'gu', 'name': 'Gujarati'},
    {'code': 'th', 'name': 'Thai'},
    {'code': 'kn', 'name': 'Kannada'},
    {'code': 'pl', 'name': 'Polish'},
    {'code': 'ml', 'name': 'Malayalam'},
    {'code': 'uk', 'name': 'Ukrainian'},
    {'code': 'ne', 'name': 'Nepali'},
    {'code': 'ps', 'name': 'Pashto'},
    {'code': 'my', 'name': 'Burmese'},
    {'code': 'ms', 'name': 'Malay'},
    {'code': 'uz', 'name': 'Uzbek'},
    {'code': 'sd', 'name': 'Sindhi'},
    {'code': 'ro', 'name': 'Romanian'},
    {'code': 'nl', 'name': 'Dutch'},
    {'code': 'ceb', 'name': 'Cebuano'},
    {'code': 'ny', 'name': 'Chichewa (Nyanja)'},
    {'code': 'az', 'name': 'Azerbaijani'},
    {'code': 'si', 'name': 'Sinhala'},
    {'code': 'as', 'name': 'Assamese'},
    {'code': 'el', 'name': 'Greek'},
    {'code': 'cs', 'name': 'Czech'},
    {'code': 'sv', 'name': 'Swedish'},
    {'code': 'hu', 'name': 'Hungarian'},
    {'code': 'be', 'name': 'Belarusian'},
    {'code': 'kk', 'name': 'Kazakh'},
    {'code': 'so', 'name': 'Somali'},
    {'code': 'zu', 'name': 'Zulu'},
    {'code': 'af', 'name': 'Afrikaans'},
    {'code': 'he', 'name': 'Hebrew'},
    {'code': 'sr', 'name': 'Serbian'},
    {'code': 'bg', 'name': 'Bulgarian'},
    {'code': 'hr', 'name': 'Croatian'},
    {'code': 'sk', 'name': 'Slovak'},
    {'code': 'da', 'name': 'Danish'},
    {'code': 'fi', 'name': 'Finnish'},
    {'code': 'no', 'name': 'Norwegian'},
    {'code': 'hy', 'name': 'Armenian'},
    {'code': 'ka', 'name': 'Georgian'},
    {'code': 'bs', 'name': 'Bosnian'},
    {'code': 'lt', 'name': 'Lithuanian'},
    {'code': 'sl', 'name': 'Slovenian'},
    {'code': 'mk', 'name': 'Macedonian'},
    {'code': 'lv', 'name': 'Latvian'},
    {'code': 'et', 'name': 'Estonian'},
    {'code': 'is', 'name': 'Icelandic'},
    {'code': 'ga', 'name': 'Irish'},
    {'code': 'gl', 'name': 'Galician'},
    {'code': 'ca', 'name': 'Catalan'},
    {'code': 'cy', 'name': 'Welsh'},
    {'code': 'lb', 'name': 'Luxembourgish'},
    {'code': 'ln', 'name': 'Lingala'},
    {'code': 'ky', 'name': 'Kirghiz (Kyrgyz)'},
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
    final found = supportedAudioLanguages.firstWhereOrNull((l) => l['code'] == code) ??
        supportedLanguages.firstWhereOrNull((l) => l['code'] == code);
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

      final updatedAd = selectedAdForSubtitles.value!.copyWith(subtitles: updatedSubtitles);
      selectedAdForSubtitles.value = updatedAd;
      final idx = AdService.to.customCampaigns.indexWhere((a) => a.id == updatedAd.id);
      if (idx != -1) {
        AdService.to.customCampaigns[idx] = updatedAd;
        AdService.to.customCampaigns.refresh();
      }

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

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  Future<bool> uploadDirectSubtitles({
    required String langCode,
    required PlatformFile file,
  }) async {
    final ad = selectedAdForSubtitles.value;
    if (ad == null) {
      AppSnackbar.show(
        'Error',
        'No ad campaign selected.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }

    isUploadingSubtitles.value = true;
    try {
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        AppSnackbar.show(
          'Error',
          'Could not read the subtitle file from device.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }

      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }

      final segments = SubtitleParser.parse(content);
      if (segments.isEmpty) {
        AppSnackbar.show(
          'Invalid Format',
          'No valid subtitle cues found in file. Please ensure it is a valid .vtt or .srt file.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }

      final newCues = segments.asMap().entries.map((e) {
        final seg = e.value;
        return {
          'id': '${DateTime.now().millisecondsSinceEpoch}_${e.key}',
          'startTime': _formatDuration(seg.start),
          'endTime': _formatDuration(seg.end),
          'text': seg.text,
        };
      }).toList();

      final buffer = StringBuffer();
      buffer.writeln('WEBVTT');
      buffer.writeln();
      for (final cue in newCues) {
        buffer.writeln('${cue['startTime']} --> ${cue['endTime']}');
        buffer.writeln(cue['text']);
        buffer.writeln();
      }
      final vttContent = buffer.toString();

      final updatedSubtitles = Map<String, String>.from(ad.subtitles ?? {});
      updatedSubtitles[langCode] = vttContent;

      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .set({
            'subtitles': updatedSubtitles,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      selectedLanguageForSubtitles.value = langCode;
      currentSubtitleCues.assignAll(newCues);

      final updatedAd = ad.copyWith(subtitles: updatedSubtitles);
      selectedAdForSubtitles.value = updatedAd;

      final idx = AdService.to.customCampaigns.indexWhere((a) => a.id == updatedAd.id);
      if (idx != -1) {
        AdService.to.customCampaigns[idx] = updatedAd;
        AdService.to.customCampaigns.refresh();
      }

      AppSnackbar.show(
        'Subtitles Uploaded',
        'Imported ${newCues.length} subtitle cues in ${getLanguageName(langCode)} successfully!',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      debugPrint('Error uploading direct subtitles: $e');
      AppSnackbar.show(
        'Upload Failed',
        'Failed to import subtitles: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    } finally {
      isUploadingSubtitles.value = false;
    }
  }

  Future<void> requestAdSubtitles(String targetLang) async {
    final ad = selectedAdForSubtitles.value;
    if (ad == null) return;

    isTranslatingSubtitles.value = true;
    subtitleProgress.value = 0.15;
    subtitleStatusText.value =
        'Connecting to AI pipeline for ${getLanguageName(targetLang)}...';

    // Pre-save currently loaded cues so the Cloud Function has the latest source cues
    if (currentSubtitleCues.isNotEmpty) {
      try {
        final vttContent = exportCuesToVtt();
        final updatedSubtitles = Map<String, String>.from(
          ad.subtitles ?? {},
        );
        updatedSubtitles[selectedLanguageForSubtitles.value] = vttContent;
        await FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(ad.id)
            .set({
              'subtitles': updatedSubtitles,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Pre-saving current cues before translation notice: $e');
      }
    }

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
                  final idx = AdService.to.customCampaigns
                      .indexWhere((a) => a.id == updatedAd.id);
                  if (idx != -1) {
                    AdService.to.customCampaigns[idx] = updatedAd;
                    AdService.to.customCampaigns.refresh();
                  }
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
                  final idx = AdService.to.customCampaigns
                      .indexWhere((a) => a.id == updatedAd.id);
                  if (idx != -1) {
                    AdService.to.customCampaigns[idx] = updatedAd;
                    AdService.to.customCampaigns.refresh();
                  }
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

  Future<bool> uploadDirectAudioTrack({
    required String langCode,
    required PlatformFile file,
  }) async {
    final ad = selectedAdForAudio.value;
    if (ad == null) {
      AppSnackbar.show(
        'Error',
        'No ad campaign selected.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }

    isUploadingAudioTrack.value = true;
    audioUploadProgress.value = 0.0;

    try {
      final fileBytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (fileBytes == null) {
        AppSnackbar.show(
          'Error',
          'Failed to read audio file from device.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }

      final ext = file.extension?.toLowerCase() ?? 'mp3';
      final fileName = '${langCode}_custom_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(
        'ads/${ad.id}/audio_tracks/$fileName',
      );

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: 'audio/$ext',
          customMetadata: {
            'uploaderId': ?currentUid,
          },
        ),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          audioUploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final updatedAudioTracks = Map<String, String>.from(ad.audioTracks ?? {});
      updatedAudioTracks[langCode] = downloadUrl;

      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .set({
            'audioTracks': updatedAudioTracks,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final updatedAd = ad.copyWith(audioTracks: updatedAudioTracks);
      selectedAdForAudio.value = updatedAd;

      final idx = AdService.to.customCampaigns.indexWhere((a) => a.id == updatedAd.id);
      if (idx != -1) {
        AdService.to.customCampaigns[idx] = updatedAd;
        AdService.to.customCampaigns.refresh();
      }

      AppSnackbar.show(
        'Audio Track Uploaded',
        'Direct audio track for ${getLanguageName(langCode)} uploaded successfully!',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      debugPrint('Error uploading audio track: $e');
      AppSnackbar.show(
        'Upload Failed',
        'Could not upload audio track: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    } finally {
      isUploadingAudioTrack.value = false;
      audioUploadProgress.value = 0.0;
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

  final RxBool isGeneratingAllVideoAdsAI = false.obs;

  Future<void> generateAllVideoAdsAI({
    List<String> features = const ['subtitles', 'dubbing'],
    List<String> targetLanguages = const ['te', 'hi', 'ta', 'es'],
    String voiceStyle = 'natural',
    bool forceRegenerate = false,
  }) async {
    if (isGeneratingAllVideoAdsAI.value) return;
    isGeneratingAllVideoAdsAI.value = true;

    try {
      AppSnackbar.show(
        'Queueing AI Pipeline',
        'Initiating AI dubbing and subtitles generation for all video ads...',
        backgroundColor: AppColors.info,
        colorText: AppColors.textPrimary,
      );

      final result = await _advertiserRepository.generateAllVideoAdsAIFeatures(
        features: features,
        targetLanguages: targetLanguages,
        voiceStyle: voiceStyle,
        forceRegenerate: forceRegenerate,
      );

      if (result.isSuccess) {
        AppSnackbar.show(
          'Batch AI Started',
          'Dubbing & subtitles are generating for all video ads in the background.',
          backgroundColor: AppColors.success,
          colorText: AppColors.textPrimary,
        );
      } else {
        AppSnackbar.show(
          'Error',
          result.exceptionOrNull?.message ?? 'Failed to start batch AI generation',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
      }
    } catch (e) {
      debugPrint('Error starting batch AI generation: $e');
      AppSnackbar.show(
        'Error',
        'Failed to start batch AI generation: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isGeneratingAllVideoAdsAI.value = false;
    }
  }

  // ==========================================
  // 1. BILLING & INVOICES / WALLET STATE
  // ==========================================
  final RxDouble walletBalance = 14500.0.obs;
  final RxBool autoReloadEnabled = true.obs;
  final RxDouble autoReloadThreshold = 200.0.obs;
  final RxDouble autoReloadAmount = 2000.0.obs;
  final RxString billingCompanyName = 'Truthworld Technologies Pvt Ltd'.obs;
  final RxString billingGstin = '29ABCDE1234F1Z5'.obs;
  final RxString billingAddress =
      '402, Innovate Towers, Outer Ring Road, Bengaluru, KA 560103'.obs;
  final RxString billingEmail = 'billing@truthworld.com'.obs;

  final RxList<Map<String, dynamic>> savedCards = <Map<String, dynamic>>[
    {
      'id': 'card_1',
      'brand': 'Visa',
      'last4': '4242',
      'expiry': '12/28',
      'holderName': 'Ebenezer Vampu',
      'isDefault': true,
    },
    {
      'id': 'card_2',
      'brand': 'Mastercard',
      'last4': '8899',
      'expiry': '08/29',
      'holderName': 'Truthworld Media Ops',
      'isDefault': false,
    },
  ].obs;

  final RxList<Map<String, dynamic>> transactions = <Map<String, dynamic>>[
    {
      'id': 'INV-2026-0891',
      'date': '06 Sep 2026',
      'description': 'Wallet Top-Up (Stripe)',
      'amount': 5000.0,
      'status': 'Paid',
      'paymentMethod': 'Visa •••• 4242',
      'tax': 900.0,
      'net': 4100.0,
    },
    {
      'id': 'INV-2026-0845',
      'date': '02 Sep 2026',
      'description': 'Campaign Budget: Truthworld Next Gen',
      'amount': 2000.0,
      'status': 'Paid',
      'paymentMethod': 'Wallet Balance',
      'tax': 360.0,
      'net': 1640.0,
    },
    {
      'id': 'INV-2026-0792',
      'date': '28 Aug 2026',
      'description': 'Creator Sponsorship Deposit: TechGuru',
      'amount': 3500.0,
      'status': 'Paid',
      'paymentMethod': 'Mastercard •••• 8899',
      'tax': 630.0,
      'net': 2870.0,
    },
    {
      'id': 'INV-2026-0710',
      'date': '15 Aug 2026',
      'description': 'AI Dubbing & Translation Batch',
      'amount': 500.0,
      'status': 'Paid',
      'paymentMethod': 'Wallet Balance',
      'tax': 90.0,
      'net': 410.0,
    },
  ].obs;

  Future<void> topUpWallet(double amount) async {
    walletBalance.value += amount;
    transactions.insert(0, {
      'id':
          'INV-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'date': 'Today',
      'description': 'Wallet Top-Up (Stripe)',
      'amount': amount,
      'status': 'Paid',
      'paymentMethod':
          savedCards.firstWhereOrNull((c) => c['isDefault'] == true) != null
          ? '${savedCards.firstWhereOrNull((c) => c['isDefault'] == true)!['brand']} •••• ${savedCards.firstWhereOrNull((c) => c['isDefault'] == true)!['last4']}'
          : 'Card Payment',
      'tax': amount * 0.18,
      'net': amount * 0.82,
    });
    AppSnackbar.show(
      'Wallet Recharged',
      '₹${amount.toStringAsFixed(0)} added to your advertiser wallet balance successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void addSavedCard(Map<String, dynamic> card) {
    if (card['isDefault'] == true) {
      for (final c in savedCards) {
        c['isDefault'] = false;
      }
    }
    savedCards.add(card);
    savedCards.refresh();
    AppSnackbar.show(
      'Card Added',
      'Payment card ending in ${card['last4']} saved securely.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void removeSavedCard(String cardId) {
    savedCards.removeWhere((c) => c['id'] == cardId);
    if (savedCards.isNotEmpty &&
        !savedCards.any((c) => c['isDefault'] == true)) {
      savedCards.first['isDefault'] = true;
    }
    savedCards.refresh();
    AppSnackbar.show(
      'Card Removed',
      'Payment method removed successfully.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  void saveBillingDetails({
    required String company,
    required String gstin,
    required String address,
    required String email,
  }) {
    billingCompanyName.value = company;
    billingGstin.value = gstin;
    billingAddress.value = address;
    billingEmail.value = email;
    AppSnackbar.show(
      'Settings Updated',
      'Billing details and GSTIN registered successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  // ==========================================
  // 2. AUDIENCE & TARGETING STATE
  // ==========================================
  final RxList<Map<String, dynamic>> audiencePresets = <Map<String, dynamic>>[
    {
      'id': 'aud_1',
      'name': 'Tech & Innovation Enthusiasts',
      'ageMin': 18,
      'ageMax': 35,
      'genders': ['All'],
      'locations': ['India', 'United States', 'UAE'],
      'interests': [
        'Technology',
        'AI & Machine Learning',
        'Startups',
        'Coding',
      ],
      'estimatedReach': '4.2M Viewers',
    },
    {
      'id': 'aud_2',
      'name': 'Digital Creators & Video Editors',
      'ageMin': 20,
      'ageMax': 45,
      'genders': ['All'],
      'locations': ['India', 'United Kingdom', 'Canada'],
      'interests': ['Video Production', 'Content Creation', 'Audio Editing'],
      'estimatedReach': '1.8M Viewers',
    },
    {
      'id': 'aud_3',
      'name': 'Gaming & Livestream Fans',
      'ageMin': 16,
      'ageMax': 28,
      'genders': ['All'],
      'locations': ['India', 'Southeast Asia', 'Brazil'],
      'interests': ['Esports', 'Live Streaming', 'Gaming Reviews'],
      'estimatedReach': '6.5M Viewers',
    },
  ].obs;

  void createAudiencePreset(Map<String, dynamic> preset) {
    audiencePresets.insert(0, preset);
    AppSnackbar.show(
      'Audience Preset Created',
      'Targeting preset "${preset['name']}" is ready to apply to ad campaigns.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void deleteAudiencePreset(String id) {
    audiencePresets.removeWhere((p) => p['id'] == id);
    AppSnackbar.show(
      'Preset Removed',
      'Audience preset deleted.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  // ==========================================
  // 3. CREATOR SPONSORSHIPS MARKETPLACE STATE
  // ==========================================
  final RxString selectedSponsorshipCategory = 'All'.obs;
  final RxList<Map<String, dynamic>> creatorsList = <Map<String, dynamic>>[
    {
      'id': 'cr_1',
      'name': 'TechVerse Daily',
      'handle': '@techversedaily',
      'category': 'Technology',
      'subscribers': '1.2M',
      'subscribersCount': 1200000,
      'avgViews': '280K',
      'engagement': '8.4%',
      'avatarColor': 0xFF3B82F6,
      'bio': 'Deep dives into futuristic AI, gadgets, and software tools.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 5000.0},
        {'type': 'Pinned Comment Link', 'price': 1500.0},
        {'type': 'Full Video Collaboration', 'price': 25000.0},
      ],
    },
    {
      'id': 'cr_2',
      'name': 'PixelCoders',
      'handle': '@pixelcoders',
      'category': 'Education',
      'subscribers': '680K',
      'subscribersCount': 680000,
      'avgViews': '95K',
      'engagement': '9.1%',
      'avatarColor': 0xFF10B981,
      'bio':
          'Software development tutorials, Flutter, Python and web engineering.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 3000.0},
        {'type': 'Pinned Comment Link', 'price': 1000.0},
      ],
    },
    {
      'id': 'cr_3',
      'name': 'Apex Gaming Realm',
      'handle': '@apexgaming',
      'category': 'Gaming',
      'subscribers': '2.4M',
      'subscribersCount': 2400000,
      'avgViews': '520K',
      'engagement': '12.3%',
      'avatarColor': 0xFFEF4444,
      'bio': 'Daily competitive gaming streams, tournaments, and reviews.',
      'packages': [
        {'type': 'Live Stream Shoutout', 'price': 4000.0},
        {'type': 'Banner Placement', 'price': 2500.0},
      ],
    },
    {
      'id': 'cr_4',
      'name': 'Global Chronicle',
      'handle': '@globalchronicle',
      'category': 'News & Media',
      'subscribers': '950K',
      'subscribersCount': 950000,
      'avgViews': '180K',
      'engagement': '7.2%',
      'avatarColor': 0xFFF59E0B,
      'bio': 'Unbiased geopolitical analysis and tech policy breakdowns.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 3500.0},
        {'type': 'Pinned Comment Link', 'price': 1200.0},
      ],
    },
    {
      'id': 'cr_5',
      'name': 'Creative Frame',
      'handle': '@creativeframe',
      'category': 'Lifestyle',
      'subscribers': '420K',
      'subscribersCount': 420000,
      'avgViews': '65K',
      'engagement': '8.8%',
      'avatarColor': 0xFF8B5CF6,
      'bio':
          'Filmmaking tips, camera gear, color grading, and creative storytelling.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 2000.0},
        {'type': 'Pinned Comment Link', 'price': 800.0},
      ],
    },
  ].obs;

  final RxList<Map<String, dynamic>> sponsorshipProposals =
      <Map<String, dynamic>>[
        {
          'id': 'prop_1',
          'creatorId': 'cr_1',
          'creatorName': 'TechVerse Daily',
          'campaignTitle': 'Truthworld Next Generation',
          'format': '15s Mid-roll Sponsor',
          'offeredAmount': 5000.0,
          'date': '05 Sep 2026',
          'status': 'Accepted',
          'deliverableUrl':
              'https://truthworld.org/watch?v=techverse_ai_future',
        },
        {
          'id': 'prop_2',
          'creatorId': 'cr_2',
          'creatorName': 'PixelCoders',
          'campaignTitle': 'Truthworld Creator Program',
          'format': 'Pinned Comment Link',
          'offeredAmount': 1000.0,
          'date': 'Yesterday',
          'status': 'Under Review',
          'deliverableUrl': '',
        },
      ].obs;

  void sendSponsorshipProposal(Map<String, dynamic> proposal) {
    sponsorshipProposals.insert(0, proposal);
    AppSnackbar.show(
      'Proposal Sent',
      'Sponsorship proposal dispatched to ${proposal['creatorName']}.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void cancelProposal(String id) {
    sponsorshipProposals.removeWhere((p) => p['id'] == id);
    AppSnackbar.show(
      'Proposal Cancelled',
      'Sponsorship proposal was retracted.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  // ==========================================
  // 4. CREATIVE ASSETS / MEDIA LIBRARY STATE
  // ==========================================
  final RxString selectedAssetCategory = 'All'.obs;
  final RxList<Map<String, dynamic>> creativeAssetsList =
      <Map<String, dynamic>>[
        {
          'id': 'asset_1',
          'title': 'Truthworld Next Gen 15s Bumper',
          'type': 'Video',
          'resolution': '1920x1080',
          'duration': '00:15',
          'format': 'MP4',
          'size': '14.8 MB',
          'url':
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
          'date': '01 Sep 2026',
          'campaignUsage': 2,
        },
        {
          'id': 'asset_2',
          'title': 'High-Conversion Feed Banner',
          'type': 'Banner',
          'resolution': '1200x628',
          'duration': 'Static',
          'format': 'PNG',
          'size': '1.2 MB',
          'url': 'https://picsum.photos/1200/628',
          'date': '28 Aug 2026',
          'campaignUsage': 3,
        },
        {
          'id': 'asset_3',
          'title': 'Truthworld Official Brandmark Vector',
          'type': 'Logo',
          'resolution': '512x512',
          'duration': 'Static',
          'format': 'SVG',
          'size': '140 KB',
          'url': 'https://picsum.photos/512/512',
          'date': '15 Aug 2026',
          'campaignUsage': 5,
        },
        {
          'id': 'asset_4',
          'title': 'Mobile Feed Square Promo',
          'type': 'Banner',
          'resolution': '1080x1080',
          'duration': 'Static',
          'format': 'WEBP',
          'size': '680 KB',
          'url': 'https://picsum.photos/1080/1080',
          'date': '10 Aug 2026',
          'campaignUsage': 1,
        },
      ].obs;

  void addCreativeAsset(Map<String, dynamic> asset) {
    creativeAssetsList.insert(0, asset);
    AppSnackbar.show(
      'Asset Uploaded',
      'Creative asset "${asset['title']}" saved to library.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void deleteCreativeAsset(String id) {
    creativeAssetsList.removeWhere((a) => a['id'] == id);
    AppSnackbar.show(
      'Asset Deleted',
      'Creative asset removed from your media library.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  // ==========================================
  // 5. A/B TESTING & OPTIMIZATION STATE
  // ==========================================
  final RxList<Map<String, dynamic>> abExperimentsList = <Map<String, dynamic>>[
    {
      'id': 'exp_1',
      'title': 'Call-To-Action Copy Test',
      'campaign': 'Truthworld Next Generation',
      'variable': 'CTA Button',
      'status': 'Running',
      'trafficSplit': '50% / 50%',
      'startDate': '01 Sep 2026',
      'variantA': {
        'label': 'Variant A (Control)',
        'value': 'Learn More',
        'impressions': 12400,
        'clicks': 480,
        'ctr': 3.87,
        'conversions': 86,
      },
      'variantB': {
        'label': 'Variant B (Challenger)',
        'value': 'Get Started Free',
        'impressions': 12350,
        'clicks': 675,
        'ctr': 5.46,
        'conversions': 134,
      },
      'winner': 'Variant B (+41% higher CTR)',
      'confidence': '97.2% Statistical Confidence',
    },
    {
      'id': 'exp_2',
      'title': 'Headline Benefit vs Curiosity',
      'campaign': 'Truthworld Video Platform',
      'variable': 'Headline',
      'status': 'Concluded',
      'trafficSplit': '50% / 50%',
      'startDate': '20 Aug 2026',
      'variantA': {
        'label': 'Variant A (Benefit)',
        'value': 'Experience Uncensored Truth & Knowledge',
        'impressions': 25000,
        'clicks': 1120,
        'ctr': 4.48,
        'conversions': 240,
      },
      'variantB': {
        'label': 'Variant B (Curiosity)',
        'value': 'The Video Platform Big Tech Didnt Want Built',
        'impressions': 25000,
        'clicks': 1480,
        'ctr': 5.92,
        'conversions': 355,
      },
      'winner': 'Variant B (+32% higher CTR)',
      'confidence': '99.1% Statistical Confidence',
    },
  ].obs;

  void createAbExperiment(Map<String, dynamic> experiment) {
    abExperimentsList.insert(0, experiment);
    AppSnackbar.show(
      'A/B Test Launched',
      'Experiment "${experiment['title']}" is now splitting campaign traffic.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void declareExperimentWinner(String experimentId, String winningVariant) {
    final idx = abExperimentsList.indexWhere((e) => e['id'] == experimentId);
    if (idx != -1) {
      abExperimentsList[idx]['status'] = 'Concluded';
      abExperimentsList.refresh();
      AppSnackbar.show(
        'Winner Applied',
        '$winningVariant has been declared the winner and set as default.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    }
  }

  // ==========================================
  // 6. BRAND PROFILE & SETTINGS STATE
  // ==========================================
  final RxString brandName = 'Truthworld'.obs;
  final RxString brandTagline = 'Truthworld Change the World'.obs;
  final RxString brandWebsite = 'https://truthworld.org'.obs;
  final RxString brandEmail = 'support@truthworld.org'.obs;
  final RxString brandCategory = 'Technology & Media'.obs;
  final RxBool isBrandVerified = true.obs;

  final RxBool lowBudgetAlert = true.obs;
  final RxBool dailyPerformanceDigest = true.obs;
  final RxBool campaignStatusNotifications = true.obs;
  final RxBool sponsorshipAlerts = true.obs;

  final RxString conversionApiKey = 'tw_live_ak_98a7b6c5d4e3f210a'.obs;

  final RxList<Map<String, dynamic>> teamMembers = <Map<String, dynamic>>[
    {
      'name': 'Ebenezer Vampu',
      'email': 'ebenezer@truthworld.org',
      'role': 'Owner (Full Access)',
      'status': 'Active',
    },
    {
      'name': 'Sarah Jenkins',
      'email': 'sarah.growth@truthworld.org',
      'role': 'Campaign Manager',
      'status': 'Active',
    },
    {
      'name': 'Alex Rivera',
      'email': 'finance@truthworld.org',
      'role': 'Billing Analyst',
      'status': 'Active',
    },
  ].obs;

  void saveBrandSettings({
    required String name,
    required String tagline,
    required String website,
    required String email,
    required String category,
  }) {
    brandName.value = name;
    brandTagline.value = tagline;
    brandWebsite.value = website;
    brandEmail.value = email;
    brandCategory.value = category;
    AppSnackbar.show(
      'Profile Saved',
      'Advertiser brand profile updated successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void inviteTeamMember(String name, String email, String role) {
    teamMembers.add({
      'name': name,
      'email': email,
      'role': role,
      'status': 'Invited',
    });
    AppSnackbar.show(
      'Invitation Sent',
      'An invitation to join Advertiser Studio was sent to $email.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void removeTeamMember(String email) {
    teamMembers.removeWhere((m) => m['email'] == email);
    AppSnackbar.show(
      'Member Removed',
      'User $email was removed from team access.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  void regenerateApiKey() {
    conversionApiKey.value =
        'tw_live_ak_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    AppSnackbar.show(
      'API Key Regenerated',
      'New conversion tracking key generated.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }
}

