/// Mode of dubbing operation.
enum DubbingMode {
  dubbing,
  subtitlesOnly,
}

/// Pipeline progress states for TruthWorld Dubbing.
enum DubbingJobStatus {
  queued,
  pending,
  processing,
  running,
  ingesting,
  demuxing,
  diarizing,
  transcribing,
  awaitingTranscriptionReview,
  translating,
  synthesizingSpeech,
  awaitingPostTtsReview,
  muxingAudio,
  generatingSubtitles,
  completed,
  failed;

  static DubbingJobStatus fromString(String? val) {
    final s = val?.trim().toLowerCase();
    switch (s) {
      case 'queued':
        return DubbingJobStatus.queued;
      case 'pending':
        return DubbingJobStatus.pending;
      case 'processing':
        return DubbingJobStatus.processing;
      case 'running':
        return DubbingJobStatus.running;
      case 'ingesting':
        return DubbingJobStatus.ingesting;
      case 'demuxing':
        return DubbingJobStatus.demuxing;
      case 'diarizing':
        return DubbingJobStatus.diarizing;
      case 'transcribing':
        return DubbingJobStatus.transcribing;
      case 'awaiting_transcription_review':
        return DubbingJobStatus.awaitingTranscriptionReview;
      case 'translating':
        return DubbingJobStatus.translating;
      case 'synthesizing_speech':
        return DubbingJobStatus.synthesizingSpeech;
      case 'awaiting_post_tts_review':
        return DubbingJobStatus.awaitingPostTtsReview;
      case 'muxing_audio':
        return DubbingJobStatus.muxingAudio;
      case 'generating_subtitles':
        return DubbingJobStatus.generatingSubtitles;
      case 'completed':
        return DubbingJobStatus.completed;
      case 'failed':
        return DubbingJobStatus.failed;
      default:
        return DubbingJobStatus.processing;
    }
  }

  String get displayName {
    switch (this) {
      case DubbingJobStatus.queued:
        return 'Queued';
      case DubbingJobStatus.pending:
        return 'Pending';
      case DubbingJobStatus.processing:
        return 'Processing';
      case DubbingJobStatus.running:
        return 'Running';
      case DubbingJobStatus.ingesting:
        return 'Preparing Media';
      case DubbingJobStatus.demuxing:
        return 'Separating Vocals & Audio';
      case DubbingJobStatus.diarizing:
        return 'Detecting Speakers';
      case DubbingJobStatus.transcribing:
        return 'Transcribing Audio';
      case DubbingJobStatus.awaitingTranscriptionReview:
        return 'Script Review Ready';
      case DubbingJobStatus.translating:
        return 'Translating Script';
      case DubbingJobStatus.synthesizingSpeech:
        return 'Generating Dubbed Voices';
      case DubbingJobStatus.awaitingPostTtsReview:
        return 'Ready for Final Review';
      case DubbingJobStatus.muxingAudio:
        return 'Mixing & Balancing Audio';
      case DubbingJobStatus.generatingSubtitles:
        return 'Generating Subtitles';
      case DubbingJobStatus.completed:
        return 'Ready to Download';
      case DubbingJobStatus.failed:
        return 'Process Failed';
    }
  }
}

/// A single dialogue segment in the video.
class DubbingSegment {
  final String id;
  final String speakerId;
  final int startTimeMs;
  final int endTimeMs;
  String originalText;
  String translatedText;
  final String targetLanguage;
  final String? audioStemUrl;
  String status;
  double speedMultiplier;

  DubbingSegment({
    required this.id,
    required this.speakerId,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.originalText,
    required this.translatedText,
    required this.targetLanguage,
    this.audioStemUrl,
    this.status = 'pending',
    this.speedMultiplier = 1.0,
  });

  factory DubbingSegment.fromMap(Map<String, dynamic> map) {
    return DubbingSegment(
      id: map['id']?.toString() ?? '',
      speakerId: map['speakerId']?.toString() ?? 'speaker_1',
      startTimeMs: (map['startTimeMs'] as num?)?.toInt() ?? 0,
      endTimeMs: (map['endTimeMs'] as num?)?.toInt() ?? 0,
      originalText: map['originalText']?.toString() ?? '',
      translatedText: map['translatedText']?.toString() ?? '',
      targetLanguage: map['targetLanguage']?.toString() ?? 'en',
      audioStemUrl: map['audioStemUrl']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      speedMultiplier: (map['speedMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'speakerId': speakerId,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      'originalText': originalText,
      'translatedText': translatedText,
      'targetLanguage': targetLanguage,
      'audioStemUrl': audioStemUrl,
      'status': status,
      'speedMultiplier': speedMultiplier,
    };
  }

  String get timecodeString {
    final startSec = startTimeMs ~/ 1000;
    final startMin = startSec ~/ 60;
    final startRemSec = startSec % 60;
    final endSec = endTimeMs ~/ 1000;
    final endMin = endSec ~/ 60;
    final endRemSec = endSec % 60;

    return '${startMin.toString().padLeft(2, '0')}:${startRemSec.toString().padLeft(2, '0')} - '
        '${endMin.toString().padLeft(2, '0')}:${endRemSec.toString().padLeft(2, '0')}';
  }
}

/// Speaker voice profile mapping for multi-speaker dubbing.
class DubbingSpeaker {
  final String id;
  final String label;
  final String assignedVoiceId;
  final bool isCloned;
  final double pitchAdjustment;
  final double speedAdjustment;

  const DubbingSpeaker({
    required this.id,
    required this.label,
    required this.assignedVoiceId,
    this.isCloned = false,
    this.pitchAdjustment = 0.0,
    this.speedAdjustment = 1.0,
  });

  factory DubbingSpeaker.fromMap(Map<String, dynamic> map) {
    return DubbingSpeaker(
      id: map['speakerId']?.toString() ?? '',
      label: map['speakerLabel']?.toString() ?? 'Speaker',
      assignedVoiceId: map['assignedVoiceId']?.toString() ?? 'default_voice',
      isCloned: map['isClonedVoice'] == true,
      pitchAdjustment: (map['pitchAdjustment'] as num?)?.toDouble() ?? 0.0,
      speedAdjustment: (map['speedAdjustment'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'speakerId': id,
      'speakerLabel': label,
      'assignedVoiceId': assignedVoiceId,
      'isClonedVoice': isCloned,
      'pitchAdjustment': pitchAdjustment,
      'speedAdjustment': speedAdjustment,
    };
  }
}

/// Complete standalone dubbing project.
class DubbingJob {
  final String id;
  final String userId;
  final String title;
  final DubbingMode mode;
  final DubbingJobStatus status;
  final int progressPercent;
  final String currentStepMessage;
  final String sourceMediaUrl;
  final String sourceMediaType;
  final int durationSeconds;
  final int characterCount;
  final String sourceLanguage;
  final List<String> targetLanguages;
  final bool voiceCloningEnabled;
  final bool twoStageReviewEnabled;
  final bool publishToTruthworld;
  final double costUsd;
  final int totalCharactersCharged;
  final List<DubbingSpeaker> speakers;
  final Map<String, List<DubbingSegment>> segmentsByLanguage;
  final Map<String, dynamic>? exportUrls;
  final String? videoId;
  final String? pipelineJobId;
  final String? channelId;
  final String? error;
  final DateTime createdAt;
  final Map<String, dynamic>? stages;

  DubbingJob({
    required this.id,
    required this.userId,
    required this.title,
    required this.mode,
    required this.status,
    required this.progressPercent,
    required this.currentStepMessage,
    required this.sourceMediaUrl,
    required this.sourceMediaType,
    required this.durationSeconds,
    required this.characterCount,
    required this.sourceLanguage,
    required this.targetLanguages,
    required this.voiceCloningEnabled,
    required this.twoStageReviewEnabled,
    required this.publishToTruthworld,
    required this.costUsd,
    required this.totalCharactersCharged,
    required this.speakers,
    required this.segmentsByLanguage,
    required this.createdAt,
    this.exportUrls,
    this.videoId,
    this.pipelineJobId,
    this.channelId,
    this.error,
    this.stages,
  });

  factory DubbingJob.fromMap(Map<String, dynamic> map) {
    final rawMode = map['mode']?.toString();
    final mode = rawMode == 'subtitles_only' ? DubbingMode.subtitlesOnly : DubbingMode.dubbing;
    final status = DubbingJobStatus.fromString(map['status']?.toString());

    final speakers = <DubbingSpeaker>[];
    if (map['speakers'] is List) {
      for (final s in map['speakers']) {
        if (s is Map<String, dynamic>) speakers.add(DubbingSpeaker.fromMap(s));
      }
    }

    final segments = <String, List<DubbingSegment>>{};
    if (map['segmentsByLanguage'] is Map) {
      final segMap = map['segmentsByLanguage'] as Map;
      segMap.forEach((key, val) {
        if (val is List) {
          segments['$key'] = val
              .whereType<Map<String, dynamic>>()
              .map(DubbingSegment.fromMap)
              .toList();
        }
      });
    }

    final rawCreated = map['createdAt'];
    final createdAt = rawCreated is num
        ? DateTime.fromMillisecondsSinceEpoch(rawCreated.toInt())
        : DateTime.now();

    return DubbingJob(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Project',
      mode: mode,
      status: status,
      progressPercent: (map['progressPercent'] as num?)?.toInt() ?? 0,
      currentStepMessage: map['currentStepMessage']?.toString() ?? '',
      sourceMediaUrl: map['sourceMediaUrl']?.toString() ?? '',
      sourceMediaType: map['sourceMediaType']?.toString() ?? 'video',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      characterCount: (map['characterCount'] as num?)?.toInt() ?? 0,
      sourceLanguage: map['sourceLanguage']?.toString() ?? 'en',
      targetLanguages: (map['targetLanguages'] as List?)?.map((e) => '$e').toList() ?? [],
      voiceCloningEnabled: map['voiceCloningEnabled'] == true,
      twoStageReviewEnabled: map['twoStageReviewEnabled'] == true,
      publishToTruthworld: map['publishToTruthworld'] == true,
      costUsd: (map['costUsd'] as num?)?.toDouble() ?? 0.0,
      totalCharactersCharged: (map['totalCharactersCharged'] as num?)?.toInt() ?? 0,
      speakers: speakers,
      segmentsByLanguage: segments,
      exportUrls: map['exportUrls'] is Map ? Map<String, dynamic>.from(map['exportUrls']) : null,
      videoId: map['videoId']?.toString(),
      pipelineJobId: map['pipelineJobId']?.toString(),
      channelId: map['channelId']?.toString(),
      error: map['error']?.toString(),
      createdAt: createdAt,
      stages: map['stages'] is Map ? Map<String, dynamic>.from(map['stages'] as Map) : null,
    );
  }

  /// Reads a per-language URL map from [exportUrls] safely.
  Map<String, String> exportUrlMap(String key) {
    final raw = exportUrls?[key];
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      final val = v?.toString().trim() ?? '';
      if (val.isNotEmpty) {
        out[k.toString()] = val;
      }
    });
    return out;
  }

  /// Reads a single URL string from [exportUrls] safely.
  String? exportUrlString(String key) {
    final val = exportUrls?[key]?.toString().trim() ?? '';
    return val.isNotEmpty ? val : null;
  }

  Map<String, String> get dubbedVideoByLanguage => exportUrlMap('dubbedVideoByLanguage');
  Map<String, String> get dubbedAudioByLanguage => exportUrlMap('dubbedAudioByLanguage');
  Map<String, String> get dialogueAudioByLanguage => exportUrlMap('dialogueAudioByLanguage');
  Map<String, String> get translationJsonByLanguage => exportUrlMap('translationJsonByLanguage');
  Map<String, String> get subtitlesSrt => exportUrlMap('subtitlesSrt');
  Map<String, String> get subtitlesVtt => exportUrlMap('subtitlesVtt');
  String? get vocalsStemMp3 => exportUrlString('vocalsStemMp3');
  String? get backgroundStemMp3 => exportUrlString('backgroundStemMp3');
  String? get reportJson => exportUrlString('reportJson');

  String? _lookupLangUrl(
    Map<String, String> map,
    String lang, {
    String? singleFallbackKey,
  }) {
    final trimmed = lang.trim();
    if (trimmed.isEmpty) return null;
    final norm = trimmed.toLowerCase();
    final direct = map[trimmed] ?? map[norm];
    if (direct != null && direct.isNotEmpty) return direct;
    for (final entry in map.entries) {
      if (entry.key.trim().toLowerCase() == norm && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    if (singleFallbackKey != null && targetLanguages.length <= 1) {
      return exportUrlString(singleFallbackKey);
    }
    return null;
  }

  String? dubbedVideoUrlFor(String lang) =>
      _lookupLangUrl(dubbedVideoByLanguage, lang, singleFallbackKey: 'dubbedVideoMp4');

  String? dubbedAudioUrlFor(String lang) =>
      _lookupLangUrl(dubbedAudioByLanguage, lang, singleFallbackKey: 'dubbedAudioMp3');

  String? dialogueAudioUrlFor(String lang) => _lookupLangUrl(dialogueAudioByLanguage, lang);

  String? translationJsonUrlFor(String lang) => _lookupLangUrl(translationJsonByLanguage, lang);

  String? subtitlesSrtUrlFor(String lang) => _lookupLangUrl(subtitlesSrt, lang);

  String? subtitlesVttUrlFor(String lang) => _lookupLangUrl(subtitlesVtt, lang);
}
