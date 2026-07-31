import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/content_verification.dart';
import 'package:truthworld/features/video/data/models/pipeline_config.dart';
import 'package:truthworld/features/video/data/models/pipeline_status.dart';
import 'package:truthworld/features/video/data/services/pipeline_service.dart';

/// Pipeline Controller - Manages pipeline orchestration state
/// Handles configuration, job submission, status tracking
class PipelineController extends GetxController {
  final PipelineService _pipelineService = Get.find<PipelineService>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════

  // Current pipeline configuration
  Rx<PipelineConfig?> currentConfig = Rx<PipelineConfig?>(null);

  // Current job status
  Rx<PipelineJobStatus?> currentJobStatus = Rx<PipelineJobStatus?>(null);

  // Current verification
  Rx<ContentVerification?> currentVerification = Rx<ContentVerification?>(null);

  // User tier information
  Rx<Map<String, dynamic>> userTier = Rx<Map<String, dynamic>>({});

  // Remaining budget
  RxDouble remainingBudget = 0.0.obs;

  // Loading states
  RxBool isSubmitting = false.obs;
  RxBool isLoading = false.obs;
  RxBool isVerifying = false.obs;

  // Error messages
  RxString errorMessage = ''.obs;
  RxString warningMessage = ''.obs;

  // Available languages
  RxMap<String, String> supportedLanguages = RxMap<String, String>(
    PipelineService.supportedLanguages,
  );

  // Selected features UI state
  RxBool enablePath1 = false.obs; // Credibility
  RxBool enablePath2 = false.obs; // Dubbing
  RxList<String> selectedDubbingLanguages = <String>[].obs;
  RxList<String> selectedSubtitleLanguages = <String>['en'].obs;
  RxString voiceType = 'natural'.obs; // natural | standard | premium
  RxDouble ttsSpeed = 1.0.obs;

  // Credibility features
  RxBool enableFactCheck = false.obs;
  RxString factCheckScoring = 'balanced'.obs;
  RxDouble confidenceThreshold = 0.7.obs;
  RxBool enableExplainability = false.obs;

  // Auxiliary features
  RxBool enableOCR = false.obs;
  RxBool enableVisualContext = false.obs;
  RxBool enableAudioEnhancement = false.obs;
  RxBool enableChapters = false.obs;

  // Job tracking
  RxList<PipelineJobStatus> userJobs = <PipelineJobStatus>[].obs;

  @override
  void onInit() {
    super.onInit();
    _initializeUser();
    _loadUserTier();
  }

  /// Initialize user data
  Future<void> _initializeUser() async {
    try {
      await _loadUserTier();
      await _loadUserJobs();
    } catch (e) {
      errorMessage.value = 'Failed to initialize user data';
    }
  }

  /// Load user tier information
  Future<void> _loadUserTier() async {
    try {
      isLoading.value = true;
      userTier.value = await _pipelineService.getUserTier();
      remainingBudget.value = await _pipelineService.getRemainingBudget();
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  /// Load user's video processing jobs
  Future<void> _loadUserJobs() async {
    try {
      final jobs = await _pipelineService.getUserJobs();
      userJobs.value = jobs;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  /// Build current configuration from UI state
  PipelineConfig buildCurrentConfig({
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
    required String channelId,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return PipelineConfig(
      enablePath1: enablePath1.value,
      enablePath2: enablePath2.value,
      dubbingLanguages: selectedDubbingLanguages,
      enableSubtitles: selectedSubtitleLanguages.isNotEmpty,
      subtitleLanguages: selectedSubtitleLanguages,
      voiceType: voiceType.value,
      ttsSpeed: ttsSpeed.value,
      enableDiarization: enablePath1.value,
      enableFactCheck: enableFactCheck.value,
      factCheckScoringMethod: factCheckScoring.value,
      factCheckConfidenceThreshold: confidenceThreshold.value,
      enableExplainability: enableExplainability.value,
      enableOCR: enableOCR.value,
      enableVisualContext: enableVisualContext.value,
      enableAudioEnhancement: enableAudioEnhancement.value,
      enableChapters: enableChapters.value,
      tier: userTier.value['tier'] ?? 'free',
      estimatedCost: _calculateEstimatedCost(),
      userId: user.uid,
      channelId: channelId,
      videoTitle: videoTitle,
      videoDescription: videoDescription,
      videoDuration: videoDuration,
      videoCategory: videoCategory,
    );
  }

  /// Load configuration from preset template
  void loadTemplate(
    String templateId, {
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
    required String channelId,
  }) {
    final user = _auth.currentUser;
    if (user == null) return;

    late PipelineConfig config;

    switch (templateId) {
      case 'basic':
        config = PipelineTemplates.basicTemplate(
          userId: user.uid,
          channelId: channelId,
          videoTitle: videoTitle,
          videoDescription: videoDescription,
          videoDuration: videoDuration,
          videoCategory: videoCategory,
        );
      case 'content_creator':
        config = PipelineTemplates.contentCreatorTemplate(
          userId: user.uid,
          channelId: channelId,
          videoTitle: videoTitle,
          videoDescription: videoDescription,
          videoDuration: videoDuration,
          videoCategory: videoCategory,
          languages: ['es', 'fr', 'de'],
        );
      case 'fact_checker':
        config = PipelineTemplates.factCheckerTemplate(
          userId: user.uid,
          channelId: channelId,
          videoTitle: videoTitle,
          videoDescription: videoDescription,
          videoDuration: videoDuration,
          videoCategory: videoCategory,
        );
      case 'full_featured':
        config = PipelineTemplates.fullFeaturedTemplate(
          userId: user.uid,
          channelId: channelId,
          videoTitle: videoTitle,
          videoDescription: videoDescription,
          videoDuration: videoDuration,
          videoCategory: videoCategory,
          languages: ['es', 'fr', 'de', 'pt', 'hi', 'ja', 'zh'],
        );
      default:
        return;
    }

    // Apply template to UI state
    enablePath1.value = config.enablePath1;
    enablePath2.value = config.enablePath2;
    selectedDubbingLanguages.value = config.dubbingLanguages;
    selectedSubtitleLanguages.value = config.subtitleLanguages;
    voiceType.value = config.voiceType;
    ttsSpeed.value = config.ttsSpeed;
    enableFactCheck.value = config.enableFactCheck;
    factCheckScoring.value = config.factCheckScoringMethod;
    confidenceThreshold.value = config.factCheckConfidenceThreshold;
    enableExplainability.value = config.enableExplainability;
    enableOCR.value = config.enableOCR;
    enableVisualContext.value = config.enableVisualContext;
    enableAudioEnhancement.value = config.enableAudioEnhancement;
    enableChapters.value = config.enableChapters;

    currentConfig.value = config;
  }

  /// Submit video for pipeline processing
  Future<String?> submitVideo({
    required String videoUrl,
    required String videoTitle,
    required String videoDescription,
    required String videoDuration,
    required String videoCategory,
    required String channelId,
  }) async {
    try {
      errorMessage.value = '';
      isSubmitting.value = true;

      // Build configuration
      final config = buildCurrentConfig(
        videoTitle: videoTitle,
        videoDescription: videoDescription,
        videoDuration: videoDuration,
        videoCategory: videoCategory,
        channelId: channelId,
      );

      // Validate configuration
      final validation = _pipelineService.validateConfig(config);
      if (validation['isValid'] != true) {
        errorMessage.value = (validation['errors'] as List).join('\n');
        isSubmitting.value = false;
        return null;
      }

      // Warn user if there are warnings
      if ((validation['warnings'] as List).isNotEmpty) {
        warningMessage.value = (validation['warnings'] as List).join('\n');
      }

      // Check budget
      if (config.estimatedCost > remainingBudget.value) {
        errorMessage.value =
            'Insufficient budget. Remaining: \$${remainingBudget.value.toStringAsFixed(2)}';
        isSubmitting.value = false;
        return null;
      }

      // Submit video
      final jobId = await _pipelineService.submitVideo(
        videoUrl: videoUrl,
        config: config,
      );

      currentConfig.value = config;

      // Start tracking job status
      _startJobTracking(jobId);

      isSubmitting.value = false;
      return jobId;
    } catch (e) {
      errorMessage.value = e.toString();
      isSubmitting.value = false;
      return null;
    }
  }

  /// Start tracking job status
  void _startJobTracking(String jobId) {
    _pipelineService
        .streamJobStatus(jobId)
        .listen(
          (status) {
            if (status != null) {
              currentJobStatus.value = status;

              // Create verification when job is completed
              if (status.isCompleted && currentVerification.value == null) {
                _initiateVerification(jobId);
              }
            }
          },
          onError: (e) {
            errorMessage.value = 'Error tracking job: $e';
          },
        );
  }

  /// Initiate content verification
  Future<void> _initiateVerification(String videoId) async {
    try {
      isVerifying.value = true;
      final verificationId = await _pipelineService.createVerification(
        videoId: videoId,
        level: VerificationLevel.standard,
      );

      // Start tracking verification
      _pipelineService
          .streamVerification(verificationId)
          .listen(
            (verification) {
              if (verification != null) {
                currentVerification.value = verification;
              }
            },
            onError: (e) {
              warningMessage.value = 'Error tracking verification: $e';
            },
          );

      isVerifying.value = false;
    } catch (e) {
      warningMessage.value = e.toString();
      isVerifying.value = false;
    }
  }

  /// Get job by ID
  Future<PipelineJobStatus?> getJob(String jobId) async {
    return _pipelineService.getJobStatus(jobId);
  }

  /// Cancel video processing job
  Future<void> cancelJob(String jobId) async {
    try {
      await _pipelineService.cancelJob(jobId);
      currentJobStatus.value = null;
      errorMessage.value = '';
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  /// Retry failed job
  Future<String?> retryJob(String jobId) async {
    try {
      final newJobId = await _pipelineService.retryJob(jobId);
      _startJobTracking(newJobId);
      return newJobId;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    }
  }

  /// Reset form to defaults
  void resetForm() {
    enablePath1.value = false;
    enablePath2.value = false;
    selectedDubbingLanguages.value = [];
    selectedSubtitleLanguages.value = ['en'];
    voiceType.value = 'natural';
    ttsSpeed.value = 1.0;
    enableFactCheck.value = false;
    factCheckScoring.value = 'balanced';
    confidenceThreshold.value = 0.7;
    enableExplainability.value = false;
    enableOCR.value = false;
    enableVisualContext.value = false;
    enableAudioEnhancement.value = false;
    enableChapters.value = false;
    errorMessage.value = '';
    warningMessage.value = '';
  }

  /// Calculate estimated cost
  double _calculateEstimatedCost() {
    try {
      final videoDurationSeconds =
          int.tryParse(currentConfig.value?.videoDuration ?? '0') ?? 0;
      return PipelineConfig.calculateCost(
        tier: (userTier.value['tier'] as String?) ?? 'free',
        enablePath1: enablePath1.value,
        enablePath2: enablePath2.value,
        dubbingLanguageCount: selectedDubbingLanguages.length,
        enableFactCheck: enableFactCheck.value,
        enableSubtitles: selectedSubtitleLanguages.isNotEmpty,
        videoDuration: videoDurationSeconds.toString(),
      );
    } catch (e) {
      return 0;
    }
  }

  /// Toggle dubbing language selection
  void toggleDubbingLanguage(String languageCode) {
    if (selectedDubbingLanguages.contains(languageCode)) {
      selectedDubbingLanguages.remove(languageCode);
    } else {
      selectedDubbingLanguages.add(languageCode);
      // Auto-add subtitle for same language
      if (!selectedSubtitleLanguages.contains(languageCode)) {
        selectedSubtitleLanguages.add(languageCode);
      }
    }
  }

  /// Toggle subtitle language selection
  void toggleSubtitleLanguage(String languageCode) {
    if (selectedSubtitleLanguages.contains(languageCode)) {
      selectedSubtitleLanguages.remove(languageCode);
    } else {
      selectedSubtitleLanguages.add(languageCode);
    }
  }

  /// Get templates
  List<Map<String, dynamic>> getTemplates() {
    return PipelineService.getTemplates();
  }
}
