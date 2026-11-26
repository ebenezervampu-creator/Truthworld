import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';

/// Persistent TruthWorld Dubbing Studio project stored in `dubbing_projects/{id}`.
///
/// A project acts as the parent workspace for a creator's source media,
/// language configuration, audio settings, and accumulated dubbing & subtitle jobs.
class DubbingProject {
  final String id;
  final String userId;
  final String title;
  final String sourceInputMode; // 'channel_videos' | 'file_upload'
  final String? videoId;
  final String? channelId;
  final String sourceMediaUrl;
  final String sourceMediaType; // 'video' | 'audio'
  final String pickedFileName;
  final int durationSeconds;
  final int characterCount;
  final String sourceLanguage;
  final List<String> targetLanguages;
  final DubbingMode mode;
  final bool voiceCloningEnabled;
  final bool isolateVocals;
  final bool preserveBgm;
  final double bgmDuckingPercent;
  final bool twoStageReviewEnabled;
  final bool publishToTruthworld;
  final List<String> jobIds;
  final List<String> dubbedLanguages;
  final List<String> subtitledLanguages;
  final String? latestJobId;
  final String latestStatus; // 'draft' | 'processing' | 'completed' | 'failed'
  final int createdAt;
  final int updatedAt;

  const DubbingProject({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.sourceInputMode = 'channel_videos',
    this.videoId,
    this.channelId,
    this.sourceMediaUrl = '',
    this.sourceMediaType = 'video',
    this.pickedFileName = '',
    this.durationSeconds = 60,
    this.characterCount = 1000,
    this.sourceLanguage = 'en',
    this.targetLanguages = const [],
    this.mode = DubbingMode.dubbing,
    this.voiceCloningEnabled = false,
    this.isolateVocals = true,
    this.preserveBgm = true,
    this.bgmDuckingPercent = 25.0,
    this.twoStageReviewEnabled = true,
    this.publishToTruthworld = false,
    this.jobIds = const [],
    this.dubbedLanguages = const [],
    this.subtitledLanguages = const [],
    this.latestJobId,
    this.latestStatus = 'draft',
  });

  factory DubbingProject.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawMode = map['mode']?.toString();
    final mode = rawMode == 'subtitles_only' ? DubbingMode.subtitlesOnly : DubbingMode.dubbing;

    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return DubbingProject(
      id: (map['id']?.toString().trim().isNotEmpty == true)
          ? map['id'].toString().trim()
          : (docId ?? ''),
      userId: map['userId']?.toString() ?? '',
      title: (map['title']?.toString().trim().isNotEmpty == true)
          ? map['title'].toString().trim()
          : 'Untitled Project',
      sourceInputMode: map['sourceInputMode']?.toString() == 'file_upload'
          ? 'file_upload'
          : 'channel_videos',
      videoId: map['videoId']?.toString().trim().isNotEmpty == true
          ? map['videoId'].toString().trim()
          : null,
      channelId: map['channelId']?.toString().trim().isNotEmpty == true
          ? map['channelId'].toString().trim()
          : null,
      sourceMediaUrl: map['sourceMediaUrl']?.toString() ?? '',
      sourceMediaType: map['sourceMediaType']?.toString() == 'audio' ? 'audio' : 'video',
      pickedFileName: map['pickedFileName']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 60,
      characterCount: (map['characterCount'] as num?)?.toInt() ?? 1000,
      sourceLanguage: (map['sourceLanguage']?.toString().trim().isNotEmpty == true)
          ? map['sourceLanguage'].toString().trim()
          : 'en',
      targetLanguages: parseStringList(map['targetLanguages']),
      mode: mode,
      voiceCloningEnabled: map['voiceCloningEnabled'] == true,
      isolateVocals: map['isolateVocals'] != false,
      preserveBgm: map['preserveBgm'] != false,
      bgmDuckingPercent: (map['bgmDuckingPercent'] as num?)?.toDouble() ?? 25.0,
      twoStageReviewEnabled: map['twoStageReviewEnabled'] != false,
      publishToTruthworld: map['publishToTruthworld'] == true,
      jobIds: parseStringList(map['jobIds']),
      dubbedLanguages: parseStringList(map['dubbedLanguages']),
      subtitledLanguages: parseStringList(map['subtitledLanguages']),
      latestJobId: map['latestJobId']?.toString().trim().isNotEmpty == true
          ? map['latestJobId'].toString().trim()
          : null,
      latestStatus: (map['latestStatus']?.toString().trim().isNotEmpty == true)
          ? map['latestStatus'].toString().trim()
          : 'draft',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? nowMs,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? nowMs,
    );
  }

  /// Creates a lightweight project wrapper around an existing `studio_dubbing_jobs` entry
  /// created before `dubbing_projects` existed.
  factory DubbingProject.fromLegacyJob(DubbingJob job) {
    final isSubOnly = job.mode == DubbingMode.subtitlesOnly;
    final createdMs = job.createdAt.millisecondsSinceEpoch;
    return DubbingProject(
      id: 'legacy_${job.id}',
      userId: job.userId,
      title: job.title,
      sourceInputMode: (job.videoId != null && job.videoId!.isNotEmpty)
          ? 'channel_videos'
          : 'file_upload',
      videoId: job.videoId,
      channelId: job.channelId,
      sourceMediaUrl: job.sourceMediaUrl,
      sourceMediaType: job.sourceMediaType,
      durationSeconds: job.durationSeconds > 0 ? job.durationSeconds : 60,
      characterCount: job.characterCount > 0 ? job.characterCount : 1000,
      sourceLanguage: job.sourceLanguage,
      targetLanguages: List<String>.from(job.targetLanguages),
      mode: job.mode,
      voiceCloningEnabled: job.voiceCloningEnabled,
      twoStageReviewEnabled: job.twoStageReviewEnabled,
      publishToTruthworld: job.publishToTruthworld,
      jobIds: [job.id],
      dubbedLanguages: isSubOnly ? const [] : List<String>.from(job.targetLanguages),
      subtitledLanguages: List<String>.from(job.targetLanguages),
      latestJobId: job.id,
      latestStatus: job.status == DubbingJobStatus.completed
          ? 'completed'
          : (job.status == DubbingJobStatus.failed ? 'failed' : 'processing'),
      createdAt: createdMs,
      updatedAt: createdMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'sourceInputMode': sourceInputMode,
      if (videoId != null) 'videoId': videoId,
      if (channelId != null) 'channelId': channelId,
      'sourceMediaUrl': sourceMediaUrl,
      'sourceMediaType': sourceMediaType,
      'pickedFileName': pickedFileName,
      'durationSeconds': durationSeconds,
      'characterCount': characterCount,
      'sourceLanguage': sourceLanguage,
      'targetLanguages': targetLanguages,
      'mode': mode == DubbingMode.subtitlesOnly ? 'subtitles_only' : 'dubbing',
      'voiceCloningEnabled': voiceCloningEnabled,
      'isolateVocals': isolateVocals,
      'preserveBgm': preserveBgm,
      'bgmDuckingPercent': bgmDuckingPercent,
      'twoStageReviewEnabled': twoStageReviewEnabled,
      'publishToTruthworld': publishToTruthworld,
      'jobIds': jobIds,
      'dubbedLanguages': dubbedLanguages,
      'subtitledLanguages': subtitledLanguages,
      if (latestJobId != null) 'latestJobId': latestJobId,
      'latestStatus': latestStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  DubbingProject copyWith({
    String? id,
    String? userId,
    String? title,
    String? sourceInputMode,
    String? videoId,
    bool clearVideoId = false,
    String? channelId,
    String? sourceMediaUrl,
    String? sourceMediaType,
    String? pickedFileName,
    int? durationSeconds,
    int? characterCount,
    String? sourceLanguage,
    List<String>? targetLanguages,
    DubbingMode? mode,
    bool? voiceCloningEnabled,
    bool? isolateVocals,
    bool? preserveBgm,
    double? bgmDuckingPercent,
    bool? twoStageReviewEnabled,
    bool? publishToTruthworld,
    List<String>? jobIds,
    List<String>? dubbedLanguages,
    List<String>? subtitledLanguages,
    String? latestJobId,
    String? latestStatus,
    int? createdAt,
    int? updatedAt,
  }) {
    return DubbingProject(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      sourceInputMode: sourceInputMode ?? this.sourceInputMode,
      videoId: clearVideoId ? null : (videoId ?? this.videoId),
      channelId: channelId ?? this.channelId,
      sourceMediaUrl: sourceMediaUrl ?? this.sourceMediaUrl,
      sourceMediaType: sourceMediaType ?? this.sourceMediaType,
      pickedFileName: pickedFileName ?? this.pickedFileName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      characterCount: characterCount ?? this.characterCount,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      mode: mode ?? this.mode,
      voiceCloningEnabled: voiceCloningEnabled ?? this.voiceCloningEnabled,
      isolateVocals: isolateVocals ?? this.isolateVocals,
      preserveBgm: preserveBgm ?? this.preserveBgm,
      bgmDuckingPercent: bgmDuckingPercent ?? this.bgmDuckingPercent,
      twoStageReviewEnabled: twoStageReviewEnabled ?? this.twoStageReviewEnabled,
      publishToTruthworld: publishToTruthworld ?? this.publishToTruthworld,
      jobIds: jobIds ?? this.jobIds,
      dubbedLanguages: dubbedLanguages ?? this.dubbedLanguages,
      subtitledLanguages: subtitledLanguages ?? this.subtitledLanguages,
      latestJobId: latestJobId ?? this.latestJobId,
      latestStatus: latestStatus ?? this.latestStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
