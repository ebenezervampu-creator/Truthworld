import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/repositories/advertiser_repository_impl.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/modules/advertiser_languages_data.dart';

mixin AdvertiserAudioDubsMixin on AdvertiserLanguagesMixin {
  final AdvertiserRepository _advertiserAudioRepo = AdvertiserRepositoryImpl();
  StreamSubscription<DocumentSnapshot>? _dubbingJobSub;

  final selectedAdForAudio = Rxn<AdItem>();
  final RxString selectedLanguageForAudio = 'hi'.obs;
  final RxBool isTranslatingAudio = false.obs;
  final RxDouble audioProgress = 0.0.obs;
  final RxBool isUploadingAudioTrack = false.obs;
  final RxDouble audioUploadProgress = 0.0.obs;
  final RxString audioStatusText = ''.obs;

  final RxBool isGeneratingAllVideoAdsAI = false.obs;

  void disposeAudioDubs() {
    _dubbingJobSub?.cancel();
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
      final result = await _advertiserAudioRepo.triggerAdAIFeatures(
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
                  AppSnackbar.success(
                    'AI voice dubbing in ${getLanguageName(targetLang)} is now live!',
                    title: 'Dubbing Completed',
                  );
                  _dubbingJobSub?.cancel();
                } else if (status == 'failed') {
                  isTranslatingAudio.value = false;
                  ErrorHandler.log(aiStage['error']);
                  AppSnackbar.error(
                    'Unable to complete voice dubbing. Please try again.',
                  );
                  _dubbingJobSub?.cancel();
                }
              }
            }, onError: (e, stackTrace) {
              isTranslatingAudio.value = false;
              ErrorHandler.log(
                e,
                stackTrace: stackTrace,
                tag: 'AdvertiserPortalController._dubbingJobSub',
              );
              AppSnackbar.error(
                'Unable to complete voice dubbing. Please try again.',
              );
              _dubbingJobSub?.cancel();
            });
      } else {
        isTranslatingAudio.value = false;
        ErrorHandler.log(result.exceptionOrNull);
        AppSnackbar.error(
          'Unable to start voice dubbing. Please try again.',
        );
      }
    } catch (e) {
      isTranslatingAudio.value = false;
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to start voice dubbing. Please try again.',
      );
    }
  }

  Future<bool> uploadDirectAudioTrack({
    required String langCode,
    required PlatformFile file,
  }) async {
    final ad = selectedAdForAudio.value;
    if (ad == null) {
      AppSnackbar.warning(
        'No ad campaign selected.',
      );
      return false;
    }

    isUploadingAudioTrack.value = true;
    audioUploadProgress.value = 0.0;

    try {
      final fileBytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (fileBytes == null) {
        AppSnackbar.error(
          'Unable to read audio file from device. Please try another file.',
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

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            audioUploadProgress.value =
                snapshot.bytesTransferred / snapshot.totalBytes;
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AdvertiserPortalController.audioUpload',
        ),
      );

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

      AppSnackbar.success(
        'Direct audio track for ${getLanguageName(langCode)} uploaded successfully!',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to upload audio track. Please try again.',
      );
      return false;
    } finally {
      isUploadingAudioTrack.value = false;
      audioUploadProgress.value = 0.0;
    }
  }

  void startAudioDubbingSimulation(
    String targetLang, [
    String voiceStyle = 'natural',
  ]) {
    requestAdAudioDub(targetLang, voiceStyle: voiceStyle);
  }

  Future<void> generateAllVideoAdsAI({
    List<String> features = const ['subtitles', 'dubbing'],
    List<String> targetLanguages = const ['te', 'hi', 'ta', 'es'],
    String voiceStyle = 'natural',
    bool forceRegenerate = false,
  }) async {
    if (isGeneratingAllVideoAdsAI.value) return;
    isGeneratingAllVideoAdsAI.value = true;

    try {
      AppSnackbar.info(
        'Initiating AI dubbing and subtitles generation for all video ads...',
      );

      final result = await _advertiserAudioRepo.generateAllVideoAdsAIFeatures(
        features: features,
        targetLanguages: targetLanguages,
        voiceStyle: voiceStyle,
        forceRegenerate: forceRegenerate,
      );

      if (result.isSuccess) {
        AppSnackbar.success(
          'Dubbing and subtitles are generating for all video ads in the background.',
        );
      } else {
        ErrorHandler.log(result.exceptionOrNull);
        AppSnackbar.error(
          'Unable to start batch AI generation. Please try again.',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to start batch AI generation. Please try again.',
      );
    } finally {
      isGeneratingAllVideoAdsAI.value = false;
    }
  }
}
