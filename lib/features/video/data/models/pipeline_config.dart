/// Pipeline Configuration Model
/// Defines all the requirements for video processing pipeline
/// including dubbing languages, subtitle options, and verification settings
library;

class PipelineConfig {

  PipelineConfig({
    // Metadata
    required this.userId, required this.channelId, required this.videoTitle, required this.videoDescription, required this.videoDuration, required this.videoCategory, // Dubbing
    this.enablePath1 = true,
    this.enablePath2 = false,
    this.dubbingLanguages = const [],
    this.enableSubtitles = true,
    this.subtitleLanguages = const ['en'],
    this.voiceType = 'natural',
    this.ttsSpeed = 1.0,

    // Transcription
    this.enableTranscription = true,
    this.enableDiarization = false,
    this.enableChapters = false,
    this.autoDetectLanguage = true,
    this.transcriptionLanguage = 'en',

    // Credibility
    this.enableFactCheck = false,
    this.factCheckScoringMethod = 'balanced',
    this.factCheckConfidenceThreshold = 0.7,
    this.enableExplainability = false,

    // Auxiliary
    this.enableOCR = false,
    this.enableVisualContext = false,
    this.enableAudioEnhancement = false,

    // Cost & Tier
    this.tier = 'free',
    this.estimatedCost = 0.0,
    this.monthlyBudgetLimit,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from Map (for loading from Firestore)
  factory PipelineConfig.fromMap(Map<String, dynamic> map) {
    return PipelineConfig(
      enablePath1: map['executionPlan']?['enablePath1'] ?? true,
      enablePath2: map['executionPlan']?['enablePath2'] ?? false,
      dubbingLanguages: List<String>.from(
        map['executionPlan']?['languages']?['dubbing'] ?? [],
      ),
      enableSubtitles: map['executionPlan']?['languages']?['subtitles'] != null,
      subtitleLanguages: List<String>.from(
        map['executionPlan']?['languages']?['subtitles'] ?? ['en'],
      ),
      voiceType: map['executionPlan']?['voiceType'] ?? 'natural',
      ttsSpeed: (map['executionPlan']?['ttsSpeed'] ?? 1.0).toDouble(),
      transcriptionLanguage:
          map['executionPlan']?['languages']?['transcription'] ?? 'en',
      enableFactCheck: map['executionPlan']?['factCheck']?['enabled'] ?? false,
      factCheckScoringMethod:
          map['executionPlan']?['factCheck']?['scoringMethod'] ?? 'balanced',
      factCheckConfidenceThreshold:
          (map['executionPlan']?['factCheck']?['confidenceThreshold'] ?? 0.7)
              .toDouble(),
      enableExplainability:
          map['executionPlan']?['factCheck']?['explainability'] ?? false,
      enableOCR: map['executionPlan']?['auxiliary']?['ocr'] ?? false,
      enableVisualContext:
          map['executionPlan']?['auxiliary']?['visualContext'] ?? false,
      enableAudioEnhancement:
          map['executionPlan']?['auxiliary']?['audioEnhancement'] ?? false,
      enableChapters: map['executionPlan']?['auxiliary']?['chapters'] ?? false,
      tier: map['config']?['tier'] ?? 'free',
      estimatedCost: (map['config']?['estimatedCost'] ?? 0.0).toDouble(),
      monthlyBudgetLimit: map['config']?['monthlyBudgetLimit'],
      userId: map['userId'] ?? '',
      channelId: map['channelId'] ?? '',
      videoTitle: map['metadata']?['videoTitle'] ?? '',
      videoDescription: map['metadata']?['videoDescription'] ?? '',
      videoDuration: map['metadata']?['videoDuration'] ?? '0',
      videoCategory: map['metadata']?['videoCategory'] ?? 'General',
    );
  }
  // ═══════════════════════════════════════════════════════════════
  // DUBBING CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /// Enable Path 1: Credibility & Fact-Checking
  final bool enablePath1;

  /// Enable Path 2: Dubbing & Translation
  final bool enablePath2;

  /// Target languages for dubbing (ISO 639-1 codes)
  /// Examples: ['es', 'fr', 'de', 'pt', 'hi', 'ja', 'zh', 'ar', 'ru']
  final List<String> dubbingLanguages;

  /// Enable subtitles for each language
  final bool enableSubtitles;

  /// Subtitle language codes (ISO 639-1)
  final List<String> subtitleLanguages;

  /// Voice type for dubbing: 'natural' | 'standard' | 'premium'
  final String voiceType;

  /// TTS speed multiplier: 0.8 to 1.2x
  final double ttsSpeed;

  // ═══════════════════════════════════════════════════════════════
  // TRANSCRIPTION CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /// Enable automatic transcription
  final bool enableTranscription;

  /// Enable speaker diarization
  final bool enableDiarization;

  /// Enable auto chapters (AssemblyAI)
  final bool enableChapters;

  /// Detect language automatically (overrides transcriptionLanguage)
  final bool autoDetectLanguage;

  /// Transcription language (used if autoDetectLanguage is false)
  final String transcriptionLanguage;

  // ═══════════════════════════════════════════════════════════════
  // CREDIBILITY & FACT-CHECKING CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /// Enable fact-checking and claim extraction
  final bool enableFactCheck;

  /// Scoring method: 'strict' | 'balanced' | 'lenient'
  final String factCheckScoringMethod;

  /// Minimum confidence threshold (0.0 to 1.0)
  final double factCheckConfidenceThreshold;

  /// Enable explainability (detailed claim analysis)
  final bool enableExplainability;

  // ═══════════════════════════════════════════════════════════════
  // AUXILIARY FEATURES CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /// Enable OCR (Optical Character Recognition)
  final bool enableOCR;

  /// Enable visual context extraction
  final bool enableVisualContext;

  /// Enable audio quality enhancement
  final bool enableAudioEnhancement;

  // ═══════════════════════════════════════════════════════════════
  // COST & TIER INFORMATION
  // ═══════════════════════════════════════════════════════════════

  /// Tier: 'free' | 'pro' | 'enterprise'
  final String tier;

  /// Estimated cost in USD
  final double estimatedCost;

  /// Monthly budget limit (null = unlimited)
  final double? monthlyBudgetLimit;

  // ═══════════════════════════════════════════════════════════════
  // METADATA
  // ═══════════════════════════════════════════════════════════════

  /// User ID (from Firebase Auth)
  final String userId;

  /// Channel ID
  final String channelId;

  /// Video metadata
  final String videoTitle;
  final String videoDescription;
  final String videoDuration; // in seconds or format like "10:30"
  final String videoCategory;

  /// Created timestamp
  final DateTime createdAt;

  /// Convert to Map for API request
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'channelId': channelId,
      'executionPlan': {
        'enablePath1': enablePath1,
        'enablePath2': enablePath2,
        'languages': {
          'dubbing': dubbingLanguages,
          'subtitles': subtitleLanguages,
          'transcription': transcriptionLanguage,
        },
        'voiceType': voiceType,
        'ttsSpeed': ttsSpeed,
        'factCheck': {
          'enabled': enableFactCheck,
          'scoringMethod': factCheckScoringMethod,
          'confidenceThreshold': factCheckConfidenceThreshold,
          'explainability': enableExplainability,
        },
        'auxiliary': {
          'ocr': enableOCR,
          'visualContext': enableVisualContext,
          'audioEnhancement': enableAudioEnhancement,
          'chapters': enableChapters,
        },
      },
      'config': {
        'tier': tier,
        'estimatedCost': estimatedCost,
        'monthlyBudgetLimit': monthlyBudgetLimit,
      },
      'metadata': {
        'videoTitle': videoTitle,
        'videoDescription': videoDescription,
        'videoDuration': videoDuration,
        'videoCategory': videoCategory,
        'createdAt': createdAt.millisecondsSinceEpoch,
      },
    };
  }

  /// Calculate estimated cost based on configuration
  static double calculateCost({
    required String tier,
    required bool enablePath1,
    required bool enablePath2,
    required int dubbingLanguageCount,
    required bool enableFactCheck,
    required bool enableSubtitles,
    required String videoDuration,
  }) {
    var cost = 0.0;

    // Base cost per tier
    switch (tier) {
      case 'pro':
        cost += 5.0;
      case 'enterprise':
        cost += 25.0;
      default:
        cost = 0.0; // Free tier
    }

    if (tier != 'free') {
      // Transcription: $0.01 per minute
      try {
        final minutes = int.parse(videoDuration) / 60;
        cost += minutes * 0.01;
      } catch (_) {
        cost += 0.5; // Default for unparseable duration
      }

      // Path 1 (Fact-checking): $2.00 per video
      if (enablePath1 && enableFactCheck) {
        cost += 2.0;
      }

      // Path 2 (Dubbing): $0.50 per language
      if (enablePath2) {
        cost += dubbingLanguageCount * 0.50;
      }

      // Subtitles: $0.10 per language
      if (enableSubtitles) {
        cost += dubbingLanguageCount * 0.10;
      }
    }

    return double.parse(cost.toStringAsFixed(2));
  }
}

/// Pre-configured pipeline templates for common use cases
class PipelineTemplates {
  /// Basic template: Transcription only (free tier)
  static PipelineConfig basicTemplate({
    required String userId,
    required String channelId,
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
  }) => PipelineConfig(
    enablePath1: false,
    userId: userId,
    channelId: channelId,
    videoTitle: videoTitle,
    videoDescription: videoDescription,
    videoDuration: videoDuration,
    videoCategory: videoCategory,
  );

  /// Content Creator Template: Dubbing + Subtitles (pro tier)
  static PipelineConfig contentCreatorTemplate({
    required String userId,
    required String channelId,
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
    required List<String> languages,
  }) => PipelineConfig(
    enablePath1: false,
    enablePath2: true,
    dubbingLanguages: languages,
    subtitleLanguages: languages,
    tier: 'pro',
    userId: userId,
    channelId: channelId,
    videoTitle: videoTitle,
    videoDescription: videoDescription,
    videoDuration: videoDuration,
    videoCategory: videoCategory,
  );

  /// Fact-Checker Template: Full credibility analysis (enterprise tier)
  static PipelineConfig factCheckerTemplate({
    required String userId,
    required String channelId,
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
  }) => PipelineConfig(
    enableFactCheck: true,
    enableExplainability: true,
    factCheckScoringMethod: 'strict',
    factCheckConfidenceThreshold: 0.8,
    enableDiarization: true,
    enableOCR: true,
    enableVisualContext: true,
    tier: 'enterprise',
    userId: userId,
    channelId: channelId,
    videoTitle: videoTitle,
    videoDescription: videoDescription,
    videoDuration: videoDuration,
    videoCategory: videoCategory,
  );

  /// Everything Enabled Template: All features (enterprise tier)
  static PipelineConfig fullFeaturedTemplate({
    required String userId,
    required String channelId,
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
    required List<String> languages,
  }) => PipelineConfig(
    enablePath2: true,
    dubbingLanguages: languages,
    subtitleLanguages: languages,
    enableDiarization: true,
    enableFactCheck: true,
    enableExplainability: true,
    enableOCR: true,
    enableVisualContext: true,
    enableAudioEnhancement: true,
    tier: 'enterprise',
    userId: userId,
    channelId: channelId,
    videoTitle: videoTitle,
    videoDescription: videoDescription,
    videoDuration: videoDuration,
    videoCategory: videoCategory,
  );
}





