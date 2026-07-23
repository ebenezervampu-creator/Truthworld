import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/content_verification.dart';
import 'package:truthworld/features/video/data/models/pipeline_config.dart';
import 'package:truthworld/features/video/data/models/pipeline_status.dart';

/// Pipeline Service - Orchestrates video processing pipeline
/// Handles job submission, status tracking, and verification
class PipelineService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Available languages for dubbing and subtitles
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'it': 'Italian',
    'hi': 'Hindi',
    'ja': 'Japanese',
    'zh': 'Mandarin Chinese',
    'ar': 'Arabic',
    'ru': 'Russian',
    'ko': 'Korean',
    'th': 'Thai',
    'tr': 'Turkish',
    'id': 'Indonesian',
  };

  @override
  void onInit() {
    super.onInit();
    _setupPipelineListener();
  }

  /// Submit a video for pipeline processing
  Future<String> submitVideo({
    required String videoUrl,
    required PipelineConfig config,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create job document
      final jobRef = _firestore.collection('video_jobs').doc();
      final jobId = jobRef.id;

      await jobRef.set({
        'jobId': jobId,
        'userId': user.uid,
        'channelId': config.channelId,
        'videoUrl': videoUrl,
        'status': 'pending',
        'eventId': _generateEventId(),
        'executionPlan': {
          'enablePath1': config.enablePath1,
          'enablePath2': config.enablePath2,
          'languages': {
            'dubbing': config.dubbingLanguages,
            'subtitles': config.subtitleLanguages,
            'transcription': config.transcriptionLanguage,
          },
          'voiceType': config.voiceType,
          'ttsSpeed': config.ttsSpeed,
          'factCheck': {
            'enabled': config.enableFactCheck,
            'scoringMethod': config.factCheckScoringMethod,
            'confidenceThreshold': config.factCheckConfidenceThreshold,
            'explainability': config.enableExplainability,
          },
          'auxiliary': {
            'ocr': config.enableOCR,
            'visualContext': config.enableVisualContext,
            'audioEnhancement': config.enableAudioEnhancement,
          },
        },
        'config': {
          'tier': config.tier,
          'estimatedCost': config.estimatedCost,
          'monthlyBudgetLimit': config.monthlyBudgetLimit,
        },
        'metadata': {
          'videoTitle': config.videoTitle,
          'videoDescription': config.videoDescription,
          'videoDuration': config.videoDuration,
          'videoCategory': config.videoCategory,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'stages': {
          'transcription': {'status': 'pending', 'progress': 0},
          'credibility': {'status': 'pending', 'progress': 0},
          'dubbing': {'status': 'pending', 'progress': 0},
          'aggregation': {'status': 'pending', 'progress': 0},
        },
      });

      // Call Firebase function to submit video
      // In production, this would call: /api/v1/pipeline/submit-video
      // For now, we rely on Firestore triggers to start the pipeline

      return jobId;
    } catch (e) {
      throw Exception('Failed to submit video: $e');
    }
  }

  /// Get job status by job ID
  Future<PipelineJobStatus?> getJobStatus(String jobId) async {
    try {
      final doc = await _firestore.collection('video_jobs').doc(jobId).get();

      if (!doc.exists) {
        return null;
      }

      return PipelineJobStatus.fromMap(doc.data() ?? {});
    } catch (e) {
      throw Exception('Failed to fetch job status: $e');
    }
  }

  /// Stream job status for real-time updates
  Stream<PipelineJobStatus?> streamJobStatus(String jobId) {
    return _firestore.collection('video_jobs').doc(jobId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        return null;
      }
      return PipelineJobStatus.fromMap(doc.data() ?? {});
    });
  }

  /// Get all jobs for current user
  Future<List<PipelineJobStatus>> getUserJobs() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('video_jobs')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => PipelineJobStatus.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user jobs: $e');
    }
  }

  /// Stream all jobs for current user
  Stream<List<PipelineJobStatus>> streamUserJobs() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('video_jobs')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs
              .map((doc) => PipelineJobStatus.fromMap(doc.data()))
              .toList();
        });
  }

  /// Create content verification for video
  Future<String> createVerification({
    required String videoId,
    required VerificationLevel level,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final verificationRef = _firestore
          .collection('content_verifications')
          .doc();
      final verificationId = verificationRef.id;

      await verificationRef.set({
        'id': verificationId,
        'videoId': videoId,
        'userId': user.uid,
        'level': level.value,
        'status': VerificationStatus.pending.value,
        'checklist': {
          'profanity': {
            'name': 'Profanity Check',
            'description': 'Scanning for profanity and offensive language',
            'isComplete': false,
            'hasFailed': false,
          },
          'safety': {
            'name': 'Content Safety',
            'description': 'Analyzing for harmful or violent content',
            'isComplete': false,
            'hasFailed': false,
          },
          'copyright': {
            'name': 'Copyright Check',
            'description': 'Checking for copyright violations',
            'isComplete': false,
            'hasFailed': false,
          },
          'audio': {
            'name': 'Audio Quality',
            'description': 'Assessing audio quality and clarity',
            'isComplete': false,
            'hasFailed': false,
          },
          'transcript': {
            'name': 'Transcript Quality',
            'description': 'Verifying transcription accuracy',
            'isComplete': false,
            'hasFailed': false,
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return verificationId;
    } catch (e) {
      throw Exception('Failed to create verification: $e');
    }
  }

  /// Get verification status
  Future<ContentVerification?> getVerification(String verificationId) async {
    try {
      final doc = await _firestore
          .collection('content_verifications')
          .doc(verificationId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return ContentVerification.fromMap(doc.data() ?? {});
    } catch (e) {
      throw Exception('Failed to fetch verification: $e');
    }
  }

  /// Stream verification status
  Stream<ContentVerification?> streamVerification(String verificationId) {
    return _firestore
        .collection('content_verifications')
        .doc(verificationId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return null;
          }
          return ContentVerification.fromMap(doc.data() ?? {});
        });
  }

  /// Get user tier information
  Future<Map<String, dynamic>> getUserTier() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final doc = await _firestore.collection('user_tiers').doc(user.uid).get();

      if (!doc.exists) {
        // Return free tier by default
        return {
          'tier': 'free',
          'createdAt': DateTime.now(),
          'monthlyUsage': 0,
          'monthlyLimit': 100,
          'features': ['transcription'],
        };
      }

      return doc.data() ?? {};
    } catch (e) {
      throw Exception('Failed to fetch user tier: $e');
    }
  }

  /// Calculate remaining budget for user
  Future<double> getRemainingBudget() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 0.0;
      }

      final tierData = await getUserTier();
      final monthlyLimit = (tierData['monthlyBudgetLimit'] ?? 100.0).toDouble();
      final monthlyUsage = (tierData['monthlyUsage'] ?? 0.0).toDouble();

      return monthlyLimit - monthlyUsage;
    } catch (e) {
      return 0.0;
    }
  }

  /// Cancel video processing job
  Future<void> cancelJob(String jobId) async {
    try {
      await _firestore.collection('video_jobs').doc(jobId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to cancel job: $e');
    }
  }

  /// Retry failed job
  Future<String> retryJob(String jobId) async {
    try {
      final jobDoc = await _firestore.collection('video_jobs').doc(jobId).get();

      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data() ?? {};

      // Create new job with same configuration
      final newJobRef = _firestore.collection('video_jobs').doc();
      final newJobId = newJobRef.id;

      await newJobRef.set({
        ...jobData,
        'jobId': newJobId,
        'eventId': _generateEventId(),
        'status': 'pending',
        'retryOf': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return newJobId;
    } catch (e) {
      throw Exception('Failed to retry job: $e');
    }
  }

  /// Setup real-time pipeline listener
  void _setupPipelineListener() {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    // Listen for pipeline status updates via Pub/Sub
    _firestore
        .collection('pipeline_updates')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final update = PipelineStatusUpdate.fromMap(
                change.doc.data() ?? {},
              );
              _handlePipelineUpdate(update);
            }
          }
        });
  }

  /// Handle pipeline status updates
  void _handlePipelineUpdate(PipelineStatusUpdate update) {
    // This can be used to trigger notifications, UI updates, etc.
    debugPrint(
      '[Pipeline] ${update.stage.value} - ${update.status.value} (${(update.progress * 100).toInt()}%)',
    );
  }

  /// Generate idempotency key for event
  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_auth.currentUser?.uid}-${DateTime.now().microsecond}';
  }

  /// Validate pipeline configuration
  Map<String, dynamic> validateConfig(PipelineConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate tier and features
    if (config.tier == 'free') {
      if (config.enablePath2) {
        errors.add('Dubbing is not available on free tier');
      }
      if (config.enableFactCheck) {
        errors.add('Fact-checking is not available on free tier');
      }
    }

    // Validate dubbing languages
    if (config.enablePath2) {
      if (config.dubbingLanguages.isEmpty) {
        errors.add('At least one dubbing language must be selected');
      }

      for (final lang in config.dubbingLanguages) {
        if (!supportedLanguages.containsKey(lang)) {
          errors.add('Unsupported language: $lang');
        }
      }
    }

    // Validate TTS speed
    if (config.ttsSpeed < 0.8 || config.ttsSpeed > 1.2) {
      errors.add('TTS speed must be between 0.8x and 1.2x');
    }

    // Validate fact-check scoring method
    if (![
      'strict',
      'balanced',
      'lenient',
    ].contains(config.factCheckScoringMethod)) {
      errors.add('Invalid scoring method: ${config.factCheckScoringMethod}');
    }

    // Validate confidence threshold
    if (config.factCheckConfidenceThreshold < 0.0 ||
        config.factCheckConfidenceThreshold > 1.0) {
      errors.add('Confidence threshold must be between 0.0 and 1.0');
    }

    // Warn if no features enabled
    if (!config.enablePath1 && !config.enablePath2) {
      warnings.add('Only transcription will be performed');
    }

    return {'isValid': errors.isEmpty, 'errors': errors, 'warnings': warnings};
  }

  /// Get pipeline templates
  static List<Map<String, dynamic>> getTemplates() {
    return [
      {
        'id': 'basic',
        'name': 'Basic Transcription',
        'description': 'Transcription only (Free)',
        'icon': '📝',
        'tier': 'free',
        'features': ['Automatic Transcription', 'Speaker Diarization'],
      },
      {
        'id': 'content_creator',
        'name': 'Content Creator',
        'description': 'Dubbing & Subtitles (Pro)',
        'icon': '🎬',
        'tier': 'pro',
        'features': [
          'Transcription',
          'Dubbing (Multi-language)',
          'Subtitles',
          'Voice Cloning',
        ],
      },
      {
        'id': 'fact_checker',
        'name': 'Fact Checker',
        'description': 'Credibility Analysis (Enterprise)',
        'icon': '✅',
        'tier': 'enterprise',
        'features': [
          'Transcription',
          'Fact-Checking',
          'Claim Extraction',
          'Credibility Scoring',
          'Visual Analysis',
        ],
      },
      {
        'id': 'full_featured',
        'name': 'Everything Enabled',
        'description': 'All Features (Enterprise)',
        'icon': '⭐',
        'tier': 'enterprise',
        'features': [
          'Everything in Fact Checker',
          'Dubbing',
          'Subtitles',
          'Audio Enhancement',
          'OCR',
        ],
      },
    ];
  }
}
