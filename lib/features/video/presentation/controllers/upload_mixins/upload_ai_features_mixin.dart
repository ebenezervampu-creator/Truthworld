import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';

mixin UploadAiFeaturesMixin on UploadControllerBase {
  /// Categories that are non-factual/creative where fact-checking is not needed
  static const Set<String> categoriesWithoutFactCheck =
      AppCategories.categoriesWithoutFactCheck;

  /// Check whether fact checking is relevant for a given category name
  bool isFactCheckNeededForCategory(String category) {
    return !categoriesWithoutFactCheck.contains(category);
  }

  /// Whether Fact Checking is relevant for the currently selected category
  bool get isFactCheckRelevant =>
      isFactCheckNeededForCategory(selectedCategory.value);

  /// Select a category and handle category update
  void selectCategory(String cat) {
    selectedCategory.value = cat;
  }

  /// Whether sources validation passes (if fact checking is enabled, at least 1 source is required)
  bool get isFactCheckSourcesValid =>
      !aiFactCheckEnabled.value || providedSources.isNotEmpty;

  /// Add a source URL provided by the channel
  void addProvidedSource(String url) {
    final validation = SourceUrlSanitizer.validateAuthoritativeSource(url);
    if (validation.isValid && validation.normalizedUrl != null) {
      final cleanUrl = validation.normalizedUrl!;
      if (!providedSources.contains(cleanUrl)) {
        providedSources.add(cleanUrl);
      }
    }
  }

  /// Remove a provided source at given index
  void removeProvidedSource(int index) {
    if (index >= 0 && index < providedSources.length) {
      providedSources.removeAt(index);
    }
  }

  /// Toggle subtitle language selection.
  /// Selecting in Subtitles does NOT select for Dubbing.
  void toggleSubtitleLanguage(String lang) {
    if (aiTranslationLanguages.contains(lang)) {
      aiTranslationLanguages.remove(lang);
      if (aiDubbingLanguages.contains(lang)) {
        aiDubbingLanguages.remove(lang);
      }
    } else {
      aiTranslationLanguages.add(lang);
    }
  }

  /// Toggle dubbing language selection.
  /// When selected in Dubbing, AUTOMATICALLY select it for Subtitles as well.
  void toggleDubbingLanguage(String lang) {
    final chanCode = channelLanguageCode.toLowerCase();
    final match = supportedLanguages.firstWhereOrNull(
      (l) =>
          l.name.toLowerCase() == lang.toLowerCase() ||
          l.code.toLowerCase() == lang.toLowerCase(),
    );
    if (match != null && match.code.toLowerCase() == chanCode) {
      AppSnackbar.info(
        'This video is already in ${match.name} (Channel Language). Dubbing is available for other languages.',
      );
      return;
    }

    if (aiDubbingLanguages.contains(lang)) {
      aiDubbingLanguages.remove(lang);
    } else {
      aiDubbingLanguages.add(lang);
      if (!aiTranslationLanguages.contains(lang)) {
        aiTranslationLanguages.add(lang);
      }
    }
  }

  /// Build the AI features map for Firestore.
  @override
  Map<String, dynamic> buildFeaturesMap({String? pipelineStage}) {
    final effectiveTier = aiFactCheckEnabled.value
        ? (aiFactCheckTier.value.isEmpty || aiFactCheckTier.value == 'none'
            ? 'full_ground'
            : aiFactCheckTier.value)
        : 'none';
    final map = AIFeatures(
      genLangSubs: aiGenerateSubtitles.value,
      generateDubbing: aiGenerateDubbing.value,
      translationLanguages: List<String>.from(aiTranslationLanguages),
      tts: TTSConfig(
        enabled: aiGenerateDubbing.value,
        voiceType: aiTTSVoiceType.value == 'cloned'
            ? 'voice_clone'
            : 'standard',
      ),
      factChecking: aiFactCheckEnabled.value,
      factCheckTier: effectiveTier,
      factCheckReviewMode: aiFactCheckReviewMode.value,
      diarization: aiDiarizationEnabled.value,
      summary: true,
      autoChapters: aiChaptersEnabled.value,
      pipelineStage: pipelineStage,
    ).toMap();
    map['providedSources'] = List<String>.from(providedSources);
    map['dubbingLanguages'] = List<String>.from(aiDubbingLanguages);
    map['isFactCheckApproved'] =
        aiFactCheckReviewMode.value != 'first_to_creator';
    map['enableFactCheck'] = aiFactCheckEnabled.value;
    map['truthVerification'] = aiFactCheckEnabled.value;
    map['enableDiarization'] = aiDiarizationEnabled.value;
    map['speakerDiarization'] = aiDiarizationEnabled.value;
    map['enableLipSync'] = aiLipSyncEnabled.value;
    map['lipSync'] = aiLipSyncEnabled.value;
    map['dubbingTier'] = aiDubbingTier.value;
    map['cinemaGrade'] = aiCinemaGradeEnabled.value;
    map['stemIsolation'] = aiStemIsolationEnabled.value;
    map['isometryMode'] = (aiDubbingTier.value == 'video_ultra' || aiDubbingTier.value == 'audio_ultra') ? 'strict_syllable' : 'natural';
    map['uncannyMitigation'] = aiDubbingTier.value == 'audio_ultra' ? 'cadence_lock' : 'none';
    map['autoChaptersEnabled'] = aiChaptersEnabled.value;
    map['chapters'] = aiChaptersEnabled.value;
    return map;
  }

  /// Pick a voice sample for TTS cloning.
  Future<void> pickVoiceSample() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        voiceSampleFile.value = result.files.first;
        AppSnackbar.success(
          'Voice sample selected: ${result.files.first.name}',
        );
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'UploadController.pickVoiceSample');
      AppSnackbar.error('Unable to select voice sample. Please try again.');
    }
  }
}
