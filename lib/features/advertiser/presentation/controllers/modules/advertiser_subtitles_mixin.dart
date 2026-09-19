import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/repositories/advertiser_repository_impl.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/modules/advertiser_languages_data.dart';

mixin AdvertiserSubtitlesMixin on AdvertiserLanguagesMixin {
  final AdvertiserRepository _advertiserSubtitlesRepo = AdvertiserRepositoryImpl();
  StreamSubscription<DocumentSnapshot>? _subtitlesJobSub;

  final selectedAdForSubtitles = Rxn<AdItem>();
  final RxString selectedLanguageForSubtitles = 'en'.obs;
  final RxList<Map<String, String>> currentSubtitleCues = <Map<String, String>>[].obs;
  final RxBool isSavingSubtitles = false.obs;
  final RxBool isUploadingSubtitles = false.obs;
  final RxBool isTranslatingSubtitles = false.obs;
  final RxDouble subtitleProgress = 0.0.obs;
  final RxString subtitleStatusText = ''.obs;

  void disposeSubtitles() {
    _subtitlesJobSub?.cancel();
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

      AppSnackbar.success(
        'Subtitles for ${getLanguageName(selectedLanguageForSubtitles.value)} saved successfully.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to save subtitles. Please try again.',
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
      AppSnackbar.warning(
        'No ad campaign selected.',
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
        AppSnackbar.error(
          'Unable to read subtitle file from device. Please try another file.',
        );
        return false;
      }

      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }

      final segments = SubtitleParser.parse(content);
      if (segments.isEmpty) {
        AppSnackbar.warning(
          'No valid subtitle cues found in file. Please ensure it is a valid .vtt or .srt file.',
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

      AppSnackbar.success(
        'Imported ${newCues.length} subtitle cues in ${getLanguageName(langCode)} successfully!',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to import subtitles. Please try again.',
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
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AdvertiserPortalController.preSaveCues',
        );
      }
    }

    try {
      final result = await _advertiserSubtitlesRepo.triggerAdAIFeatures(
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
                  AppSnackbar.success(
                    'AI subtitles in ${getLanguageName(targetLang)} generated successfully!',
                    title: 'Translation Ready',
                  );
                  _subtitlesJobSub?.cancel();
                } else if (status == 'failed') {
                  isTranslatingSubtitles.value = false;
                  ErrorHandler.log(aiStage['error']);
                  AppSnackbar.error(
                    'Unable to generate AI subtitles. Please try again.',
                  );
                  _subtitlesJobSub?.cancel();
                }
              }
            }, onError: (e, stackTrace) {
              isTranslatingSubtitles.value = false;
              ErrorHandler.log(
                e,
                stackTrace: stackTrace,
                tag: 'AdvertiserPortalController._subtitlesJobSub',
              );
              AppSnackbar.error(
                'Unable to generate AI subtitles. Please try again.',
              );
              _subtitlesJobSub?.cancel();
            });
      } else {
        isTranslatingSubtitles.value = false;
        ErrorHandler.log(result.exceptionOrNull);
        AppSnackbar.error(
          'Unable to start AI subtitle generation. Please try again.',
        );
      }
    } catch (e) {
      isTranslatingSubtitles.value = false;
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to start AI subtitle generation. Please try again.',
      );
    }
  }

  void startSubtitleTranslationSimulation(String targetLang) {
    requestAdSubtitles(targetLang);
  }
}
