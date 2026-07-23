/// Pipeline Job Status Model
/// Tracks the progress of video processing through all pipeline stages
library;

enum PipelineStage {
  pending('pending'),
  ingestion('ingestion'),
  transcription('transcription'),
  credibility('credibility'),
  dubbing('dubbing'),
  aggregation('aggregation'),
  completed('completed'),
  failed('failed');

  final String value;
  const PipelineStage(this.value);

  factory PipelineStage.fromString(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => PipelineStage.pending,
    );
  }
}

enum StageStatus {
  pending('pending'),
  running('running'),
  completed('completed'),
  skipped('skipped'),
  failed('failed');

  final String value;
  const StageStatus(this.value);

  factory StageStatus.fromString(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => StageStatus.pending,
    );
  }
}

class PipelineJobStatus {

  PipelineJobStatus({
    required this.jobId,
    required this.userId,
    required this.currentStage,
    required this.overallProgress,
    required this.startedAt, this.stageProgress = const {},
    this.stageStatuses = const {},
    this.eta,
    this.errorMessage,
    this.completedAt,
    this.estimatedCompletionAt,
    this.pipelineConfig = const {},
    this.path1Results,
    this.path2Results,
    this.finalOutput,
    this.warnings = const [],
  });

  /// Create from Map (from API/Firestore)
  factory PipelineJobStatus.fromMap(Map<String, dynamic> map) {
    return PipelineJobStatus(
      jobId: map['jobId'] ?? '',
      userId: map['userId'] ?? '',
      currentStage: PipelineStage.fromString(map['currentStage'] ?? 'pending'),
      overallProgress: (map['overallProgress'] ?? 0.0).toDouble(),
      stageProgress: Map<String, double>.from(
        map['stageProgress']?.cast<String, double>() ?? {},
      ),
      stageStatuses:
          (map['stageStatuses'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, StageStatus.fromString(v)))
              .cast<String, StageStatus>() ??
          {},
      eta: map['eta'],
      errorMessage: map['errorMessage'],
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['startedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      estimatedCompletionAt: map['estimatedCompletionAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['estimatedCompletionAt'])
          : null,
      pipelineConfig: map['pipelineConfig'] ?? {},
      path1Results: map['path1Results'],
      path2Results: map['path2Results'],
      finalOutput: map['finalOutput'],
      warnings: List<String>.from(map['warnings'] ?? []),
    );
  }
  /// Unique job identifier
  final String jobId;

  /// User who submitted the job
  final String userId;

  /// Current stage
  final PipelineStage currentStage;

  /// Overall progress (0.0 to 1.0 where 1.0 = 100%)
  final double overallProgress;

  /// Progress breakdown by stage
  final Map<String, double> stageProgress;

  /// Status of each stage
  final Map<String, StageStatus> stageStatuses;

  /// ETA in seconds
  final int? eta;

  /// Error message if stage failed
  final String? errorMessage;

  /// Start time
  final DateTime startedAt;

  /// Completion time
  final DateTime? completedAt;

  /// Estimated completion time
  final DateTime? estimatedCompletionAt;

  /// Pipeline configuration used
  final Map<String, dynamic> pipelineConfig;

  /// Path 1 (Credibility) results
  final Map<String, dynamic>? path1Results;

  /// Path 2 (Dubbing) results
  final Map<String, dynamic>? path2Results;

  /// Final aggregated output
  final Map<String, dynamic>? finalOutput;

  /// Warnings/info messages
  final List<String> warnings;

  /// Get human-readable current stage name
  String get currentStageName => _stageName(currentStage);

  /// Get overall progress as percentage
  int get progressPercent => (overallProgress * 100).toInt();

  /// Is job still processing?
  bool get isProcessing =>
      currentStage != PipelineStage.completed &&
      currentStage != PipelineStage.failed;

  /// Is job completed successfully?
  bool get isCompleted => currentStage == PipelineStage.completed;

  /// Is job failed?
  bool get isFailed => currentStage == PipelineStage.failed;

  /// Get stage progress as percentage
  int getStageProgressPercent(String stageName) {
    final progress = stageProgress[stageName] ?? 0.0;
    return (progress * 100).toInt();
  }

  /// Get status of specific stage
  StageStatus getStageStatus(String stageName) {
    return stageStatuses[stageName] ?? StageStatus.pending;
  }

  /// Get duration so far
  Duration getDuration() {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  /// Convert to Map for API/Firestore
  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'userId': userId,
      'currentStage': currentStage.value,
      'overallProgress': overallProgress,
      'stageProgress': stageProgress,
      'stageStatuses': stageStatuses.map((k, v) => MapEntry(k, v.value)),
      'eta': eta,
      'errorMessage': errorMessage,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'estimatedCompletionAt': estimatedCompletionAt?.millisecondsSinceEpoch,
      'pipelineConfig': pipelineConfig,
      'path1Results': path1Results,
      'path2Results': path2Results,
      'finalOutput': finalOutput,
      'warnings': warnings,
    };
  }

  String _stageName(PipelineStage stage) {
    switch (stage) {
      case PipelineStage.pending:
        return 'Pending';
      case PipelineStage.ingestion:
        return 'Ingestion';
      case PipelineStage.transcription:
        return 'Transcription';
      case PipelineStage.credibility:
        return 'Credibility Check';
      case PipelineStage.dubbing:
        return 'Dubbing';
      case PipelineStage.aggregation:
        return 'Aggregation';
      case PipelineStage.completed:
        return 'Completed';
      case PipelineStage.failed:
        return 'Failed';
    }
  }
}

/// Real-time status update from Pub/Sub
class PipelineStatusUpdate {

  PipelineStatusUpdate({
    required this.jobId,
    required this.userId,
    required this.stage,
    required this.progress,
    required this.status,
    required this.timestamp, this.message,
    this.eta,
  });

  factory PipelineStatusUpdate.fromMap(Map<String, dynamic> map) {
    return PipelineStatusUpdate(
      jobId: map['jobId'] ?? '',
      userId: map['userId'] ?? '',
      stage: PipelineStage.fromString(map['stage'] ?? 'pending'),
      progress: (map['progress'] ?? 0.0).toDouble(),
      status: StageStatus.fromString(map['status'] ?? 'pending'),
      message: map['message'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      eta: map['eta'],
    );
  }
  final String jobId;
  final String userId;
  final PipelineStage stage;
  final double progress;
  final StageStatus status;
  final String? message;
  final DateTime timestamp;
  final int? eta;
}





