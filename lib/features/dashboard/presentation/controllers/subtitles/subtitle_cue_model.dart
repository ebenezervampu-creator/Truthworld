/// Status of a subtitle language track
enum SubtitleTrackStatus {
  published,
  draft,
  notAdded,
  generating,
  failed;

  String get label {
    switch (this) {
      case SubtitleTrackStatus.published:
        return 'Published';
      case SubtitleTrackStatus.draft:
        return 'Draft';
      case SubtitleTrackStatus.notAdded:
        return 'Not added';
      case SubtitleTrackStatus.generating:
        return 'Generating...';
      case SubtitleTrackStatus.failed:
        return 'Failed';
    }
  }
}

/// Granular per-track progress state for AI subtitles generation pipeline
class SubtitleTrackProgressState {
  final String langCode;
  final int progress;
  final int stageStep;
  final String totalStepsText;
  final String stageTitle;
  final String etaText;
  final DateTime? startedAt;
  final bool isGenerating;
  final bool isFailed;
  final String? errorMessage;

  const SubtitleTrackProgressState({
    required this.langCode,
    this.progress = 15,
    this.stageStep = 1,
    this.totalStepsText = 'Step 1 of 3',
    this.stageTitle = 'Transcribing dialogue',
    this.etaText = '~30 sec',
    this.startedAt,
    this.isGenerating = true,
    this.isFailed = false,
    this.errorMessage,
  });

  SubtitleTrackProgressState copyWith({
    String? langCode,
    int? progress,
    int? stageStep,
    String? totalStepsText,
    String? stageTitle,
    String? etaText,
    DateTime? startedAt,
    bool? isGenerating,
    bool? isFailed,
    String? errorMessage,
  }) {
    return SubtitleTrackProgressState(
      langCode: langCode ?? this.langCode,
      progress: progress ?? this.progress,
      stageStep: stageStep ?? this.stageStep,
      totalStepsText: totalStepsText ?? this.totalStepsText,
      stageTitle: stageTitle ?? this.stageTitle,
      etaText: etaText ?? this.etaText,
      startedAt: startedAt ?? this.startedAt,
      isGenerating: isGenerating ?? this.isGenerating,
      isFailed: isFailed ?? this.isFailed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Internal Cue Representation for visual preview and editing
class SubtitleCue {
  SubtitleCue({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  String id;
  String startTime;
  String endTime;
  String text;

  SubtitleCue copyWith({
    String? id,
    String? startTime,
    String? endTime,
    String? text,
  }) {
    return SubtitleCue(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      text: text ?? this.text,
    );
  }

  @override
  String toString() => 'SubtitleCue(id: $id, $startTime --> $endTime, text: $text)';
}
