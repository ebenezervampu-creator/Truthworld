import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:multi_lang_bad_words_filter/multi_lang_bad_words_filter.dart';
import 'package:safe_text/safe_text.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/core/utils/mentions_helper.dart';

// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/verification_cache_service.dart';

class UploadController extends GetxController with ContentValidationMixin {
  final _imageVerificationService = ImageVerificationService();
  final _cacheService = VerificationCacheService();
  final _performanceMonitor = VerificationPerformanceMonitor();
  StreamSubscription? _thumbnailModerationSubscription;
  StreamSubscription? _communityImageModerationSubscription;
  /// Returns the upload progress as a formatted percentage string (e.g., '42%')
  String get uploadProgressPercent =>
      '${(uploadProgress.value * 100).toStringAsFixed(0)}%';

  /// Real-time video upload progress (0.0 - 1.0)
  RxDouble videoUploadProgress = 0.0.obs;

  /// Real-time image upload progress (0.0 - 1.0)
  RxDouble imageUploadProgress = 0.0.obs;

  /// Current upload progress (0.0 - 1.0) - maintained for backward compatibility with UI
  RxDouble uploadProgress = 0.0.obs;
  RxString selectedCategory = "Other".obs;
  Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  RxString selectedVisibility = 'Public'.obs;
  RxBool isKidFriendly = false.obs;
  RxBool isShort = false.obs;
  RxString uploadQuality = 'Auto'.obs;
  RxBool enableComments = true.obs;
  RxBool allowRatings = false.obs;
  RxString selectedPlaylist = ''.obs;
  RxString selectedTopicId = ''.obs;
  RxList<Topic> availableTopics = <Topic>[].obs;
  RxBool isTopicsLoading = false.obs;
  RxString topicsError = ''.obs;
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;
  RxBool isScheduled = false.obs;
  Rx<DateTime> scheduledDate = DateTime.now().add(Duration(days: 1)).obs;
  final RxString finalstatus = "".obs;
  final RxString finalstatusReason = "".obs;

  // ══════════════════════════════════════════════════════════════
  // VIDEO CONTENT MODERATION STATE (Gemini Audio Analysis)
  // ══════════════════════════════════════════════════════════════
  final RxString videoModerationStatus = 'PENDING'.obs;
  final RxString videoModerationReason = ''.obs;
  final RxString videoModerationSummary = ''.obs;
  /// Whether the video content has been approved by Gemini moderation
  bool get isVideoContentApproved => videoModerationStatus.value == 'APPROVED';
  /// Whether the video was rejected (blocks Publish button)
  bool get isVideoContentRejected => videoModerationStatus.value == 'REJECTED';

  // ══════════════════════════════════════════════════════════════
  // AI FEATURE SELECTION STATE
  // ══════════════════════════════════════════════════════════════
  RxBool aiTranscriptEnabled = true.obs; // Always on
  RxBool aiChaptersEnabled = false.obs;
  RxBool aiGenerateSubtitles = false.obs;
  RxBool aiGenerateDubbing = false.obs;
  RxBool aiDiarizationEnabled = false.obs;
  RxBool aiSummaryEnabled = false.obs;
  RxList<String> aiTranslationLanguages = <String>[].obs;
  RxBool aiTTSEnabled = false.obs;
  RxString aiTTSVoiceType = 'default'.obs; // "default" | "cloned"
  RxBool aiFactCheckEnabled = false.obs;
  Rx<PlatformFile?> voiceSampleFile = Rx<PlatformFile?>(null);

  /// Build the AI features map for Firestore.
  Map<String, dynamic> buildFeaturesMap({String? pipelineStage}) {
    return AIFeatures(
      transcript: true,
      genLangSubs: aiGenerateSubtitles.value,
      generateDubbing: aiGenerateDubbing.value,
      translationLanguages: List<String>.from(aiTranslationLanguages),
      tts: TTSConfig(
        enabled: aiGenerateDubbing.value,
        voiceType: aiTTSVoiceType.value == 'cloned' ? 'voice_clone' : 'standard',
      ),
      factChecking: aiFactCheckEnabled.value,
      diarization: aiDiarizationEnabled.value,
      summary: aiSummaryEnabled.value,
      autoChapters: aiChaptersEnabled.value,
      pipelineStage: pipelineStage,
    ).toMap();
  }

  /// Pick a voice sample for TTS cloning.
  Future<void> pickVoiceSample() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        voiceSampleFile.value = result.files.first;
        Get.snackbar(
          'Success',
          'Voice sample selected: ${result.files.first.name}',
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick voice sample: \$e');
    }
  }

  VideoPlayerController? videoPlayerController;

  List<String> videoCategories = [
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Gaming',
    'Technology',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion & Beauty',
    'Food & Cooking',
    'Business & Finance',
    'Animation',
    'Short Films',
    'Motivation',
    'History',
    'Art & Design',
    'Automotive',
    'Animals & Pets',
    'Spirituality',
    'Nature & Wildlife',
    'Kids & Family',
  ];

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  void selectChannel(Channel channel) {
    selectedChannel.value = channel;
  }

  void selectPlaylist(String id) {
    selectedPlaylist.value = id;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  var videos = <Video>[].obs;
  var searchedVideos = <Video>[].obs;
  var channels = <Channel>[].obs;

  var pickedImage = Rx<PlatformFile?>(null);
  var pickedCommunityImage = Rx<PlatformFile?>(null);
  var pickedVideo = Rx<PlatformFile?>(null);

  // Storage for upload tasks and URLs
  UploadTask? _videoUploadTask;
  RxString videoUrl = ''.obs;
  RxString thumbnailUrl = ''.obs;
  RxString communityImageUrl = ''.obs;
  RxString communityImageStatus = ''.obs;
  RxString communityImageStatusReason = ''.obs;
  RxBool isUploading = false.obs;
  RxBool isCommunityPostUploading = false.obs;
  String?
  _currentVideoId; // Store the current video ID for linking storage and firestore

  /// Public getter for the current video ID being uploaded
  String? get currentVideoId => _currentVideoId;


  // Channel Loading State
  RxBool isChannelsLoading = true.obs;
  RxString channelsError = "".obs;
  StreamSubscription<QuerySnapshot>? _channelsSubscription;

  // ══════════════════════════════════════════════════════════════
  // MULTI-STAGE UPLOAD STATE MANAGEMENT
  // ══════════════════════════════════════════════════════════════
  RxInt uploadStage = 0.obs; // 0: Media, 1: Details, 2: Settings, 3: Publish
  RxString uploadStageLabel = "Upload Media".obs;
  RxBool canAdvanceStage = false.obs;
  
  // UI Processing State
  RxBool isProcessing = false.obs;
  RxString processingMessage = "".obs;
  RxBool isFormValid = false.obs;

  double get overallProgress => (uploadStage.value + 1) / 4.0;

  void setFormValid(bool valid) {
    isFormValid.value = valid;
  }

  // Store video metadata between stages
  Map<String, dynamic> _videoMetadata = {};

  // Validation constants
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int maxTags = 15;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    fetchChannelsWithRetry();
    fetchAvailableTopics();
    
    // Every video doesn't have video rating only when user enabled Factchecking
    ever(aiFactCheckEnabled, (bool enabled) {
      allowRatings.value = enabled;
    });
  }

  @override
  void onClose() {
    videoPlayerController?.dispose();
    _thumbnailModerationSubscription?.cancel();
    _communityImageModerationSubscription?.cancel();
    super.onClose();
  }

  // ==========================================================================
  // AUTHENTICATION & TOKEN MANAGEMENT
  // ==========================================================================

  /// Refresh the current user's auth token to ensure it's fresh
  Future<bool> _refreshAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return false;
      }

      // Force a token refresh with explicit caching invalidation
      final idToken = await user.getIdToken(true);

      // For web: ensure the token is persisted to localStorage
      if (kIsWeb) {
        debugPrint('🌐 Web platform detected - ensuring token persistence');
        // Token is automatically persisted by Firebase Auth SDK on web
      }

      debugPrint('✅ Auth token refreshed successfully');
      debugPrint('🔑 Token obtained (${idToken?.substring(0, 30)}...)');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to refresh auth token: $e');
      return false;
    }
  }

  /// Verify user is authenticated and token is valid
  Future<bool> _verifyAuthentication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Refresh token to ensure it's valid
      final refreshed = await _refreshAuthToken();
      if (!refreshed) {
        throw Exception("Failed to refresh authentication token");
      }

      debugPrint('✅ Authentication verified for user: ${user.uid}');
      return true;
    } catch (e) {
      debugPrint('❌ Authentication verification failed: $e');
      Get.snackbar(
        "Authentication Error",
        "Please log in again to continue uploading",
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  // ==========================================================================
  // MULTI-STAGE UPLOAD MANAGEMENT
  // ==========================================================================

  /// Update the current upload stage
  void setUploadStage(int stage) {
    uploadStage.value = stage;
    final stages = ["Upload Media", "All Details", "Settings", "Publish"];
    uploadStageLabel.value = stages[stage];
    debugPrint('📍 Moved to stage $stage: ${stages[stage]}');
  }

  /// Check if current stage is complete and valid
  bool _isCurrentStageValid() {
    switch (uploadStage.value) {
      case 0: // Upload Media
        return pickedVideo.value != null && videoUrl.value.isNotEmpty;
      case 1: // All Details
        return _videoMetadata.containsKey('title') &&
            _videoMetadata['title'].toString().isNotEmpty;
      case 2: // Settings
        return _videoMetadata.containsKey('category');
      case 3: // Publish
        return true;
      default:
        return false;
    }
  }

  /// Advance to the next stage
  Future<bool> advanceUploadStage() async {
    if (!_isCurrentStageValid()) {
      Get.snackbar(
        "Incomplete Stage",
        "Please complete the current stage before advancing",
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (uploadStage.value < 3) {
      setUploadStage(uploadStage.value + 1);
      return true;
    }
    return false;
  }

  /// Ensure auth context is ready for Storage operations on web
  Future<void> _ensureStorageAuthReady() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Get the ID token and ensure it's fresh
      await user.getIdToken(true);

      // On web, add a small delay to ensure Firebase Storage SDK picks it up
      if (kIsWeb) {
        debugPrint('⏳ Waiting for Storage auth context sync...');
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('✅ Storage auth context synchronized');
      }

      debugPrint('✅ Storage auth ready for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Failed to prepare Storage auth: $e');
      throw Exception("Storage auth preparation failed: $e");
    }
  }

  // validateContent is now provided by ContentValidationMixin



  // validateTags is now provided by ContentValidationMixin

  // ==========================================================================
  // CHANNEL AND FILE MANAGEMENT
  // ==========================================================================

  Future<void> fetchChannelsWithRetry() async {
    isChannelsLoading.value = true;
    channelsError.value = "";
    fetchChannels();
  }

  // Fetch channels with fallback to simple query if index missing
  void fetchChannels() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isChannelsLoading.value = false;
      channelsError.value = "User not logged in";
      return;
    }

    debugPrint('🔍 Fetching channels for user: ${user.uid}');

    // Cancel existing subscription
    _channelsSubscription?.cancel();

    _channelsSubscription = _firestore
        .collection("channels")
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint('✅ Channels loaded: ${snapshot.docs.length}');
            
            // Filter active channels in memory (status != deleted)
            channels.value = snapshot.docs
                .map((doc) => Channel.fromDocumentSnapshot(doc))
                .where((channel) => channel.status != ChannelStatus.deleted)
                .toList();

            isChannelsLoading.value = false;
            channelsError.value = "";

            // Auto-select first channel if none selected
            if (channels.isNotEmpty && selectedChannel.value == null) {
              selectedChannel.value = channels.first;
              debugPrint(
                'Auto-selected channel: ${channels.first.channelName}',
              );
            }
          },
          onError: (error) {
            debugPrint('❌ Error fetching channels: $error');
            isChannelsLoading.value = false;
            channelsError.value = "Failed to load channels: $error";
          },
        );
  }

  Future<void> pickImage({required bool forCommunity}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        if (forCommunity) {
          pickedCommunityImage.value = result.files.first;
        } else {
          pickedImage.value = result.files.first;
        }
        await _startImageUpload(result.files.first, forCommunity: forCommunity);
      } else {
        Get.snackbar("Info", "No image selected.");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick image: $e");
    }
  }

  Future<void> pickVideo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        const maxSizeInBytes = 2 * 1024 * 1024 * 1024; // 2GB
        if (pickedFile.size > maxSizeInBytes) {
          Get.snackbar("Error", "Selected video exceeds the 2GB limit.");
          return;
        }

        final extension = pickedFile.extension?.toLowerCase();
        if (extension != 'mp4' && extension != 'mov') {
          Get.snackbar("Error", "Only MP4/MOV videos allowed.");
          return;
        }

        const maxDurationSeconds = 60 * 60; // 60 minutes

        int duration;
        if (kIsWeb) {
          final blob = html.Blob([pickedFile.bytes!]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final video = html.VideoElement()
            ..src = url
            ..preload = 'metadata';

          await video.onLoadedMetadata.first;
          duration = video.duration.floor();
          html.Url.revokeObjectUrl(url);
        } else {
          final file = io.File(pickedFile.path!);
          final controller = VideoPlayerController.file(file);

          await controller.initialize();
          duration = controller.value.duration.inSeconds;
          await controller.dispose();
        }

        if (duration > maxDurationSeconds) {
          Get.snackbar("Error", "Video exceeds 60 minute limit.");
          return;
        }

        pickedVideo.value = pickedFile;
        Get.snackbar("Success", "Video selected successfully!");

        await initializeVideoPlayer();
        await _startVideoUpload(pickedVideo.value!);
      } else {
        Get.snackbar("Info", "No video selected.");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick video: $e");
    }
  }

  Future<void> initializeVideoPlayer() async {
    if (pickedVideo.value == null) return;

    final file = pickedVideo.value!;

    if (videoPlayerController != null) {
      await videoPlayerController!.dispose();
      videoPlayerController = null;
    }

    if (kIsWeb) {
      final blob = html.Blob([file.bytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      videoPlayerController = VideoPlayerController.file(File(file.path!));
    }

    await videoPlayerController!.initialize();
    videoPlayerController!.setLooping(true);
    update();
  }

  Future<String> getVideoDurationFormatted(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';

        final durationInSeconds = await videoElement.onLoadedMetadata.first
            .then((_) => videoElement.duration);

        html.Url.revokeObjectUrl(url);

        final duration = Duration(seconds: durationInSeconds.floor());
        return _formatDuration(duration);
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${videoFile.name}');
        await tempFile.writeAsBytes(videoFile.bytes!);

        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        final duration = controller.value.duration;
        await controller.dispose();

        return _formatDuration(duration);
      }
    } catch (e) {
      throw Exception("Failed to get video duration: $e");
    }
  }

  Future<int> getVideoDurationMs(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';

        final durationInSeconds = await videoElement.onLoadedMetadata.first
            .then((_) => videoElement.duration);

        html.Url.revokeObjectUrl(url);

        return (durationInSeconds * 1000).floor();
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${videoFile.name}');
        await tempFile.writeAsBytes(videoFile.bytes!);

        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        final durationMs = controller.value.duration.inMilliseconds;
        await controller.dispose();

        return durationMs;
      }
    } catch (e) {
      throw Exception("Failed to get video duration: $e");
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _startVideoUpload(PlatformFile videoFile) async {
    // Cancel any previous upload
    if (isUploading.value) {
      await _videoUploadTask?.cancel();
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    setUploadStage(0); // Start at Media upload stage

    StreamSubscription<DocumentSnapshot>? statusListener;

    try {
      // ✅ STEP 0: REFRESH AUTHENTICATION TOKEN
      debugPrint('🔐 Refreshing authentication token...');
      final authValid = await _verifyAuthentication();
      if (!authValid) {
        throw Exception("Authentication failed. Please log in again.");
      }

      debugPrint('🔐 Verifying authentication before upload...');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not authenticated");

      final userId = currentUser.uid;
      final uniqueId = const Uuid().v4();
      _currentVideoId = uniqueId;
      debugPrint('✅ Authenticated user: $userId');
      debugPrint('🆔 Generated video ID: $uniqueId');

      // --------------------------------------------------------
      // 1️⃣ Create initial Firestore document (with AI features)
      // --------------------------------------------------------
      final initialData = {
        'id': uniqueId,
        'ownerId': userId,
        'userId': userId,
        'status': 'uploading', // Will change via Cloud Function
        'uploadedAt': Timestamp.now(),
        'title': 'Uploading...',
        'description': 'Processing...',
        'videoUrl': '',
        'thumbnailUrl': '',
        'likes': 0,
        'likedby': [],
        'views': 0,
        'shares': [],
        'downloads': 0,
        'reportCount': 0,
        'reports': [],
        'isBlocked': false,
        'visibility': selectedVisibility.value,
        'category': selectedCategory.value,
        'tags': [],
        'fileName': videoFile.name,
        // AI Processing features (read by backend pipeline)
        'aiFeatures': buildFeaturesMap(pipelineStage: 'draft'),
        'storage': {'videoPath': 'videos/$uniqueId/original.mp4'},
      };

      debugPrint('📄 Creating Firestore placeholder with AI features...');
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(uniqueId)
          .set(initialData);
      debugPrint(
        '✅ Placeholder created with features: ${initialData['features']}',
      );

      // --------------------------------------------------------
      // 2️⃣ Listen for Firestore status updates (from Cloud Function)
      // --------------------------------------------------------
      statusListener = FirebaseFirestore.instance
          .collection('videos')
          .doc(uniqueId)
          .snapshots()
          .listen((snapshot) {
            final data = snapshot.data();
            if (data == null) return;
            final status = data['status'] as String?;
            debugPrint('📡 Firestore status update: $status');

            // ── Video Content Moderation Status ──────────────────────
            final moderation = data['moderation'] as Map<String, dynamic>?;
            if (moderation != null) {
              final modStatus = (moderation['status'] as String?)?.toUpperCase() ?? 'PENDING';
              final modReason = moderation['reason'] as String? ?? '';
              final modSummary = moderation['summary'] as String? ?? '';

              // Only show snackbar on status transition
              if (modStatus != videoModerationStatus.value) {
                videoModerationStatus.value = modStatus;
                videoModerationReason.value = modReason;
                videoModerationSummary.value = modSummary;

                if (modStatus == 'APPROVED') {
                  debugPrint('✅ Video content APPROVED by Gemini moderation');
                  Get.snackbar(
                    "Content Approved",
                    "✅ Your video complies with Community Guidelines",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    duration: const Duration(seconds: 3),
                  );
                } else if (modStatus == 'REJECTED') {
                  debugPrint('❌ Video content REJECTED: $modReason');
                  Get.snackbar(
                    "Content Rejected",
                    "❌ $modReason",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    duration: const Duration(seconds: 5),
                  );
                } else if (modStatus == 'PROCESSING') {
                  debugPrint('🔍 Video content moderation in progress...');
                }
              }
            }

            // Sync URLs from backend if they exist
            if (data['videoUrl'] != null &&
                (data['videoUrl'] as String).isNotEmpty) {
              videoUrl.value = data['videoUrl'] as String;
            }
            if (data['thumbnailUrl'] != null &&
                (data['thumbnailUrl'] as String).isNotEmpty) {
              thumbnailUrl.value = data['thumbnailUrl'] as String;
            }

            if (status == 'processed') {
              debugPrint('✅ Processing completed successfully!');
              videoUploadProgress.value = 1.0;
              uploadProgress.value = 1.0;
              isUploading.value = false;

              // Final check on URLs to ensure UI is ready
              if (data['videoUrl'] != null) videoUrl.value = data['videoUrl'];
              if (data['thumbnailUrl'] != null) {
                thumbnailUrl.value = data['thumbnailUrl'];
              }

              Get.snackbar(
                "Success",
                "Video processed and ready to publish!",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF10B981),
                colorText: Colors.white,
              );
              statusListener?.cancel();
            } else if (status == 'rejected') {
              final reason = data['rejectionReason'] ?? 'Content violates Community Guidelines';
              debugPrint('❌ Video REJECTED by moderation: $reason');
              isUploading.value = false;
              videoUploadProgress.value = 0.0;
              uploadProgress.value = 0.0;
              Get.snackbar(
                "Video Rejected",
                "$reason",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444),
                colorText: Colors.white,
                duration: const Duration(seconds: 5),
              );
              statusListener?.cancel();
            } else if (status == 'failed') {
              final error = data['error'] ?? 'Unknown processing error';
              debugPrint('❌ Processing failed: $error');
              isUploading.value = false;
              videoUploadProgress.value = 0.0;
              uploadProgress.value = 0.0;
              Get.snackbar(
                "Error",
                "Video processing failed: $error",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444),
                colorText: Colors.white,
              );
              statusListener?.cancel();
            }
          });

      // --------------------------------------------------------
      // 3️⃣ Upload video to Firebase Storage
      // --------------------------------------------------------
      debugPrint('☁️ Uploading video to Firebase Storage...');

      // 🔑 CRITICAL: Ensure Storage auth context is ready on web
      debugPrint('🔐 Preparing Storage auth context...');
      await _ensureStorageAuthReady();

      // Upload to nested path: videos/{id}/original.mp4 (pipeline structure)
      final videoRef = FirebaseStorage.instance.ref().child(
        'videos/$uniqueId/original.mp4',
      );
      final metadata = SettableMetadata(contentType: 'video/mp4');
      _videoUploadTask = videoRef.putData(videoFile.bytes!, metadata);

      // Upload voice sample if Dubbing with cloning is selected
      if (aiGenerateDubbing.value &&
          aiTTSVoiceType.value == 'cloned' &&
          voiceSampleFile.value != null) {
        final sampleRef = FirebaseStorage.instance.ref().child(
          'videos/$uniqueId/voice_sample.mp3',
        );
        final sampleMeta = SettableMetadata(contentType: 'audio/mpeg');
        await sampleRef.putData(voiceSampleFile.value!.bytes!, sampleMeta);
        debugPrint('🎙️ Voice sample uploaded for cloning');
      }

      _videoUploadTask!.snapshotEvents.listen(
        (event) {
          if (event.totalBytes > 0) {
            // Report full upload progress (0.0 - 1.0). Do not cap at 90%.
            final progress = (event.bytesTransferred / event.totalBytes);
            videoUploadProgress.value = progress;
            uploadProgress.value = progress;
            if (progress % 0.1 < 0.01) {
              debugPrint(
                '📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
              );
            }
          }
        },
        onError: (e) {
          debugPrint('Video upload stream error: $e');
        },
      );

      final snapshot = await _videoUploadTask!.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Video uploaded successfully');
      debugPrint('🔗 Video URL: $downloadUrl');
      videoUrl.value = downloadUrl;

      // --------------------------------------------------------
      // 4️⃣ Update Firestore with video URL
      // --------------------------------------------------------
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(uniqueId)
          .update({
            'videoUrl': downloadUrl,
            'status': 'processing', // Optional: hint for Cloud Function
          });

      // --------------------------------------------------------
      // 5️⃣ Notify user that processing is in progress
      // --------------------------------------------------------
      // Upload finished — show mostly-complete but not 100% so UI doesn't show published.
      // Keep a small gap while server-side processing completes.
      videoUploadProgress.value = 0.99;
      uploadProgress.value = 0.99;
      // Allow new uploads while processing continues server-side.
      isUploading.value = false;
      Get.snackbar(
        "Processing",
        "Upload complete! Processing video...",
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
      );

      debugPrint('⏳ Waiting for Cloud Function to complete processing...');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase error: ${e.message}');
      debugPrint('🔥 Firebase error code: ${e.code}');
      debugPrint('🔥 Firebase plugin: ${e.plugin}');
      debugPrint('🔥 Full exception: $e');
      isUploading.value = false;
      uploadProgress.value = 0.0;

      if (_currentVideoId != null) {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(_currentVideoId)
            .delete();
        debugPrint('🗑️ Cleaned up failed Firestore document');
      }

      // Handle specific auth errors with web-specific diagnostics
      String errorMessage = "Upload failed";
      if (e.code.contains('permission-denied') ||
          e.code.contains('unauthorized') ||
          e.message?.contains('not authorized') == true) {
        errorMessage =
            "Authorization error. Please try:\n"
            "1. Clear browser cache (Ctrl+Shift+Del)\n"
            "2. Log out completely\n"
            "3. Log back in\n"
            "4. Try uploading again";
        debugPrint('⚠️ AUTH ERROR DETECTED');
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
        debugPrint('   Plugin: ${e.plugin}');
        debugPrint('   Platform: ${kIsWeb ? "Web (Flutter)" : "Native"}');
      } else if (e.code.contains('unauthenticated')) {
        errorMessage = "Authentication expired. Please log in again.";
        debugPrint('⚠️ SESSION EXPIRED - Redirecting to login');
      } else {
        errorMessage = "Failed to upload video: ${e.message}";
      }

      Get.snackbar(
        "Error",
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during upload: $e\n$stackTrace');
      isUploading.value = false;
      uploadProgress.value = 0.0;
      statusListener?.cancel();

      if (_currentVideoId != null) {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(_currentVideoId)
            .delete();
      }

      Get.snackbar(
        "Error",
        "Unexpected error: $e",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Separate refs/tasks for video thumbnails vs community post images
  Reference? _currentImageRefVideo;
  Reference? _currentImageRefCommunity;

  UploadTask? _currentUploadTaskVideo;
  UploadTask? _currentUploadTaskCommunity;

  // Keep track of moderation listeners for all uploaded images


  // Track uploaded doc ids (both video and community)
  List<String> uploadedDocIds = [];

  Future<void> _startImageUpload(
    PlatformFile imageFile, {
    bool forCommunity = false,
  }) async {
    uploadProgress.value = 0.0;

    // Determine which task/ref to use
    UploadTask? activeTask = forCommunity
        ? _currentUploadTaskCommunity
        : _currentUploadTaskVideo;
    Reference? existingRef = forCommunity
        ? _currentImageRefCommunity
        : _currentImageRefVideo;

    // 1️⃣ Cancel previous upload if running for this type
    if (activeTask != null) {
      try {
        await activeTask.cancel();
        debugPrint(
          "Previous ${forCommunity ? 'community' : 'video'} upload cancelled",
        );
      } catch (e) {
        debugPrint(
          "Failed to cancel previous ${forCommunity ? 'community' : 'video'} upload: $e",
        );
      }
    }

    // 2️⃣ Delete previous image from storage (if exists and uploaded) for this type
    if (existingRef != null) {
      try {
        await existingRef.getMetadata();
        await existingRef.delete();
        debugPrint(
          "Previous ${forCommunity ? 'community' : 'video'} image deleted from storage",
        );
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
          debugPrint("Previous image does not exist, skipping delete");
        } else {
          debugPrint("Failed to delete previous image: $e");
        }
      }
    }

    try {
      // 3️⃣ Generate unique file name (normalize extension for consistency)
      final extension = (imageFile.extension ?? 'jpg').toLowerCase();
      final uniqueFileName = '${_uuid.v4()}.$extension';
      final storagePath = forCommunity
          ? 'community_images/$uniqueFileName'
          : 'thumbnails/$uniqueFileName';
      final imageRef = _firebaseStorage.ref().child(storagePath);

      // Save ref in the correct slot
      if (forCommunity) {
        _currentImageRefCommunity = imageRef;
      } else {
        _currentImageRefVideo = imageRef;
      }

      // 4️⃣ Start new upload
      final metadata = SettableMetadata(
        contentType: 'image/${imageFile.extension}',
      );
      final uploadTask = imageRef.putData(imageFile.bytes!, metadata);
      if (forCommunity) {
        _currentUploadTaskCommunity = uploadTask;
      } else {
        _currentUploadTaskVideo = uploadTask;
      }

      // Track progress
      uploadTask.snapshotEvents.listen(
        (event) {
          if (event.totalBytes > 0) {
            imageUploadProgress.value =
                event.bytesTransferred / event.totalBytes;
          }
        },
        onError: (e) {
          debugPrint('Image upload stream error: $e');
        },
      );

      // 5️⃣ Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update UI with the latest image URL for the correct flow
      if (forCommunity) {
        communityImageUrl.value = downloadUrl;
      } else {
        thumbnailUrl.value = downloadUrl;
      }
      debugPrint("Image uploaded successfully: $downloadUrl");

      // 6️⃣ Track moderation for this image
      final docId = uniqueFileName;
      uploadedDocIds.add(docId);

      _startImageVerification(docId, forCommunity: forCommunity);
    } catch (e) {
      uploadProgress.value = 0.0;
      Get.snackbar("Error", "Failed to upload image: $e");
    }
  }

  void _startImageVerification(String docId, {required bool forCommunity}) {
    final subscription = _imageVerificationService
        .streamVerificationStatus(docId)
        .listen((result) {
      final status = result.status.name.toUpperCase();
      final reason = result.reason;

      if (forCommunity) {
        communityImageStatus.value = status;
        communityImageStatusReason.value = reason;
      } else {
        finalstatus.value = status;
        finalstatusReason.value = reason;
      }

      // Cache the result for future reference
      _cacheService.setVerification(docId, result);

      debugPrint("🔍 [VERIFICATION UPDATE] $docId: $status (community=$forCommunity)");
      debugPrint("   Reason: $reason");

      if (status == "REJECTED") {
        Get.snackbar(
          "Rejected",
          "Your image was rejected: $reason",
          backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.1),
          duration: const Duration(seconds: 4),
        );
      } else if (status == "FLAGGED") {
        Get.snackbar(
          "Review",
          "Your image needs review: $reason",
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          duration: const Duration(seconds: 4),
        );
      } else if (status == "APPROVED") {
        Get.snackbar(
          "Approved",
          "✅ Your image was approved!",
          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
          duration: const Duration(seconds: 3),
        );
      }

      if (status != "PENDING") {
        Future.delayed(const Duration(seconds: 2), () {
          if (forCommunity) {
            _communityImageModerationSubscription?.cancel();
          } else {
            _thumbnailModerationSubscription?.cancel();
          }
        });
      }
    }, onError: (error) {
      debugPrint('❌ [VERIFICATION ERROR] $error');
      if (forCommunity) {
        communityImageStatus.value = "ERROR";
        communityImageStatusReason.value = "Verification service error: $error";
      } else {
        finalstatus.value = "ERROR";
        finalstatusReason.value = "Verification service error: $error";
      }
      Get.snackbar(
        "Verification Error",
        "Failed to verify image: $error",
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
        duration: const Duration(seconds: 4),
      );
      if (forCommunity) {
        _communityImageModerationSubscription?.cancel();
      } else {
        _thumbnailModerationSubscription?.cancel();
      }
    });

    if (forCommunity) {
      _communityImageModerationSubscription = subscription;
    } else {
      _thumbnailModerationSubscription = subscription;
    }
  }

  List<String> _generateKeywords(String title) {
    final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final words = cleanTitle.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final Set<String> keywords = {};
    for (final word in words) {
      keywords.add(word);
      for (int i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    return keywords.toList();
  }

  Future<void> uploadVideo(
    String title,
    String description,
    String channelName,
    String channelId,
    String channelImage,
    List<String> tags,
    List<String> selectedLanguages,
  ) async {
    debugPrint('Starting final video metadata update...');

    // Store metadata for multi-stage flow
    _videoMetadata = {
      'title': title,
      'description': description,
      'channelName': channelName,
      'channelId': channelId,
      'channelImage': channelImage,
      'tags': tags,
      'languages': selectedLanguages,
    };

    if (pickedVideo.value == null) {
      Get.snackbar("Error", "Please select a video.");
      return;
    }

    if (videoUrl.value.isEmpty) {
      Get.snackbar("Error", "Video upload not complete.");
      return;
    }

    // All your validations...
    if (title.isEmpty || title.length > maxTitleLength) {
      Get.snackbar("Error", "Invalid title.");
      return;
    }

    final titleValidation = await validateContent(title, fieldName: 'Title');
    if (!titleValidation.isValid) {
      Get.snackbar("Error", titleValidation.message);
      return;
    }

    // Description validation
    if (description.isEmpty || description.length > maxDescriptionLength) {
      Get.snackbar("Error", "Invalid description.");
      return;
    }

    final descValidation = await validateContent(
      description,
      fieldName: 'Description',
      checkPhoneNumbers: true,
    );
    if (!descValidation.isValid) {
      Get.snackbar("Error", descValidation.message);
      return;
    }

    // Tags validation
    final validTags = tags.where((t) => t.trim().isNotEmpty).toList();
    if (validTags.isNotEmpty) {
      final tagsValidation = await validateTags(validTags);
      if (!tagsValidation.isValid) {
        Get.snackbar("Error", tagsValidation.message);
        return;
      }
    }

    if (channelName.trim().isEmpty) {
      Get.snackbar("Error", "Selected channel name is missing. Please select a valid channel.");
      return;
    }
    
    if (channelId.trim().isEmpty) {
      Get.snackbar("Error", "Selected channel ID is missing. Please select a valid channel.");
      return;
    }

    try {
      // 🔑 REFRESH TOKEN BEFORE FINAL PUBLISH
      debugPrint('🔐 Refreshing token before final publish...');
      final authValid = await _verifyAuthentication();
      if (!authValid) {
        throw Exception("Authentication failed before publishing");
      }

      debugPrint('🔐 Checking authentication...');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not authenticated");
      }
      final userId = currentUser.uid;
      debugPrint('✅ User authenticated: $userId');

      // Get video duration in milliseconds
      final durationMs = await getVideoDurationMs(
        pickedVideo.value!,
      );

      // Upload thumbnail if needed
      if (thumbnailUrl.value.isEmpty && pickedImage.value != null) {
        await _startImageUpload(pickedImage.value!);
      }
      if (thumbnailUrl.value.isEmpty) {
        thumbnailUrl.value =
            'https://via.placeholder.com/1280x720.png?text=No+Thumbnail';
      }

      final validLanguages = selectedLanguages.whereType<String>().toList();

      // Use the ID that was created during video upload
      final videoId = _currentVideoId;
      if (videoId == null) {
        throw Exception("No video ID found - upload may have failed");
      }

      debugPrint('📄 Video ID: $videoId');
      debugPrint('👤 Owner ID: $userId');

      // CHECK IF DOCUMENT EXISTS FIRST
      debugPrint('🔍 Checking if document exists...');
      final docRef = _firestore.collection('videos').doc(videoId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint('❌ Document does not exist! This should not happen.');
        throw Exception("Video document not found in Firestore");
      }

      debugPrint('✅ Document exists');
      debugPrint('📋 Current document data: ${docSnapshot.data()}');

      // Verify ownership
      final existingOwnerId = docSnapshot.data()?['ownerId'];
      if (existingOwnerId != userId) {
        debugPrint('❌ OWNERSHIP MISMATCH!');
        debugPrint('   Document ownerId: $existingOwnerId');
        debugPrint('   Current user ID: $userId');
        throw Exception("Ownership verification failed");
      }

      debugPrint('✅ Ownership verified');

      // Prepare update data
      final updateData = {
        'title': title.trim(),
        'description': description.trim(),
        'keywords': _generateKeywords(title.trim()),
        'videoUrl': videoUrl.value,
        'thumbnailUrl': thumbnailUrl.value,
        'channelName': channelName.trim(),
        'channelId': channelId.trim(),
        'channelImage': channelImage,
        'category': selectedCategory.value.isEmpty
            ? 'Uncategorized'
            : selectedCategory.value,
        'tags': validTags,
        'languages': validLanguages,
        'visibility': selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
        'isShort': isShort.value,
        'uploadQuality': uploadQuality.value.isEmpty
            ? 'Auto'
            : uploadQuality.value,
        'enableComments': enableComments.value,
        'allowRatings': allowRatings.value,
        'durationMs': durationMs,
        'fileName': pickedVideo.value?.name ?? 'unnamed_video.mp4',
        'status': isScheduled.value ? 'scheduled' : 'published',
        'aiFeatures': buildFeaturesMap(pipelineStage: 'published'),
      };

      // Handle inline topic creation if needed
      if (newTopicData.isNotEmpty) {
        debugPrint('🆕 Creating new inline topic: ${newTopicData['title']}');
        
        final String newTitle = newTopicData['title'];
        final String newDescription = newTopicData['description'] ?? '';
        final String newCategory = newTopicData['category'] ?? 'Music';
        final TopicVisibilityType newVisibility = newTopicData['visibilityType'] ?? TopicVisibilityType.public;
        final String? newAccessCode = newTopicData['accessCode'];
        final String thumbnailSource = newTopicData['thumbnailSource'] ?? 'video';
        
        String? finalThumbnailUrl;
        if (thumbnailSource == 'custom' && newTopicData['customThumbnailBytes'] != null) {
          final bytes = newTopicData['customThumbnailBytes'] as Uint8List;
          final fileName = newTopicData['customThumbnailName'] ?? 'custom_topic_thumb.jpg';
          finalThumbnailUrl = await uploadTopicCustomThumbnail(bytes, fileName);
        } else {
          // Use first video's thumbnail
          finalThumbnailUrl = thumbnailUrl.value;
        }
        
        final String newSlug = newTitle
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');
            
        final existingSlug = await _firestore
            .collection('topics')
            .where('slug', isEqualTo: newSlug)
            .limit(1)
            .get();
            
        String finalSlug = newSlug;
        if (existingSlug.docs.isNotEmpty) {
          finalSlug = '$newSlug-${const Uuid().v4().substring(0, 6)}';
        }

        final String rawHandle = newTopicData['handle'] ?? '';
        String cleanHandle = rawHandle.trim();
        if (cleanHandle.startsWith('T/')) {
          cleanHandle = cleanHandle.substring(2);
        }
        if (cleanHandle.startsWith('t/')) {
          cleanHandle = cleanHandle.substring(2);
        }
        cleanHandle = cleanHandle
            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')
            .replaceAll(RegExp(r'-+'), '-');
        if (cleanHandle.isEmpty) {
          cleanHandle = finalSlug;
        }
        final String finalHandle = 'T/$cleanHandle';
        final String finalHandleLowercase = finalHandle.toLowerCase();
        
        final newTopicRef = _firestore.collection('topics').doc();
        final newTopic = Topic(
          id: newTopicRef.id,
          title: newTitle,
          slug: finalSlug,
          handle: finalHandle,
          handleLowercase: finalHandleLowercase,
          description: newDescription,
          category: newCategory,
          thumbnailUrl: finalThumbnailUrl,
          channelId: channelId.trim(),
          creatorId: userId,
          visibilityType: newVisibility,
          accessCode: newVisibility == TopicVisibilityType.private ? newAccessCode : null,
          videoCount: 1, // Enforces the rule that it has 1 video now
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'underReview',
        );
        
        await newTopicRef.set(newTopic.toMap());
        debugPrint('✅ Inline topic created with slug: $finalSlug and handle: $finalHandle');
        
        selectedTopicId.value = finalSlug;
        newTopicData.clear();
      }

      // Link video to topic if selected
      if (selectedTopicId.value.isNotEmpty) {
        debugPrint('🔗 Linking video to topic: ${selectedTopicId.value}');
        updateData['topicId'] = selectedTopicId.value;
        updateData['topics'] = [selectedTopicId.value];
      }

      if (isScheduled.value) {
        updateData['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      debugPrint('📝 Updating document with metadata...');
      debugPrint('Update data keys: ${updateData.keys.toList()}');

      // IMPORTANT: Use update() not set() to preserve Cloud Function data
      await docRef.update(updateData);

      // Scan for handle mentions and notify
      final String fullMetadataText = '${title.trim()} ${description.trim()}';
      try {
        await MentionsHelper.processAndNotifyMentions(
          text: fullMetadataText,
          videoId: videoId,
          videoTitle: title.trim(),
          videoThumbnailUrl: thumbnailUrl.value,
          videoChannelId: channelId.trim(),
        );
      } catch (e) {
        debugPrint('⚠️ Error processing mentions for video upload: $e');
      }

      debugPrint('✅ Document updated successfully!');

      if (selectedTopicId.value.isNotEmpty) {
        final topicQuery = await _firestore.collection('topics')
            .where('slug', isEqualTo: selectedTopicId.value)
            .limit(1)
            .get();
        if (topicQuery.docs.isNotEmpty) {
          final topicDoc = topicQuery.docs.first;
          final topicData = Topic.fromDocumentSnapshot(topicDoc);
          if (DateTime.now().difference(topicData.createdAt).inSeconds > 5) {
            await topicDoc.reference.update({
              'videoCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ Incremented videoCount for existing topic: ${selectedTopicId.value}');
          }
        }
      }

      // Add to playlist if selected
      if (selectedPlaylist.value.isNotEmpty) {
        debugPrint('📂 Adding to playlist: ${selectedPlaylist.value}');
        try {
          final playlistController = Get.find<PlaylistController>();
          await playlistController.addVideoToPlaylist(
            selectedPlaylist.value,
            videoId,
            true, // We assume public_playlists based on the current upload flow
          );
          debugPrint('✅ Successfully added video to playlist via PlaylistController');
        } catch (e) {
          debugPrint('⚠️ Error adding to playlist via controller: $e');
          // Fallback to manual update if controller not found or fails
          await _firestore
              .collection('public_playlists')
              .doc(selectedPlaylist.value)
              .update({
                'videoIds': FieldValue.arrayUnion([videoId]),
              });
        }
      }


      // Move to publish stage
      setUploadStage(3);

      debugPrint('🎉 Upload completed successfully!');
      Get.snackbar("Success", "Video uploaded successfully!");
      uploadProgress.value = 0.0;
      _resetUploads();
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException caught:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Plugin: ${e.plugin}');

      String errorMessage = "Failed to update video: ";
      if (e.code == 'permission-denied' ||
          e.message?.contains('not authorized') == true) {
        errorMessage +=
            "Permission denied. Please log in again and try uploading.";
        debugPrint('⚠️ AUTH ERROR - User needs to re-authenticate');
      } else {
        errorMessage += e.message ?? e.code;
      }

      Get.snackbar("Error", errorMessage);
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR: Upload failed');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      Get.snackbar("Error", "Failed to complete video upload: $e");
    }
  }
  // ==========================================================================
  // COMMUNITY POST UPLOAD WITH CONTENT VALIDATION
  // ==========================================================================

  Future<void> uploadCommunityPost(
    String title,
    String description,
    String channelName,
    String channelId,
    String channelImage,
    List<String> tags,
  ) async {
    if (isCommunityPostUploading.value) {
      Get.snackbar(
        "Please wait",
        "A community post is already being published.",
      );
      return;
    }

    // Check Moderation Status
    /* Images are now approved by default for smoother creation
    if (finalstatus.value == "REJECTED" || finalstatus.value == "FLAGGED") {
      Get.snackbar(
        "Moderation Blocked",
        "Your community post image was rejected. Please upload a compliant image.",
      );
      return;
    }
    if (finalstatus.value == "PENDING") {
      Get.snackbar("Processing", "Image is still being verified. Please wait.");
      return;
    }
    */
    if (pickedCommunityImage.value == null) {
      Get.snackbar("Error", "Please select an image.");
      return;
    }

    if (communityImageUrl.value.isEmpty) {
      Get.snackbar("Error", "Image upload not complete.");
      return;
    }

    // CONTENT VALIDATION - Title
    if (title.isEmpty) {
      Get.snackbar("Error", "Title cannot be empty.");
      return;
    }

    if (title.length > maxTitleLength) {
      Get.snackbar("Error", "Title cannot exceed $maxTitleLength characters.");
      return;
    }

    final titleValidation = await validateContent(title, fieldName: 'Title');
    if (!titleValidation.isValid) {
      Get.snackbar("Error", titleValidation.message);
      return;
    }

    // CONTENT VALIDATION - Description
    if (description.isEmpty) {
      Get.snackbar("Error", "Description cannot be empty.");
      return;
    }

    if (description.length > maxDescriptionLength) {
      Get.snackbar(
        "Error",
        "Description cannot exceed $maxDescriptionLength characters.",
      );
      return;
    }

    final descValidation = await validateContent(
      description,
      fieldName: 'Description',
      checkPhoneNumbers: true,
    );
    if (!descValidation.isValid) {
      Get.snackbar("Error", descValidation.message);
      return;
    }

    // CONTENT VALIDATION - Tags
    final validTags = tags.where((t) => t.trim().isNotEmpty).toList();
    if (validTags.isNotEmpty) {
      final tagsValidation = await validateTags(validTags);
      if (!tagsValidation.isValid) {
        Get.snackbar("Error", tagsValidation.message);
        return;
      }
    }

    try {
      // 🔑 REFRESH TOKEN BEFORE COMMUNITY POST
      debugPrint('🔐 Refreshing token before community post...');
      final authValid = await _verifyAuthentication();
      if (!authValid) {
        throw Exception(
          "Authentication failed before uploading community post",
        );
      }

      isUploading.value = true;
      isCommunityPostUploading.value = true;
      DocumentReference docRef = _firestore.collection('Community').doc();
      debugPrint("Attempting to publish community post with ID: ${docRef.id}");

      Map<String, dynamic> data = {
        'id': docRef.id,
        'title': title.trim(),
        'description': description.trim(),
        'images': [communityImageUrl.value],
        'image': communityImageUrl.value,
        'likes': 0,
        'likedby': [],
        'dislikes': 0,
        'dislikedby': [],
        'dislikeCount': 0,
        'commentCount': 0,
        'views': 0,
        'shares': [],
        'downloads': 0,
        'uploadedAt': Timestamp.now(),
        'ownerId': FirebaseAuth.instance.currentUser!.uid,
        'channelName': channelName.trim(),
        'channelId': channelId.trim(),
        'channelImage': channelImage,
        'selectedCategory': selectedCategory.value,
        'tags': validTags,
        'processed': false,
        'visibility': selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
      };

      if (isScheduled.value) {
        data['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      await docRef.set(data);
      debugPrint("Community post published successfully!");

      Get.snackbar("Success", "Community Post uploaded successfully!");
      uploadProgress.value = 0.0;
      _resetUploads();
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException: ${e.code} - ${e.message}');
      String errorMessage = "Failed to upload community post: ";
      if (e.code == 'permission-denied' ||
          e.message?.contains('not authorized') == true) {
        errorMessage += "Authentication failed. Please log in again.";
      } else {
        errorMessage += e.message ?? e.code;
      }
      Get.snackbar("Upload Failed", errorMessage);
    } catch (e) {
      debugPrint("CRITICAL: Failed to publish community post: $e");
      Get.snackbar(
        "Upload Failed",
        "Failed to publish post: ${e.toString()}",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isUploading.value = false;
      isCommunityPostUploading.value = false;
    }
  }

  void _resetUploads() {
    videoUrl.value = '';
    thumbnailUrl.value = '';
    communityImageUrl.value = '';
    communityImageStatus.value = '';
    communityImageStatusReason.value = '';
    videoUploadProgress.value = 0.0;
    imageUploadProgress.value = 0.0;
    uploadProgress.value = 0.0;
    isCommunityPostUploading.value = false;
    _videoUploadTask = null;
    _currentUploadTaskVideo = null;
    _currentUploadTaskCommunity = null;
    _communityImageModerationSubscription?.cancel();
    _communityImageModerationSubscription = null;
    _thumbnailModerationSubscription?.cancel();
    _thumbnailModerationSubscription = null;
    pickedVideo.value = null;
    pickedImage.value = null;
    pickedCommunityImage.value = null;
    videoPlayerController?.dispose();
    videoPlayerController = null;
    selectedPlaylist.value = '';
    selectedTopicId.value = '';
    newTopicData.clear();
    isScheduled.value = false;
    _currentVideoId = null;
  }

  Future<void> fetchAvailableTopics() async {
    isTopicsLoading.value = true;
    topicsError.value = '';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        isTopicsLoading.value = false;
        return;
      }
      
      final snap = await _firestore.collection('topics')
          .where('status', isNotEqualTo: 'deletion_pending')
          .get();
          
      final List<Topic> fetched = [];
      for (var doc in snap.docs) {
        try {
          final t = Topic.fromDocumentSnapshot(doc);
          if (t.visibilityType == TopicVisibilityType.public ||
              t.creatorId == user.uid ||
              (selectedChannel.value != null && t.channelId == selectedChannel.value!.id)) {
            fetched.add(t);
          }
        } catch (e) {
          debugPrint('Error parsing topic doc: $e');
        }
      }
      
      availableTopics.value = fetched;
      debugPrint('Fetched ${availableTopics.length} available topics for upload screen');
    } catch (e) {
      debugPrint('Error fetching topics: $e');
      topicsError.value = e.toString();
    } finally {
      isTopicsLoading.value = false;
    }
  }

  void selectTopic(String id) {
    selectedTopicId.value = id;
  }

  Future<bool> unlockPrivateTopic(String slug, String passcode) async {
    try {
      final query = await _firestore
          .collection('topics')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();
          
      if (query.docs.isEmpty) {
        Get.snackbar(
          "Error",
          "Topic not found with slug: $slug",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
      
      final topicDoc = query.docs.first;
      final topic = Topic.fromDocumentSnapshot(topicDoc);
      
      if (topic.visibilityType == TopicVisibilityType.private) {
        if (topic.accessCode != passcode) {
          Get.snackbar(
            "Error",
            "Incorrect passcode for private topic",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return false;
        }
      }
      
      if (!availableTopics.any((t) => t.slug == topic.slug)) {
        availableTopics.add(topic);
      }
      selectedTopicId.value = topic.slug;
      Get.snackbar(
        "Success",
        "Successfully unlocked private topic: ${topic.title}",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to unlock topic: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<String?> uploadTopicCustomThumbnail(Uint8List bytes, String fileName) async {
    try {
      await _ensureStorageAuthReady();
      final ref = FirebaseStorage.instance.ref().child('thumbnails/topics/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded': DateTime.now().toString()},
      );
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading topic custom thumbnail: $e');
      return null;
    }
  }
}

// ==========================================================================
// CONTENT VALIDATION RESULT CLASS
// ==========================================================================

// ContentValidationResult is now provided by content_validation_mixin.dart

// ==========================================================================
// VIDEO REPOSITORY WITH REPORT SYSTEM
// ==========================================================================

class VideoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int reportThresholdToBlock = 5;

  // Multi-layer profanity filtering for reports
  final ProfanityFilter _profanityFilter = ProfanityFilter();
  late final BadWordFilter _multiLangFilter;

  VideoRepository() {
    _initializeFilters();
  }

  void _initializeFilters() {
    _multiLangFilter = BadWordFilter(
      languages: ['en', 'fa', 'ar', 'tr', 'de', 'fr', 'es', 'ru'],
      includeSensitiveTopics: true,
      matchInsideWords: true,
      censorCharacter: '*',
      caseSensitive: false,
    );
  }

  /// Validate report details for inappropriate content
  Future<ContentValidationResult> validateReportDetails(String details) async {
    if (details.trim().isEmpty) {
      return ContentValidationResult(isValid: true, message: 'Valid');
    }

    // Check for profanity in report details
    if (_profanityFilter.hasProfanity(details)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate language.',
      );
    }

    String filteredText = _multiLangFilter.filterText(details);
    if (filteredText != details) {
      return ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate content.',
      );
    }

    bool containsBadWord = await SafeTextFilter.containsBadWord(
      text: details,
      extraWords: ['xxx', 'nsfw', 'porn', 'sex', 'nude'],
    );

    if (containsBadWord) {
      return ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate language.',
      );
    }

    return ContentValidationResult(isValid: true, message: 'Valid');
  }

  Future<void> addReport({
    required String videoId,
    required String reporterId,
    required String reportType,
    String? details,
  }) async {
    // Validate report details if provided
    if (details != null && details.trim().isNotEmpty) {
      final validation = await validateReportDetails(details);
      if (!validation.isValid) {
        throw Exception(validation.message);
      }
    }

    final videoRef = _firestore.collection('videos').doc(videoId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(videoRef);

        if (!snapshot.exists) {
          throw Exception("Video not found.");
        }

        final videoData = snapshot.data()!;
        List<dynamic> reports = videoData['reports'] ?? [];
        int reportCount = (videoData['reportCount'] as num?)?.toInt() ?? 0;

        bool isUpdated = false;

        // Check for existing report from the same reporter
        for (int i = 0; i < reports.length; i++) {
          final report = reports[i] as Map<String, dynamic>?;
          if (report != null && report['reporterId'] == reporterId) {
            reports[i] = {
              'reporterId': reporterId,
              'reportType': reportType,
              'details': details?.trim(),
              'uploadedAt': Timestamp.now(),
            };
            isUpdated = true;
            break;
          }
        }

        if (!isUpdated) {
          reports.add({
            'reporterId': reporterId,
            'reportType': reportType,
            'details': details?.trim(),
            'uploadedAt': Timestamp.now(),
          });
          reportCount++;
        }

        final shouldBlock = reportCount >= reportThresholdToBlock;

        transaction.update(videoRef, {
          'reports': reports,
          'reportCount': reportCount,
          'isBlocked': shouldBlock,
        });
      });
    } catch (e) {
      rethrow;
    }
  }
}





