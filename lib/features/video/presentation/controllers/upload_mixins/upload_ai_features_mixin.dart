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

  /// Toggle expansion of the unified AI features studio section
  @override
  void toggleAiFeaturesExpanded() {
    isAiFeaturesExpanded.value = !isAiFeaturesExpanded.value;
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
    final clean = lang.trim().toLowerCase();
    if (aiTranslationLanguages.contains(lang)) {
      aiTranslationLanguages.remove(lang);
      if (aiDubbingLanguages.contains(lang)) {
        aiDubbingLanguages.remove(lang);
      }
    } else {
      // Collision guard: If device file already attached for this language, replace it cleanly
      if (attachedSubtitleFiles.containsKey(clean) || attachedSubtitleFiles.containsKey(lang)) {
        attachedSubtitleFiles.remove(clean);
        attachedSubtitleFiles.remove(lang);
        AppSnackbar.info('Replaced device subtitle file with AI-queued ${getLanguageName(lang)}.');
      }
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

    final clean = lang.trim().toLowerCase();
    if (aiDubbingLanguages.contains(lang)) {
      aiDubbingLanguages.remove(lang);
    } else {
      // Collision guard: If device audio already attached for this language, replace it cleanly
      if (attachedAudioFiles.containsKey(clean) || attachedAudioFiles.containsKey(lang)) {
        attachedAudioFiles.remove(clean);
        attachedAudioFiles.remove(lang);
        attachedAudioRoles.remove(clean);
        attachedAudioRoles.remove(lang);
        AppSnackbar.info('Replaced device audio track with AI-queued ${getLanguageName(lang)}.');
      }
      aiDubbingLanguages.add(lang);
      if (!aiTranslationLanguages.contains(lang)) {
        aiTranslationLanguages.add(lang);
      }
    }
  }

  /// Resolves language code to human-friendly display name.
  @override
  String getLanguageName(String code) {
    final clean = code.trim().toLowerCase();
    final match = supportedLanguages.firstWhereOrNull(
      (l) => l.code.toLowerCase() == clean || l.name.toLowerCase() == clean,
    );
    if (match != null) {
      return match.nativeName.isNotEmpty && match.nativeName != match.name
          ? '${match.name} (${match.nativeName})'
          : match.name;
    }
    return code.toUpperCase();
  }

  /// Consolidated list of all configured languages across base, AI queues, and attached files.
  @override
  List<String> get allConfiguredLanguages {
    final result = <String>{};
    final base = effectiveVideoLanguage.trim().toLowerCase();
    if (base.isNotEmpty) result.add(base);

    for (final l in aiTranslationLanguages) {
      final c = l.trim().toLowerCase();
      if (c.isNotEmpty) result.add(c);
    }
    for (final l in aiDubbingLanguages) {
      final c = l.trim().toLowerCase();
      if (c.isNotEmpty) result.add(c);
    }
    for (final l in attachedSubtitleFiles.keys) {
      final c = l.trim().toLowerCase();
      if (c.isNotEmpty) result.add(c);
    }
    for (final l in attachedAudioFiles.keys) {
      final c = l.trim().toLowerCase();
      if (c.isNotEmpty) result.add(c);
    }
    return result.toList();
  }

  /// Whether any extra subtitle, dubbing, or device track has been staged.
  @override
  bool get hasConfiguredLanguageTracks =>
      attachedSubtitleFiles.isNotEmpty ||
      attachedAudioFiles.isNotEmpty ||
      aiTranslationLanguages.isNotEmpty ||
      aiDubbingLanguages.isNotEmpty;

  /// Attach a device subtitle file (.srt / .vtt) with collision cleanup.
  @override
  void attachDeviceSubtitle(String langCode, PlatformFile file) {
    final clean = langCode.trim().toLowerCase();
    // Collision guard: If this language was queued for AI translation, clear it
    if (aiTranslationLanguages.contains(langCode) || aiTranslationLanguages.contains(clean)) {
      aiTranslationLanguages.remove(langCode);
      aiTranslationLanguages.remove(clean);
      if (aiTranslationLanguages.isEmpty) {
        aiGenerateSubtitles.value = false;
      }
      AppSnackbar.info('Replaced AI-queued ${getLanguageName(langCode)} with device subtitle upload.');
    }
    attachedSubtitleFiles[clean] = file;
    AppSnackbar.success('Attached ${file.name} as ${getLanguageName(langCode)} subtitle track.');
  }

  /// Attach a device audio or video track (.mp3, .wav, .mp4, .mov) with collision cleanup.
  @override
  void attachDeviceAudioTrack(String langCode, PlatformFile file, String role) {
    final clean = langCode.trim().toLowerCase();
    // Collision guard: If this language was queued for AI dubbing, clear it
    if (aiDubbingLanguages.contains(langCode) || aiDubbingLanguages.contains(clean)) {
      aiDubbingLanguages.remove(langCode);
      aiDubbingLanguages.remove(clean);
      if (aiDubbingLanguages.isEmpty) {
        aiGenerateDubbing.value = false;
      }
      AppSnackbar.info('Replaced AI-queued ${getLanguageName(langCode)} with device audio track.');
    }
    attachedAudioFiles[clean] = file;
    attachedAudioRoles[clean] = role.isNotEmpty ? role : 'Dubbed Audio';
    AppSnackbar.success('Attached ${file.name} as ${getLanguageName(langCode)} ($role).');
  }

  /// Remove a language track from AI queues and/or device attachments.
  @override
  void removeLanguageTrack(String langCode, {bool removeSubtitle = true, bool removeAudio = true}) {
    final clean = langCode.trim().toLowerCase();
    if (removeSubtitle) {
      attachedSubtitleFiles.remove(clean);
      attachedSubtitleFiles.remove(langCode);
      aiTranslationLanguages.remove(clean);
      aiTranslationLanguages.remove(langCode);
      if (aiTranslationLanguages.isEmpty) {
        aiGenerateSubtitles.value = false;
      }
    }
    if (removeAudio) {
      attachedAudioFiles.remove(clean);
      attachedAudioFiles.remove(langCode);
      attachedAudioRoles.remove(clean);
      attachedAudioRoles.remove(langCode);
      aiDubbingLanguages.remove(clean);
      aiDubbingLanguages.remove(langCode);
      if (aiDubbingLanguages.isEmpty) {
        aiGenerateDubbing.value = false;
      }
    }
    if (activePreviewLanguage.value == clean || activePreviewLanguage.value == langCode) {
      activePreviewLanguage.value = '';
    }
    AppSnackbar.info('Removed ${getLanguageName(langCode)} track.');
  }

  /// Reset all staged AI and device language tracks (e.g. on video file replacement).
  @override
  void resetAllLanguageTracks() {
    attachedSubtitleFiles.clear();
    attachedAudioFiles.clear();
    attachedAudioRoles.clear();
    aiTranslationLanguages.clear();
    aiDubbingLanguages.clear();
    aiGenerateDubbing.value = false;
    activePreviewLanguage.value = '';
  }

  /// Build the AI features map for Firestore.
  @override
  Map<String, dynamic> buildFeaturesMap({String? pipelineStage}) {
    final effectiveTier = aiFactCheckEnabled.value
        ? (aiFactCheckTier.value.isEmpty || aiFactCheckTier.value == 'none'
            ? 'full_ground'
            : aiFactCheckTier.value)
        : 'none';
    final isManualDubbingRequested =
        aiGenerateDubbing.value && aiDubbingLanguages.isNotEmpty;
    final map = AIFeatures(
      genLangSubs: aiGenerateSubtitles.value,
      generateDubbing: isManualDubbingRequested,
      translationLanguages: List<String>.from(aiTranslationLanguages),
      tts: TTSConfig(
        enabled: isManualDubbingRequested,
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
    map['dubbingLanguages'] = isManualDubbingRequested
        ? List<String>.from(aiDubbingLanguages)
        : <String>[];
    map['spokenLanguages'] = spokenLanguages.isNotEmpty
        ? List<String>.from(spokenLanguages)
        : [effectiveVideoLanguage];
    map['primaryLanguage'] = effectiveVideoLanguage;
    map['sourceLanguage'] = effectiveVideoLanguage;
    map['isMultilingualSpoken'] = isMultilingualSpoken.value || spokenLanguages.length > 1;
    map['isFactCheckApproved'] =
        aiFactCheckReviewMode.value != 'first_to_creator';
    map['enableFactCheck'] = aiFactCheckEnabled.value;
    map['truthVerification'] = aiFactCheckEnabled.value;
    map['enableDiarization'] = aiDiarizationEnabled.value;
    map['speakerDiarization'] = aiDiarizationEnabled.value;
    map['dubbingTier'] = isManualDubbingRequested ? aiDubbingTier.value : 'none';
    map['dubbingMode'] = isManualDubbingRequested
        ? (aiTTSVoiceType.value == 'cloned' ? 'voice_clone' : 'standard')
        : 'none';
    map['cinemaGrade'] = false;
    map['stemIsolation'] = isManualDubbingRequested;
    map['isometryMode'] = 'strict_syllable';
    map['uncannyMitigation'] = 'cadence_lock';
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
