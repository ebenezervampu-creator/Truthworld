import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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
    'whispers',
    'excited',
    'laughs',
    'sighs',
    'sorrowful',
    'angry',
    'shouts',
    'gasps',
    'calm',
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
  final RxBool hasPendingRemaster = false.obs;
  final RxBool hasPendingTimingSave = false.obs;
  final RxnInt regeneratingSegmentIndex = RxnInt();
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
      final updatedModel = DubbingEditableSegmentModel.fromMap(updatedMap);

      segments[idx] = updatedModel.copyWith(
        synthesizedAudioUrl: playableUrl ?? updatedModel.synthesizedAudioUrl,
      );
      _segmentControllers[segmentIndex]?.text = updatedModel.displayText;
      manifestVersion.value =
          (data['version'] as num?)?.toInt() ?? manifestVersion.value;
      hasPendingRemaster.value = true;
      AppSnackbar.success(
        'Line ${segmentIndex + 1} regenerated. Click Remaster & Publish when ready.',
      );
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
