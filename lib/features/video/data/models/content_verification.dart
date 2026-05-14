/// Content Verification Models
/// Handles verification of video content for quality, safety, and authenticity
library;

enum VerificationLevel {
  basic('basic'),
  standard('standard'),
  premium('premium');

  final String value;
  const VerificationLevel(this.value);
}

enum VerificationStatus {
  pending('pending'),
  inProgress('in_progress'),
  approved('approved'),
  rejected('rejected'),
  needsReview('needs_review');

  final String value;
  const VerificationStatus(this.value);

  factory VerificationStatus.fromString(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => VerificationStatus.pending,
    );
  }
}

class ContentVerification {
  /// Verification ID
  final String id;

  /// Video ID being verified
  final String videoId;

  /// User ID
  final String userId;

  /// Verification level
  final VerificationLevel level;

  /// Current status
  final VerificationStatus status;

  /// Audio quality score (0-100)
  final int? audioQualityScore;

  /// Video quality score (0-100)
  final int? videoQualityScore;

  /// Content safety score (0-100, higher = safer)
  final int? safetyScore;

  /// Profanity detection results
  final ProfanityCheckResult? profanityCheck;

  /// Violence/harmful content detection
  final ContentSafetyCheckResult? contentSafetyCheck;

  /// Duplicate/plagiarism check
  final PlagiarismCheckResult? plagiarismCheck;

  /// Copyright detection
  final CopyrightCheckResult? copyrightCheck;

  /// Transcript quality check
  final TranscriptQualityCheckResult? transcriptCheck;

  /// Dubbing quality check (if Path 2 enabled)
  final DubbingQualityCheckResult? dubbingCheck;

  /// Face quality check
  final FaceQualityCheckResult? faceCheck;

  /// Overall verification result
  final bool? isVerified;

  /// Rejection reason if rejected
  final String? rejectionReason;

  /// Reviewer notes
  final String? reviewerNotes;

  /// Checklist items
  final Map<String, VerificationChecklistItem> checklist;

  /// Created timestamp
  final DateTime createdAt;

  /// Updated timestamp
  final DateTime updatedAt;

  /// Completed timestamp
  final DateTime? completedAt;

  ContentVerification({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.level,
    required this.status,
    this.audioQualityScore,
    this.videoQualityScore,
    this.safetyScore,
    this.profanityCheck,
    this.contentSafetyCheck,
    this.plagiarismCheck,
    this.copyrightCheck,
    this.transcriptCheck,
    this.dubbingCheck,
    this.faceCheck,
    this.isVerified,
    this.rejectionReason,
    this.reviewerNotes,
    this.checklist = const {},
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  /// Get overall verification score (0-100)
  int getOverallScore() {
    final scores = [
      audioQualityScore,
      videoQualityScore,
      safetyScore,
    ].whereType<int>();

    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) ~/ scores.length);
  }

  /// Is verification complete?
  bool get isComplete =>
      status == VerificationStatus.approved ||
      status == VerificationStatus.rejected;

  /// Get pending checks
  List<String> getPendingChecks() {
    return checklist.entries
        .where((e) => !e.value.isComplete)
        .map((e) => e.key)
        .toList();
  }

  /// Get failed checks
  List<String> getFailedChecks() {
    return checklist.entries
        .where((e) => e.value.hasFailed)
        .map((e) => e.key)
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'level': level.value,
      'status': status.value,
      'audioQualityScore': audioQualityScore,
      'videoQualityScore': videoQualityScore,
      'safetyScore': safetyScore,
      'profanityCheck': profanityCheck?.toMap(),
      'contentSafetyCheck': contentSafetyCheck?.toMap(),
      'plagiarismCheck': plagiarismCheck?.toMap(),
      'copyrightCheck': copyrightCheck?.toMap(),
      'transcriptCheck': transcriptCheck?.toMap(),
      'dubbingCheck': dubbingCheck?.toMap(),
      'faceCheck': faceCheck?.toMap(),
      'isVerified': isVerified,
      'rejectionReason': rejectionReason,
      'reviewerNotes': reviewerNotes,
      'checklist': checklist.map((k, v) => MapEntry(k, v.toMap())),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory ContentVerification.fromMap(Map<String, dynamic> map) {
    return ContentVerification(
      id: map['id'] ?? '',
      videoId: map['videoId'] ?? '',
      userId: map['userId'] ?? '',
      level: VerificationLevel.values.firstWhere(
        (e) => e.value == map['level'],
        orElse: () => VerificationLevel.basic,
      ),
      status: VerificationStatus.fromString(map['status'] ?? 'pending'),
      audioQualityScore: map['audioQualityScore'],
      videoQualityScore: map['videoQualityScore'],
      safetyScore: map['safetyScore'],
      profanityCheck: map['profanityCheck'] != null
          ? ProfanityCheckResult.fromMap(map['profanityCheck'])
          : null,
      contentSafetyCheck: map['contentSafetyCheck'] != null
          ? ContentSafetyCheckResult.fromMap(map['contentSafetyCheck'])
          : null,
      plagiarismCheck: map['plagiarismCheck'] != null
          ? PlagiarismCheckResult.fromMap(map['plagiarismCheck'])
          : null,
      copyrightCheck: map['copyrightCheck'] != null
          ? CopyrightCheckResult.fromMap(map['copyrightCheck'])
          : null,
      transcriptCheck: map['transcriptCheck'] != null
          ? TranscriptQualityCheckResult.fromMap(map['transcriptCheck'])
          : null,
      dubbingCheck: map['dubbingCheck'] != null
          ? DubbingQualityCheckResult.fromMap(map['dubbingCheck'])
          : null,
      faceCheck: map['faceCheck'] != null
          ? FaceQualityCheckResult.fromMap(map['faceCheck'])
          : null,
      isVerified: map['isVerified'],
      rejectionReason: map['rejectionReason'],
      reviewerNotes: map['reviewerNotes'],
      checklist:
          (map['checklist'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, VerificationChecklistItem.fromMap(v)),
          ) ??
          {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }
}

// Verification check result types

class ProfanityCheckResult {
  final bool hasProfanity;
  final double severity; // 0.0 to 1.0
  final List<String> detectedWords;
  final int wordCount;

  ProfanityCheckResult({
    required this.hasProfanity,
    required this.severity,
    required this.detectedWords,
    this.wordCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'hasProfanity': hasProfanity,
      'severity': severity,
      'detectedWords': detectedWords,
      'wordCount': wordCount,
    };
  }

  factory ProfanityCheckResult.fromMap(Map<String, dynamic> map) {
    return ProfanityCheckResult(
      hasProfanity: map['hasProfanity'] ?? false,
      severity: (map['severity'] ?? 0.0).toDouble(),
      detectedWords: List<String>.from(map['detectedWords'] ?? []),
      wordCount: map['wordCount'] ?? 0,
    );
  }
}

class ContentSafetyCheckResult {
  final double safetyScore; // 0.0 to 1.0, higher = safer
  final List<String> flaggedCategories;
  final Map<String, double> categoryScores;

  ContentSafetyCheckResult({
    required this.safetyScore,
    required this.flaggedCategories,
    required this.categoryScores,
  });

  Map<String, dynamic> toMap() {
    return {
      'safetyScore': safetyScore,
      'flaggedCategories': flaggedCategories,
      'categoryScores': categoryScores,
    };
  }

  factory ContentSafetyCheckResult.fromMap(Map<String, dynamic> map) {
    return ContentSafetyCheckResult(
      safetyScore: (map['safetyScore'] ?? 0.5).toDouble(),
      flaggedCategories: List<String>.from(map['flaggedCategories'] ?? []),
      categoryScores: Map<String, double>.from(
        map['categoryScores']?.cast<String, double>() ?? {},
      ),
    );
  }
}

class PlagiarismCheckResult {
  final double similarityScore; // 0.0 to 1.0
  final int matchingSegments;
  final List<String> sourcesFound;

  PlagiarismCheckResult({
    required this.similarityScore,
    required this.matchingSegments,
    required this.sourcesFound,
  });

  Map<String, dynamic> toMap() {
    return {
      'similarityScore': similarityScore,
      'matchingSegments': matchingSegments,
      'sourcesFound': sourcesFound,
    };
  }

  factory PlagiarismCheckResult.fromMap(Map<String, dynamic> map) {
    return PlagiarismCheckResult(
      similarityScore: (map['similarityScore'] ?? 0.0).toDouble(),
      matchingSegments: map['matchingSegments'] ?? 0,
      sourcesFound: List<String>.from(map['sourcesFound'] ?? []),
    );
  }
}

class CopyrightCheckResult {
  final bool hasNoViolations;
  final List<String> flaggedSegments;
  final List<String> sources;

  CopyrightCheckResult({
    required this.hasNoViolations,
    required this.flaggedSegments,
    required this.sources,
  });

  Map<String, dynamic> toMap() {
    return {
      'hasNoViolations': hasNoViolations,
      'flaggedSegments': flaggedSegments,
      'sources': sources,
    };
  }

  factory CopyrightCheckResult.fromMap(Map<String, dynamic> map) {
    return CopyrightCheckResult(
      hasNoViolations: map['hasNoViolations'] ?? true,
      flaggedSegments: List<String>.from(map['flaggedSegments'] ?? []),
      sources: List<String>.from(map['sources'] ?? []),
    );
  }
}

class TranscriptQualityCheckResult {
  final double accuracy; // 0.0 to 1.0
  final int wordCount;
  final List<String> issues;

  TranscriptQualityCheckResult({
    required this.accuracy,
    required this.wordCount,
    required this.issues,
  });

  Map<String, dynamic> toMap() {
    return {'accuracy': accuracy, 'wordCount': wordCount, 'issues': issues};
  }

  factory TranscriptQualityCheckResult.fromMap(Map<String, dynamic> map) {
    return TranscriptQualityCheckResult(
      accuracy: (map['accuracy'] ?? 0.95).toDouble(),
      wordCount: map['wordCount'] ?? 0,
      issues: List<String>.from(map['issues'] ?? []),
    );
  }
}

class DubbingQualityCheckResult {
  final Map<String, double> languageScores; // language -> quality score
  final List<String> languagesWithIssues;
  final double averageQuality;

  DubbingQualityCheckResult({
    required this.languageScores,
    required this.languagesWithIssues,
    required this.averageQuality,
  });

  Map<String, dynamic> toMap() {
    return {
      'languageScores': languageScores,
      'languagesWithIssues': languagesWithIssues,
      'averageQuality': averageQuality,
    };
  }

  factory DubbingQualityCheckResult.fromMap(Map<String, dynamic> map) {
    return DubbingQualityCheckResult(
      languageScores: Map<String, double>.from(
        map['languageScores']?.cast<String, double>() ?? {},
      ),
      languagesWithIssues: List<String>.from(map['languagesWithIssues'] ?? []),
      averageQuality: (map['averageQuality'] ?? 0.85).toDouble(),
    );
  }
}

class FaceQualityCheckResult {
  final int detectedFaces;
  final double clarity; // 0.0 to 1.0
  final List<String> issues;

  FaceQualityCheckResult({
    required this.detectedFaces,
    required this.clarity,
    required this.issues,
  });

  Map<String, dynamic> toMap() {
    return {
      'detectedFaces': detectedFaces,
      'clarity': clarity,
      'issues': issues,
    };
  }

  factory FaceQualityCheckResult.fromMap(Map<String, dynamic> map) {
    return FaceQualityCheckResult(
      detectedFaces: map['detectedFaces'] ?? 0,
      clarity: (map['clarity'] ?? 0.8).toDouble(),
      issues: List<String>.from(map['issues'] ?? []),
    );
  }
}

class VerificationChecklistItem {
  final String name;
  final String description;
  final bool isComplete;
  final bool hasFailed;
  final String? result;

  VerificationChecklistItem({
    required this.name,
    required this.description,
    this.isComplete = false,
    this.hasFailed = false,
    this.result,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'isComplete': isComplete,
      'hasFailed': hasFailed,
      'result': result,
    };
  }

  factory VerificationChecklistItem.fromMap(Map<String, dynamic> map) {
    return VerificationChecklistItem(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isComplete: map['isComplete'] ?? false,
      hasFailed: map['hasFailed'] ?? false,
      result: map['result'],
    );
  }
}





