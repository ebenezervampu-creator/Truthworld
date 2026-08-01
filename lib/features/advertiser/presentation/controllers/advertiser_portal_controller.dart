import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdvertiserPortalController extends GetxController {
  Worker? _authWorker;
  Timer? _subtitleSimTimer;
  Timer? _audioSimTimer;
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
    'Ad Comments & Replies',
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
    _authWorker = ever(AuthService.to.isAuthenticated, (_) {
      fetchChannelVideos();
    });
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

  void startSubtitleTranslationSimulation(String targetLang) {
    if (selectedAdForSubtitles.value == null) return;
    isTranslatingSubtitles.value = true;
    subtitleProgress.value = 0.0;
    subtitleStatusText.value = 'Extracting audio track...';

    _subtitleSimTimer?.cancel();
    _subtitleSimTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (subtitleProgress.value >= 1.0) {
        timer.cancel();

        final updatedSubtitles = Map<String, String>.from(
          selectedAdForSubtitles.value!.subtitles ?? {},
        );

        var welcome = 'Welcome!';
        var desc = selectedAdForSubtitles.value!.description;
        var cta = 'Learn More';

        if (targetLang == 'hi') {
          welcome = 'स्वागत है!';
          desc = 'यह ஒரு விளம்பரம்.';
          cta = 'அறிந்துகொள்ளுங்கள்';
        } else if (targetLang == 'es') {
          welcome = '¡Bienvenido!';
          desc = 'Este es un anuncio patrocinado.';
          cta = 'Saber más';
        } else if (targetLang == 'fr') {
          welcome = 'Bienvenue!';
          desc = 'Ceci est une annonce sponsorisée.';
          cta = 'En savoir plus';
        } else if (targetLang == 'de') {
          welcome = 'Willkommen!';
          desc = 'Dies ist eine gesponserte Anzeige.';
          cta = 'Mehr erfahren';
        } else if (targetLang == 'ta') {
          welcome = 'வரவேற்கிறோம்!';
          desc = 'இது ஒரு விளம்பரம்.';
          cta = 'மேலும் அறிய';
        }

        final mockVtt =
            'WEBVTT\n\n00:00:01.000 --> 00:00:05.000\n$welcome\n\n00:00:05.000 --> 00:00:10.000\n$desc\n\n00:00:10.000 --> 00:00:15.000\n$cta\n';
        updatedSubtitles[targetLang] = mockVtt;

        FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(selectedAdForSubtitles.value!.id)
            .update({'subtitles': updatedSubtitles})
            .then((_) {
              isTranslatingSubtitles.value = false;
              selectedLanguageForSubtitles.value = targetLang;
              loadCuesForAd(selectedAdForSubtitles.value!, targetLang);
              AppSnackbar.show(
                'Translation Ready',
                'AI translation for ${getLanguageName(targetLang)} completed successfully!',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            });
      } else {
        subtitleProgress.value += 0.1;
        if (subtitleProgress.value > 0.8) {
          subtitleStatusText.value = 'Aligning timestamps...';
        } else if (subtitleProgress.value > 0.5) {
          subtitleStatusText.value =
              'Translating transcript to ${getLanguageName(targetLang)}...';
        } else if (subtitleProgress.value > 0.2) {
          subtitleStatusText.value = 'Transcribing speech to text...';
        }
      }
    });
  }

  void startAudioDubbingSimulation(String targetLang) {
    if (selectedAdForAudio.value == null) return;
    isTranslatingAudio.value = true;
    audioProgress.value = 0.0;
    audioStatusText.value = 'Analyzing original vocal pattern...';

    _audioSimTimer?.cancel();
    _audioSimTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (audioProgress.value >= 1.0) {
        timer.cancel();

        final updatedAudioTracks = Map<String, String>.from(
          selectedAdForAudio.value!.audioTracks ?? {},
        );
        updatedAudioTracks[targetLang] =
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

        FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(selectedAdForAudio.value!.id)
            .update({'audioTracks': updatedAudioTracks})
            .then((_) {
              isTranslatingAudio.value = false;
              AppSnackbar.show(
                'Dubbing Completed',
                'AI audio dub in ${getLanguageName(targetLang)} is now live!',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            });
      } else {
        audioProgress.value += 0.1;
        if (audioProgress.value > 0.8) {
          audioStatusText.value = 'Mixing and matching background track...';
        } else if (audioProgress.value > 0.5) {
          audioStatusText.value =
              'Synthesizing clone voice in ${getLanguageName(targetLang)}...';
        } else if (audioProgress.value > 0.2) {
          audioStatusText.value = 'Translating voice transcript...';
        }
      }
    });
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    _subtitleSimTimer?.cancel();
    _audioSimTimer?.cancel();
    super.onClose();
  }
}
