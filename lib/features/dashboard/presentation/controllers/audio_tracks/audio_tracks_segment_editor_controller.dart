import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class DubbingEditableSegmentModel {
  final int index;
  final int startMs;
  final int endMs;
  final String speaker;
  final String originalText;
  final String translatedText;
  final String? editedText;
  final String? emotionTag;
  final double? energyDb;
  final double? stabilityOverride;
  final double? similarityBoostOverride;
  final double? pitchRangeSemitones;
  final String? voiceQuality;
  final double? syllableBudgetCompliance;
  final String? deliveryStyle;
  final String? synthesizedAudioUrl;
  final int? actualSynthesizedDurationMs;

  const DubbingEditableSegmentModel({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.speaker,
    required this.originalText,
    required this.translatedText,
    this.editedText,
    this.emotionTag,
    this.energyDb,
    this.stabilityOverride,
    this.similarityBoostOverride,
    this.pitchRangeSemitones,
    this.voiceQuality,
    this.syllableBudgetCompliance,
    this.deliveryStyle,
    this.synthesizedAudioUrl,
    this.actualSynthesizedDurationMs,
  });

  String get displayText =>
      (editedText != null && editedText!.trim().isNotEmpty)
          ? editedText!
          : translatedText;

  factory DubbingEditableSegmentModel.fromMap(Map<String, dynamic> map) {
    return DubbingEditableSegmentModel(
      index: (map['index'] as num?)?.toInt() ?? 0,
      startMs: (map['startMs'] as num?)?.toInt() ?? 0,
      endMs: (map['endMs'] as num?)?.toInt() ?? 0,
      speaker: (map['speaker'] as String?) ?? 'speaker_0',
      originalText: (map['originalText'] as String?) ?? '',
      translatedText: (map['translatedText'] as String?) ?? '',
      editedText: map['editedText'] as String?,
      emotionTag: map['emotionTag'] as String?,
      energyDb: (map['energyDb'] as num?)?.toDouble(),
      stabilityOverride: (map['stabilityOverride'] as num?)?.toDouble(),
      similarityBoostOverride:
          (map['similarityBoostOverride'] as num?)?.toDouble(),
      pitchRangeSemitones: (map['pitchRangeSemitones'] as num?)?.toDouble(),
      voiceQuality: map['voiceQuality'] as String?,
      syllableBudgetCompliance:
          (map['syllableBudgetCompliance'] as num?)?.toDouble(),
      deliveryStyle: map['deliveryStyle'] as String?,
      synthesizedAudioUrl: map['synthesizedAudioUrl'] as String?,
      actualSynthesizedDurationMs:
          (map['actualSynthesizedDurationMs'] as num?)?.toInt() ??
              (map['durationMs'] as num?)?.toInt(),
    );
  }

  DubbingEditableSegmentModel copyWith({
    int? startMs,
    int? endMs,
    String? translatedText,
    String? editedText,
    String? emotionTag,
    bool clearEmotionTag = false,
    double? energyDb,
    double? stabilityOverride,
    double? similarityBoostOverride,
    double? pitchRangeSemitones,
    String? voiceQuality,
    double? syllableBudgetCompliance,
    String? deliveryStyle,
    String? synthesizedAudioUrl,
    int? actualSynthesizedDurationMs,
  }) {
    return DubbingEditableSegmentModel(
      index: index,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      speaker: speaker,
      originalText: originalText,
      translatedText: translatedText ?? this.translatedText,
      editedText: editedText ?? this.editedText,
      emotionTag: clearEmotionTag ? null : (emotionTag ?? this.emotionTag),
      energyDb: energyDb ?? this.energyDb,
      stabilityOverride: stabilityOverride ?? this.stabilityOverride,
      similarityBoostOverride:
          similarityBoostOverride ?? this.similarityBoostOverride,
      pitchRangeSemitones: pitchRangeSemitones ?? this.pitchRangeSemitones,
      voiceQuality: voiceQuality ?? this.voiceQuality,
      syllableBudgetCompliance:
          syllableBudgetCompliance ?? this.syllableBudgetCompliance,
      deliveryStyle: deliveryStyle ?? this.deliveryStyle,
      synthesizedAudioUrl: synthesizedAudioUrl ?? this.synthesizedAudioUrl,
      actualSynthesizedDurationMs:
          actualSynthesizedDurationMs ?? this.actualSynthesizedDurationMs,
    );
  }
}

class PronunciationRuleModel {
  final String id;
  final String term;
  final String replacement;
  final bool caseSensitive;

  const PronunciationRuleModel({
    required this.id,
    required this.term,
    required this.replacement,
    this.caseSensitive = false,
  });

  factory PronunciationRuleModel.fromMap(Map<String, dynamic> map) {
    return PronunciationRuleModel(
      id: (map['id'] as String?) ?? '',
      term: (map['term'] as String?) ?? '',
      replacement: (map['replacement'] as String?) ??
          (map['ipaOrPhonetic'] as String?) ??
          '',
      caseSensitive: map['caseSensitive'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'term': term,
        'replacement': replacement,
        'caseSensitive': caseSensitive,
      };
}

class DubbingSegmentEditorController extends GetxController {
  static const String _tag = 'DubbingSegmentEditorController';

  static const List<String> supportedEmotionTags = [
    'excited',
    'whispers',
    'laughs',
    'said angrily',
    'sad',
    'sarcastic',
    'calm',
    'sighs',
    'sorrowful',
    'angry',
    'shouts',
    'gasps',
    'serious',
  ];

  final String videoId;
  final String languageCode;
  final String languageName;
  final Future<void> Function()? onRemastered;

  DubbingSegmentEditorController({
    required this.videoId,
    required this.languageCode,
    required this.languageName,
    this.onRemastered,
  });

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  final RxBool isLoading = true.obs;
  final RxBool isSavingGlossary = false.obs;
  final RxBool isSavingTimings = false.obs;
  final RxBool isRemastering = false.obs;
  final RxBool isExporting = false.obs;
  final RxBool hasPendingRemaster = false.obs;
  final RxBool hasPendingTimingSave = false.obs;
  final RxnInt regeneratingSegmentIndex = RxnInt();
  final RxnInt retranslatingSegmentIndex = RxnInt();
  final RxnInt playingSegmentIndex = RxnInt();
  final RxnInt selectedSegmentIndex = RxnInt();
  final RxInt manifestVersion = 1.obs;
  final RxInt totalDurationMs = 0.obs;
  final RxBool hasMneStem = false.obs;
  final RxDouble mneGain = 1.0.obs;
  final RxDouble dialogueGain = 1.0.obs;
  final RxDouble timelineZoom = 1.0.obs;
  final RxString resolvedJobId = ''.obs;
  final RxString masterAudioUrl = ''.obs;
  final RxString errorMessage = ''.obs;

  final Set<int> _dirtyTimingIndices = <int>{};

  final RxList<DubbingEditableSegmentModel> segments =
      <DubbingEditableSegmentModel>[].obs;
  final RxList<PronunciationRuleModel> glossary =
      <PronunciationRuleModel>[].obs;

  final Map<int, TextEditingController> _segmentControllers = {};
  final TextEditingController glossaryTermController = TextEditingController();
  final TextEditingController glossaryReplacementController =
      TextEditingController();

  VideoPlayerController? _audioPreviewController;

  @override
  void onInit() {
    super.onInit();
    loadManifest();
  }

  TextEditingController controllerForSegment(DubbingEditableSegmentModel seg) {
    return _segmentControllers.putIfAbsent(
      seg.index,
      () => TextEditingController(text: seg.displayText),
    );
  }

  Future<void> loadManifest() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final callable = _functions.httpsCallable('getDubbingEditorManifest');
      final response = await callable.call(<String, dynamic>{
        'videoId': videoId,
        'language': languageCode,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final manifest = Map<String, dynamic>.from(data['manifest'] as Map);

      resolvedJobId.value = (manifest['jobId'] as String?) ?? '';
      manifestVersion.value = (manifest['version'] as num?)?.toInt() ?? 1;
      masterAudioUrl.value = (manifest['masterAudioUrl'] as String?) ?? '';
      final mneStemStr = (manifest['mneStemUrl'] as String?) ?? '';
      hasMneStem.value = mneStemStr.trim().isNotEmpty;
      mneGain.value = ((manifest['mneGain'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.0, 2.0);
      dialogueGain.value =
          ((manifest['dialogueGain'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.2, 2.0);
      _dirtyTimingIndices.clear();
      hasPendingTimingSave.value = false;

      for (final c in _segmentControllers.values) {
        c.dispose();
      }
      _segmentControllers.clear();

      final rawSegments = manifest['segments'] as List<dynamic>? ?? [];
      final parsedSegments = rawSegments
          .map((item) => DubbingEditableSegmentModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
      segments.assignAll(parsedSegments);

      final parsedDurationMs =
          (manifest['totalDurationMs'] as num?)?.toInt() ?? 0;
      if (parsedDurationMs > 0) {
        totalDurationMs.value = parsedDurationMs;
      } else if (parsedSegments.isNotEmpty) {
        totalDurationMs.value = parsedSegments
            .map((s) => s.endMs)
            .reduce((a, b) => a > b ? a : b);
      } else {
        totalDurationMs.value = 0;
      }
      if (parsedSegments.isNotEmpty) {
        selectedSegmentIndex.value = parsedSegments.first.index;
      }

      for (final seg in parsedSegments) {
        _segmentControllers[seg.index] =
            TextEditingController(text: seg.displayText);
      }

      final rawGlossary =
          manifest['pronunciationGlossary'] as List<dynamic>? ?? [];
      glossary.assignAll(
        rawGlossary.map(
          (item) => PronunciationRuleModel.fromMap(
              Map<String, dynamic>.from(item as Map)),
        ),
      );
    } on FirebaseFunctionsException catch (fe) {
      LoggerService().warning(
        'Failed loading dubbing manifest: ${fe.code}',
        tag: _tag,
      );
      errorMessage.value = fe.code == 'not-found'
          ? 'No interactive segment manifest was found for $languageName yet. Newly generated dubs automatically create editable timelines.'
          : 'Unable to load the dubbing editor right now. Please try again.';
    } catch (e, st) {
      LoggerService().error(
        'Unexpected manifest load issue',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      errorMessage.value =
          'Unable to load the dubbing editor right now. Please check your connection and try again.';
    } finally {
      isLoading.value = false;
    }
  }

  void setSegmentEmotionTag(int segmentIndex, String? emotionTag) {
    final idx = segments.indexWhere((s) => s.index == segmentIndex);
    if (idx == -1) return;
    segments[idx] = segments[idx].copyWith(
      emotionTag: emotionTag,
      clearEmotionTag: emotionTag == null || emotionTag.isEmpty,
    );
  }

  void setSegmentStability(int segmentIndex, double stability) {
    final idx = segments.indexWhere((s) => s.index == segmentIndex);
    if (idx == -1) return;
    segments[idx] = segments[idx].copyWith(stabilityOverride: stability);
  }

  Future<void> regenerateSegment(int segmentIndex) async {
    if (resolvedJobId.value.isEmpty) return;
    final idx = segments.indexWhere((s) => s.index == segmentIndex);
    if (idx == -1) return;

    final seg = segments[idx];
    final editedText = _segmentControllers[segmentIndex]?.text.trim() ?? '';
    if (editedText.isEmpty) {
      AppSnackbar.warning('Please enter dialogue text before regenerating.');
      return;
    }

    regeneratingSegmentIndex.value = segmentIndex;
    try {
      final callable =
          _functions.httpsCallable('updateDubbingSegmentAndResynthesize');
      final response = await callable.call(<String, dynamic>{
        'jobId': resolvedJobId.value,
        'language': languageCode,
        'segmentIndex': segmentIndex,
        'editedText': editedText,
        'emotionTag': seg.emotionTag,
        if (seg.stabilityOverride != null)
          'stabilityOverride': seg.stabilityOverride,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final updatedMap = Map<String, dynamic>.from(data['segment'] as Map);
      final playableUrl = data['playableAudioUrl'] as String?;
      final terminologyWarning = data['terminologyWarning'] as String?;
      final updatedModel = DubbingEditableSegmentModel.fromMap(updatedMap);

      segments[idx] = updatedModel.copyWith(
        synthesizedAudioUrl: playableUrl ?? updatedModel.synthesizedAudioUrl,
      );
      _segmentControllers[segmentIndex]?.text = updatedModel.displayText;
      manifestVersion.value =
          (data['version'] as num?)?.toInt() ?? manifestVersion.value;
      hasPendingRemaster.value = true;
      if (terminologyWarning != null && terminologyWarning.isNotEmpty) {
        AppSnackbar.warning(terminologyWarning);
      } else {
        AppSnackbar.success(
          'Line ${segmentIndex + 1} regenerated. Click Remaster & Publish when ready.',
        );
      }
    } catch (e, st) {
      LoggerService().error(
        'Failed regenerating segment $segmentIndex',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      AppSnackbar.warning(
        'Unable to regenerate line ${segmentIndex + 1} right now. Please try again.',
      );
    } finally {
      regeneratingSegmentIndex.value = null;
    }
  }

  /// Auto-translates or fits a segment's translation to its exact speech timeline window.
  Future<void> autoFitSegmentTranslation(
    int segmentIndex, {
    String mode = 'fit',
  }) async {
    if (resolvedJobId.value.isEmpty) return;
    final idx = segments.indexWhere((s) => s.index == segmentIndex);
    if (idx == -1) return;

    final draftText = _segmentControllers[segmentIndex]?.text.trim() ?? '';
    retranslatingSegmentIndex.value = segmentIndex;
    try {
      final callable = _functions.httpsCallable('retranslateDubbingSegment');
      final response = await callable.call(<String, dynamic>{
        'jobId': resolvedJobId.value,
        'language': languageCode,
        'segmentIndex': segmentIndex,
        'mode': mode,
        if (draftText.isNotEmpty) 'draftText': draftText,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final fittedText = (data['translatedText'] as String?)?.trim() ?? '';
      final compliance =
          (data['syllableBudgetCompliance'] as num?)?.toDouble();
      final warning = data['terminologyWarning'] as String?;

      if (fittedText.isNotEmpty) {
        _segmentControllers[segmentIndex]?.text = fittedText;
        segments[idx] = segments[idx].copyWith(
          editedText: fittedText,
          syllableBudgetCompliance:
              compliance ?? segments[idx].syllableBudgetCompliance,
        );
      }

      if (warning != null && warning.isNotEmpty) {
        AppSnackbar.warning(warning);
      } else {
        AppSnackbar.success(
          'Line ${segmentIndex + 1} fitted to timeline. Click Regenerate to synthesize.',
        );
      }
    } catch (e, st) {
      LoggerService().error(
        'Failed auto-fitting segment $segmentIndex',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      AppSnackbar.warning(
        'Unable to auto-fit line ${segmentIndex + 1} right now. Please try again.',
      );
    } finally {
      retranslatingSegmentIndex.value = null;
    }
  }

  Future<void> playSegmentPreview(DubbingEditableSegmentModel seg) async {
    final url = seg.synthesizedAudioUrl;
    if (url == null || url.isEmpty) {
      AppSnackbar.info(
        'Audio preview is not yet available for this line. Regenerate the line to preview it.',
      );
      return;
    }

    if (playingSegmentIndex.value == seg.index) {
      await _stopAudioPreview();
      return;
    }

    await _stopAudioPreview();
    playingSegmentIndex.value = seg.index;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _audioPreviewController = controller;
      await controller.initialize();
      controller.addListener(() {
        if (controller.value.isCompleted) {
          playingSegmentIndex.value = null;
        }
      });
      await controller.play();
    } catch (e, st) {
      LoggerService().warning(
        'Preview playback error',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      playingSegmentIndex.value = null;
      AppSnackbar.warning(
        'Could not play this audio line right now. Please try again.',
      );
    }
  }

  Future<void> _stopAudioPreview() async {
    playingSegmentIndex.value = null;
    final ctrl = _audioPreviewController;
    _audioPreviewController = null;
    if (ctrl != null) {
      await ctrl.pause().catchError((_) {});
      await ctrl.dispose().catchError((_) {});
    }
  }

  void addGlossaryRule() {
    final term = glossaryTermController.text.trim();
    final replacement = glossaryReplacementController.text.trim();
    if (term.isEmpty || replacement.isEmpty) {
      AppSnackbar.warning(
        'Please enter both a word/brand and how it should be pronounced.',
      );
      return;
    }
    glossary.add(
      PronunciationRuleModel(
        id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
        term: term,
        replacement: replacement,
      ),
    );
    glossaryTermController.clear();
    glossaryReplacementController.clear();
  }

  void removeGlossaryRule(String id) {
    glossary.removeWhere((r) => r.id == id);
  }

  Future<void> saveGlossaryRules() async {
    if (resolvedJobId.value.isEmpty) return;
    isSavingGlossary.value = true;
    try {
      final callable =
          _functions.httpsCallable('saveDubbingPronunciationGlossary');
      final response = await callable.call(<String, dynamic>{
        'jobId': resolvedJobId.value,
        'language': languageCode,
        'rules': glossary.map((r) => r.toMap()).toList(),
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      manifestVersion.value =
          (data['version'] as num?)?.toInt() ?? manifestVersion.value;
      hasPendingRemaster.value = true;
      AppSnackbar.success(
        'Pronunciation glossary saved (${glossary.length} rules).',
      );
    } catch (e, st) {
      LoggerService().error(
        'Failed saving glossary',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      AppSnackbar.warning(
        'Unable to save pronunciation rules right now. Please try again.',
      );
    } finally {
      isSavingGlossary.value = false;
    }
  }

  void selectSegment(int segmentIndex) {
    selectedSegmentIndex.value = segmentIndex;
  }

  void setMneGain(double value) {
    mneGain.value = double.parse(value.clamp(0.0, 2.0).toStringAsFixed(2));
    hasPendingRemaster.value = true;
  }

  void setDialogueGain(double value) {
    dialogueGain.value =
        double.parse(value.clamp(0.2, 2.0).toStringAsFixed(2));
    hasPendingRemaster.value = true;
  }

  void setTimelineZoom(double zoom) {
    timelineZoom.value = zoom.clamp(1.0, 4.0);
  }

  void updateSegmentTiming(int segmentIndex, int newStartMs, int newEndMs) {
    final idx = segments.indexWhere((s) => s.index == segmentIndex);
    if (idx < 0) return;

    final maxTimelineMs = totalDurationMs.value > 0
        ? totalDurationMs.value
        : segments.map((s) => s.endMs).reduce((a, b) => a > b ? a : b) + 5000;
    final clampedStart = newStartMs.clamp(0, maxTimelineMs - 200);
    final clampedEnd = newEndMs.clamp(clampedStart + 200, maxTimelineMs);

    segments[idx] = segments[idx].copyWith(
      startMs: clampedStart,
      endMs: clampedEnd,
    );
    _dirtyTimingIndices.add(segmentIndex);
    hasPendingTimingSave.value = true;
    hasPendingRemaster.value = true;
  }

  Future<bool> saveSegmentTimings({bool silent = false}) async {
    if (resolvedJobId.value.isEmpty || _dirtyTimingIndices.isEmpty) {
      return true;
    }
    isSavingTimings.value = true;
    try {
      final dirtyList = _dirtyTimingIndices
          .map((segIdx) => segments.firstWhereOrNull((s) => s.index == segIdx))
          .whereType<DubbingEditableSegmentModel>()
          .map((s) => <String, dynamic>{
                'segmentIndex': s.index,
                'startMs': s.startMs,
                'endMs': s.endMs,
              })
          .toList();
      if (dirtyList.isEmpty) {
        _dirtyTimingIndices.clear();
        hasPendingTimingSave.value = false;
        return true;
      }

      final callable = _functions.httpsCallable('updateDubbingSegmentTimings');
      final response = await callable.call(<String, dynamic>{
        'jobId': resolvedJobId.value,
        'language': languageCode,
        'timings': dirtyList,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      manifestVersion.value =
          (data['version'] as num?)?.toInt() ?? manifestVersion.value;
      _dirtyTimingIndices.clear();
      hasPendingTimingSave.value = false;
      hasPendingRemaster.value = true;
      if (!silent) {
        AppSnackbar.success(
          'Saved timing adjustments for ${dirtyList.length} segment(s).',
        );
      }
      return true;
    } catch (e, st) {
      LoggerService().error(
        'Failed saving dubbing segment timings',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      if (!silent) {
        AppSnackbar.warning(
          'Unable to save timeline timing changes right now. Please try again.',
        );
      }
      return false;
    } finally {
      isSavingTimings.value = false;
    }
  }

  Future<void> remasterAndPublish() async {
    if (resolvedJobId.value.isEmpty) return;
    await _stopAudioPreview();
    isRemastering.value = true;
    try {
      if (_dirtyTimingIndices.isNotEmpty) {
        await saveSegmentTimings(silent: true);
      }
      final callable = _functions.httpsCallable('remasterDubbedAudioTrack');
      final response = await callable.call(<String, dynamic>{
        'jobId': resolvedJobId.value,
        'language': languageCode,
        'mneGain': mneGain.value,
        'dialogueGain': dialogueGain.value,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      masterAudioUrl.value = (data['masterAudioUrl'] as String?) ?? '';
      manifestVersion.value =
          (data['version'] as num?)?.toInt() ?? manifestVersion.value;
      hasPendingRemaster.value = false;
      if (onRemastered != null) {
        await onRemastered!();
      }
      AppSnackbar.success(
        '$languageName audio track remastered and published with studio M&E + Dialogue mix.',
      );
    } catch (e, st) {
      LoggerService().error(
        'Failed remastering dubbed audio track',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      AppSnackbar.warning(
        'Unable to publish the remastered audio track right now. Please try again.',
      );
    } finally {
      isRemastering.value = false;
    }
  }

  Future<void> exportPackage({String format = 'all'}) async {
    if (resolvedJobId.value.isEmpty && videoId.isEmpty) {
      AppSnackbar.warning('Timeline data is not ready to export yet.');
      return;
    }
    isExporting.value = true;
    try {
      final callable = _functions.httpsCallable('getDubbingExportPackage');
      final response = await callable.call(<String, dynamic>{
        if (resolvedJobId.value.isNotEmpty) 'jobId': resolvedJobId.value,
        if (videoId.isNotEmpty) 'videoId': videoId,
        'language': languageCode,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final pkg = Map<String, dynamic>.from(data['package'] as Map);
      final rawTitle = (pkg['title'] as String?)?.trim() ?? 'truthworld_video';
      final cleanTitle = rawTitle
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');

      final videoUrl = pkg['videoUrl'] as String?;
      final audioUrl = pkg['audioUrl'] as String?;
      final dialogueAudioUrl = pkg['dialogueAudioUrl'] as String?;
      final vocalsStemUrl = pkg['vocalsStemUrl'] as String?;
      final backgroundStemUrl = pkg['backgroundStemUrl'] as String?;
      final translationJsonUrl = pkg['translationJsonUrl'] as String?;
      final reportJsonUrl = pkg['reportJsonUrl'] as String?;
      final srtContent = pkg['srtContent'] as String?;
      final vttContent = pkg['vttContent'] as String?;

      var downloadCount = 0;

      if (format == 'all' || format == 'video') {
        if (videoUrl != null && videoUrl.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            videoUrl,
            'video_with_${languageCode}_dub.mp4',
          );
          downloadCount++;
        } else if (audioUrl != null && audioUrl.isNotEmpty && format == 'all') {
          await DownloadHelper.downloadFromUrl(
            audioUrl,
            'dub_$languageCode.mp3',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'srt') {
        if (srtContent != null && srtContent.isNotEmpty) {
          await DownloadHelper.downloadText(
            srtContent,
            '${cleanTitle}_$languageCode.srt',
            mimeType: 'application/x-subrip',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'vtt') {
        if (vttContent != null && vttContent.isNotEmpty) {
          await DownloadHelper.downloadText(
            vttContent,
            '${cleanTitle}_$languageCode.vtt',
            mimeType: 'text/vtt',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'audio') {
        final url = audioUrl ?? masterAudioUrl.value;
        if (url.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            url,
            'dub_$languageCode.mp3',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'dialogue') {
        if (dialogueAudioUrl != null && dialogueAudioUrl.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            dialogueAudioUrl,
            'dialogue_$languageCode.mp3',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'vocals') {
        if (vocalsStemUrl != null && vocalsStemUrl.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            vocalsStemUrl,
            'vocals_stem.mp3',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'background') {
        if (backgroundStemUrl != null && backgroundStemUrl.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            backgroundStemUrl,
            'background_stem.mp3',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'translation') {
        if (translationJsonUrl != null && translationJsonUrl.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            translationJsonUrl,
            'translation_$languageCode.json',
          );
          downloadCount++;
        }
      }

      if (format == 'all' || format == 'report') {
        if (reportJsonUrl != null && reportJsonUrl.isNotEmpty) {
          await DownloadHelper.downloadFromUrl(
            reportJsonUrl,
            'report.json',
          );
          downloadCount++;
        }
      }

      if (downloadCount > 0) {
        AppSnackbar.success(
          format == 'all'
              ? 'Exported $downloadCount asset(s) ($languageName video & aligned captions).'
              : 'Exported $languageName asset successfully.',
        );
      } else {
        AppSnackbar.info(
          'No matching export assets are ready yet. Try clicking "Remaster & Publish" first.',
        );
      }
    } catch (e, st) {
      LoggerService().error(
        'Failed exporting dubbing package',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      AppSnackbar.warning(
        'Unable to export dubbing assets right now. Please try again.',
      );
    } finally {
      isExporting.value = false;
    }
  }

  void showExportModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.bgSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.file_download_outlined,
                        color: textColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export $languageName Studio Package',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Download synchronized media & caption stems in one tap.',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Obx(() {
                  final exporting = isExporting.value;

                  return Column(
                    children: [
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Complete Studio Package (MP4 + Captions)',
                        subtitle:
                            'Synchronized multi-track video with $languageName voice, plus aligned .srt and .vtt captions',
                        icon: Icons.all_inbox_rounded,
                        isRecommended: true,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage();
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Dubbed Video Container (.mp4)',
                        subtitle:
                            'High-definition video muxed with remastered $languageName voice and M&E sound bed',
                        icon: Icons.movie_creation_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'video');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'SubRip Captions (.srt)',
                        subtitle:
                            'Millisecond-aligned SubRip subtitle file for YouTube, VLC, and video editors',
                        icon: Icons.subtitles_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'srt');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'WebVTT Captions (.vtt)',
                        subtitle:
                            'Native HTML5 video caption track for browsers and web platforms',
                        icon: Icons.closed_caption_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'vtt');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Studio Master Audio Track (dub_$languageCode.mp3)',
                        subtitle:
                            'Isolated audio track with vocal balance, EQ, and background ambiance',
                        icon: Icons.audiotrack_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'audio');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Dialogue-only TTS Track (dialogue_$languageCode.mp3)',
                        subtitle:
                            'Clean synthesized speech track without background music or effects',
                        icon: Icons.record_voice_over_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'dialogue');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Vocals Stem (vocals_stem.mp3)',
                        subtitle:
                            'Original isolated vocal stem extracted from the source audio',
                        icon: Icons.mic_none_rounded,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'vocals');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Background Stem (background_stem.mp3)',
                        subtitle:
                            'Music & Effects (M&E) background stem preserved from the source',
                        icon: Icons.music_note_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'background');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Translation JSON (translation_$languageCode.json)',
                        subtitle:
                            'Structured segment-by-segment original & translated script JSON',
                        icon: Icons.translate_rounded,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'translation');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildExportOptionTile(
                        context: modalCtx,
                        title: 'Dubbing Report (report.json)',
                        subtitle:
                            'Complete dubbing job telemetry, stems, and artifact report',
                        icon: Icons.analytics_outlined,
                        isLoading: exporting,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.of(modalCtx).pop();
                          await exportPackage(format: 'report');
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLoading,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required bool isDark,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isRecommended
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecommended
                  ? (isDark ? Colors.white38 : Colors.black26)
                  : borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: subTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatTimestamp(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void onClose() {
    _audioPreviewController?.dispose();
    glossaryTermController.dispose();
    glossaryReplacementController.dispose();
    for (final c in _segmentControllers.values) {
      c.dispose();
    }
    _segmentControllers.clear();
    super.onClose();
  }
}
