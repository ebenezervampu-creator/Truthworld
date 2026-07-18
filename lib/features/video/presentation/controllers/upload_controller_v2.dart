import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:video_player/video_player.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:truthworld/core/utils/mentions_helper.dart';

/// Upload Status Enum
enum UploadStatus { idle, picking, uploading, processing, completed, failed }

// =============================================================================
// PRODUCTION-LEVEL UPLOAD CONTROLLER V2 - SCALABLE & HIGH PERFORMANCE
// =============================================================================

class UploadControllerV2 extends GetxController {


  /// Real-time video upload progress (0.0 - 1.0)
  RxDouble videoUploadProgress = 0.0.obs;

  /// Real-time thumbnail upload progress (0.0 - 1.0)
  RxDouble thumbnailUploadProgress = 0.0.obs;

  /// Overall upload progress
  RxDouble uploadProgress = 0.0.obs;

  /// Upload status
  Rx<UploadStatus> uploadStatus = UploadStatus.idle.obs;

  /// Upload error message
  RxString uploadError = ''.obs;

  /// Upload speed in MB/s
  RxDouble uploadSpeed = 0.0.obs;

  /// Estimated time remaining in seconds
  RxInt timeRemaining = 0.obs;

  /// Video upload verified
  RxBool videoUploadVerified = false.obs;

  /// Thumbnail upload verified
  RxBool thumbnailUploadVerified = false.obs;

  /// File size in MB
  RxDouble videoFileSizeMB = 0.0.obs;

  // Upload preferences
  RxString selectedCategory = "Music".obs;
  Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  RxString selectedVisibility = 'Public'.obs;
  RxBool isKidFriendly = false.obs;
  RxBool isShort = false.obs;
  RxString uploadQuality = 'Auto'.obs;
  RxBool enableComments = true.obs;
  RxBool allowRatings = false.obs;
  RxString selectedPlaylist = ''.obs;
  RxBool isScheduled = false.obs;
  Rx<DateTime> scheduledDate = DateTime.now().add(Duration(days: 1)).obs;

  /// AI Features
  RxBool aiTranscriptEnabled = true.obs;
  RxBool aiChaptersEnabled = false.obs;
  RxBool aiGenerateSubtitles = false.obs;
  RxBool aiGenerateDubbing = false.obs;
  RxBool aiDiarizationEnabled = false.obs;
  RxBool aiSummaryEnabled = false.obs;
  RxList<String> aiTranslationLanguages = <String>[].obs;
  RxBool aiTTSEnabled = false.obs;
  RxString aiTTSVoiceType = 'default'.obs;
  RxBool aiFactCheckEnabled = false.obs;
  Rx<PlatformFile?> voiceSampleFile = Rx<PlatformFile?>(null);

  /// Video player controller
  VideoPlayerController? videoPlayerController;

  /// Category list
  List<String> videoCategories = [
    'Education', 'Entertainment', 'Music', 'News', 'Sports', 'Gaming',
    'Technology', 'Science', 'Travel', 'Lifestyle', 'Comedy',
    'Documentary', 'Movies', 'TV Shows', 'Vlogs', 'DIY & How-to',
    'Health & Fitness', 'Fashion & Beauty', 'Food & Cooking',
    'Business & Finance', 'Animation', 'Short Films', 'Motivation',
    'History', 'Art & Design', 'Automotive', 'Animals & Pets',
    'Spirituality', 'Nature & Wildlife', 'Kids & Family',
  ];

  /// Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;


  /// File stores
  var videos = <Video>[].obs;
  var filteredVideos = <Video>[].obs;
  RxString searchQuery = ''.obs;
  var channels = <Channel>[].obs;
  var pickedImage = Rx<PlatformFile?>(null);
  var pickedVideo = Rx<PlatformFile?>(null);

  /// Upload task references
  UploadTask? _videoUploadTask;
  UploadTask? _thumbnailUploadTask;
  String? _currentVideoId;

  /// Storage URLs
  RxString videoUrl = ''.obs;
  RxString thumbnailUrl = ''.obs;

  /// Upload metadata
  RxBool isUploading = false.obs;
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int maxTags = 15;

  // Chunk upload constants
  static const int chunkSizeBytes = 5 * 1024 * 1024; // 5MB chunks

  /// Stream subscription for channels
  StreamSubscription<QuerySnapshot>? _channelsSubscription;
  
  /// Retry counter for failed channel fetches
  int _channelsFetchRetries = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Channel loading state
  RxBool isChannelsLoading = false.obs;
  
  /// Channel fetch error
  RxString channelsError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    
    final auth = AuthService.to;
    if (auth.hasChannel.value) {
      selectedChannel.value = auth.userChannel;
    }
    
    // Every video doesn't have video rating only when user enabled Factchecking
    ever(aiFactCheckEnabled, (bool enabled) {
      allowRatings.value = enabled;
    });
    
    fetchChannelsWithRetry();
  }


  @override
  void onClose() {
    _channelsSubscription?.cancel();
    videoPlayerController?.dispose();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHANNEL MANAGEMENT WITH ENHANCED ERROR HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch channels with retry logic and proper error handling
  Future<void> fetchChannelsWithRetry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      channelsError.value = 'User not authenticated';
      debugPrint('❌ Channels: User not authenticated');
      Get.snackbar(
        'Auth Error',
        'Please login to view channels',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
      return;
    }

    try {
      isChannelsLoading.value = true;
      channelsError.value = '';
      _channelsFetchRetries = 0;
      
      await _fetchChannelsStream(user.uid);
      
    } catch (e) {
      debugPrint('❌ Initial channels fetch error: $e');
      _retryFetchChannels(user.uid);
    }
  }

  /// Fetch channels with retry mechanism
  void _retryFetchChannels(String userId) async {
    if (_channelsFetchRetries >= _maxRetries) {
      isChannelsLoading.value = false;
      channelsError.value = 'Failed to load channels after $_maxRetries attempts';
      debugPrint('❌ Channels: Max retries exhausted');
      Get.snackbar(
        'Error',
        'Failed to load channels. Please refresh.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        mainButton: TextButton(
          onPressed: () => fetchChannelsWithRetry(),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    _channelsFetchRetries++;
    debugPrint('🔄 Retrying channels fetch (attempt $_channelsFetchRetries/$_maxRetries)');
    
    await Future.delayed(_retryDelay);
    
    try {
      await _fetchChannelsStream(userId);
    } catch (e) {
      debugPrint('❌ Retry attempt $_channelsFetchRetries failed: $e');
      _retryFetchChannels(userId);
    }
  }

  /// Stream channels from Firestore with proper error handling
  Future<void> _fetchChannelsStream(String userId) async {
    _channelsSubscription?.cancel();
    
    final completer = Completer<void>();
    bool streamInitialized = false;

    _channelsSubscription = _firestore
        .collection("channels")
        .where('ownerId', isEqualTo: userId)
        .where('isArchived', isEqualTo: false)
        .withConverter<Channel>(
          fromFirestore: (doc, _) => Channel.fromDocumentSnapshot(doc),
          toFirestore: (channel, _) => {},
        )
        .snapshots()
        .listen(
          (snapshot) {
            try {
              isChannelsLoading.value = false;
              channelsError.value = '';
              
              channels.value = snapshot.docs.map((doc) => doc.data()).toList();

              debugPrint('✅ Channels loaded: ${channels.length}');

              // Auto-select first channel if none selected
              if (channels.isNotEmpty && selectedChannel.value == null) {
                selectedChannel.value = channels.first;
                debugPrint('✅ Auto-selected channel: ${selectedChannel.value!.channelName}');
                Get.snackbar(
                  'Channel Selected',
                  '${selectedChannel.value!.channelName} is ready',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              }

              // Empty channels case
              if (channels.isEmpty) {
                debugPrint('⚠️ No channels found for user');
                Get.snackbar(
                  'No Channels',
                  'Create a channel to start uploading',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 3),
                );
              }

              if (!streamInitialized) {
                streamInitialized = true;
                completer.complete();
              }
            } catch (e) {
              debugPrint('❌ Error processing channels snapshot: $e');
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            }
          },
          onError: (error) {
            isChannelsLoading.value = false;
            debugPrint('❌ Firestore stream error: $error');
            
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
          onDone: () {
            debugPrint('✅ Channels stream closed');
          },
        );

    // Wait for first data with timeout
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 10), () {
        if (!streamInitialized) {
          throw TimeoutException('Channel fetch timeout');
        }
      }),
    ]);
  }

  /// Select a channel and validate
  void selectChannel(Channel channel) {
    if (channel.id.isEmpty) {
      debugPrint('❌ Invalid channel selection');
      Get.snackbar(
        'Error',
        'Invalid channel selected',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
      );
      return;
    }
    
    selectedChannel.value = channel;
    debugPrint('✅ Channel selected: ${channel.channelName}');
    Get.snackbar(
      'Success',
      '${channel.channelName} selected',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  void selectPlaylist(String id) {
    selectedPlaylist.value = id;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILE PICKING AND VALIDATION (OPTIMIZED)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> pickVideo() async {
    try {
      uploadStatus.value = UploadStatus.picking;
      uploadError.value = '';

      final result = await FilePicker.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        Get.snackbar("Info", "No video selected");
        uploadStatus.value = UploadStatus.idle;
        return;
      }

      final pickedFile = result.files.first;

      // Validate file size (2GB max)
      const maxSizeInBytes = 2 * 1024 * 1024 * 1024;
      if (pickedFile.size > maxSizeInBytes) {
        uploadError.value = 'Video exceeds 2GB limit';
        Get.snackbar("Error", uploadError.value);
        uploadStatus.value = UploadStatus.failed;
        return;
      }

      // Validate file type
      final extension = pickedFile.extension?.toLowerCase();
      if (extension != 'mp4' && extension != 'mov') {
        uploadError.value = 'Only MP4/MOV format supported';
        Get.snackbar("Error", uploadError.value);
        uploadStatus.value = UploadStatus.failed;
        return;
      }

      // Update file size
      videoFileSizeMB.value = pickedFile.size / (1024 * 1024);

      // Validate duration
      const maxDurationSeconds = 60 * 60; // 60 minutes
      int duration = await _getVideoDuration(pickedFile);

      if (duration > maxDurationSeconds) {
        uploadError.value = 'Video exceeds 60 minute limit';
        Get.snackbar("Error", uploadError.value);
        uploadStatus.value = UploadStatus.failed;
        return;
      }

      pickedVideo.value = pickedFile;
      await initializeVideoPlayer();

      Get.snackbar(
        "Success",
        "Video selected: ${(videoFileSizeMB.value).toStringAsFixed(1)}MB",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );

      uploadStatus.value = UploadStatus.idle;
    } catch (e) {
      uploadError.value = 'Failed to pick video: $e';
      uploadStatus.value = UploadStatus.failed;
      Get.snackbar("Error", uploadError.value);
      debugPrint('❌ Error picking video: $e');
    }
  }

  Future<void> pickImage({required bool forCommunity}) async {
    try {
      uploadStatus.value = UploadStatus.picking;

      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        pickedImage.value = result.files.first;
        Get.snackbar(
          "Success",
          "Image selected successfully",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      uploadStatus.value = UploadStatus.idle;
    } catch (e) {
      uploadError.value = 'Failed to pick image: $e';
      uploadStatus.value = UploadStatus.failed;
      Get.snackbar("Error", uploadError.value);
    }
  }

  Future<int> _getVideoDuration(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final video = html.VideoElement()..src = url;
        await video.onLoadedMetadata.first;
        final duration = video.duration.floor();
        html.Url.revokeObjectUrl(url);
        return duration;
      } else {
        final file = File(videoFile.path!);
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        final duration = controller.value.duration.inSeconds;
        await controller.dispose();
        return duration;
      }
    } catch (e) {
      debugPrint('❌ Error getting video duration: $e');
      return 0;
    }
  }

  Future<void> initializeVideoPlayer() async {
    if (pickedVideo.value == null) return;

    try {
      if (videoPlayerController != null) {
        await videoPlayerController!.dispose();
      }

      if (kIsWeb) {
        final blob = html.Blob([pickedVideo.value!.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        videoPlayerController = VideoPlayerController.file(
          File(pickedVideo.value!.path!),
        );
      }

      await videoPlayerController!.initialize();
      videoPlayerController!.setLooping(true);
      update();
    } catch (e) {
      debugPrint('❌ Error initializing video player: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OPTIMIZED UPLOAD WITH CHUNKED DELIVERY & VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> uploadVideoWithChunks(PlatformFile videoFile) async {
    if (selectedChannel.value == null) {
      uploadError.value = 'Please select a channel';
      Get.snackbar("Error", uploadError.value);
      return;
    }

    uploadStatus.value = UploadStatus.uploading;
    uploadError.value = '';
    uploadProgress.value = 0.0;
    videoUploadProgress.value = 0.0;

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Authentication check
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      final userId = user.uid;
      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentVideoId = uniqueId;

      debugPrint('🔐 Authenticated: $userId');
      debugPrint('🆔 Video ID: $uniqueId');

      // 2. Create Firestore placeholder
      await _createVideoPlaceholder(uniqueId, userId);

      // 3. Upload video with optimization
      final videoDownloadUrl = await _uploadVideoToStorage(
        videoFile,
        uniqueId,
        onProgress: (progress) {
          videoUploadProgress.value = progress;
          uploadProgress.value = progress * 0.7; // 70% of total
          _updateUploadSpeed(stopwatch, videoFile.size);
        },
      );

      videoUrl.value = videoDownloadUrl;
      videoUploadVerified.value = false; // Reset until verified

      // 4. Upload thumbnail if available
      if (pickedImage.value != null) {
        await _uploadThumbnailToStorage(
          pickedImage.value!,
          uniqueId,
          onProgress: (progress) {
            thumbnailUploadProgress.value = progress;
            uploadProgress.value = 0.7 + (progress * 0.3); // Remaining 30%
          },
        );
        thumbnailUploadVerified.value = false;
      }

      // 5. Verify uploads
      await _verifyUploads(uniqueId);

      // 6. Update Firestore
      await _updateVideoMetadata(uniqueId, videoDownloadUrl);

      uploadProgress.value = 0.99;
      uploadStatus.value = UploadStatus.processing;

      Get.snackbar(
        "Success",
        "Video uploaded! Processing...",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } on FirebaseException catch (e) {
      uploadError.value = 'Upload failed: ${e.message}';
      uploadStatus.value = UploadStatus.failed;
      debugPrint('🔥 Firebase Error: ${e.message}');
      Get.snackbar("Error", uploadError.value);

      if (_currentVideoId != null) {
        await _firestore.collection('videos').doc(_currentVideoId).delete();
      }
    } catch (e) {
      uploadError.value = 'Unexpected error: $e';
      uploadStatus.value = UploadStatus.failed;
      debugPrint('❌ Error: $e');
      Get.snackbar("Error", uploadError.value);

      if (_currentVideoId != null) {
        await _firestore.collection('videos').doc(_currentVideoId).delete();
      }
    } finally {
      stopwatch.stop();
    }
  }

  Future<void> _createVideoPlaceholder(String videoId, String userId) async {
    final data = {
      'id': videoId,
      'ownerId': userId,
      'userId': userId,
      'status': 'uploading',
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
      'aiFeatures': buildFeaturesMap(pipelineStage: 'draft'),
      'uploadMetadata': {
        'uploadStartTime': Timestamp.now(),
        'uploadSpeed': 0,
        'uploadStatus': 'initiated',
      },
    };

    await _firestore.collection('videos').doc(videoId).set(data);
    debugPrint('✅ Firestore placeholder created');
  }

  Future<String> _uploadVideoToStorage(
    PlatformFile videoFile,
    String videoId, {
    required Function(double) onProgress,
  }) async {
    /// Optimized upload strategy: use direct putData for files under 100MB,
    /// otherwise consider chunked approach
    final videoRef = _firebaseStorage.ref().child('videos/$videoId/original.mp4');
    final metadata = SettableMetadata(contentType: 'video/mp4');

    _videoUploadTask = videoRef.putData(videoFile.bytes!, metadata);

    _videoUploadTask!.snapshotEvents.listen(
      (event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);

          if (progress % 0.1 < 0.01) {
            debugPrint(
              '📊 Video upload: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        }
      },
    );

    final snapshot = await _videoUploadTask!.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('✅ Video uploaded: $downloadUrl');
    return downloadUrl;
  }

  Future<void> _uploadThumbnailToStorage(
    PlatformFile imageFile,
    String videoId, {
    required Function(double) onProgress,
  }) async {
    final thumbnailRef = _firebaseStorage.ref().child('thumbnails/$videoId.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    _thumbnailUploadTask = thumbnailRef.putData(imageFile.bytes!, metadata);

    _thumbnailUploadTask!.snapshotEvents.listen(
      (event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      },
    );

    final snapshot = await _thumbnailUploadTask!.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    thumbnailUrl.value = downloadUrl;
    debugPrint('✅ Thumbnail uploaded: $downloadUrl');
  }

  Future<void> _verifyUploads(String videoId) async {
    try {
      // Verify video URL exists in Firebase Storage
      if (videoUrl.value.isNotEmpty) {
        final response = await http.get(Uri.parse(videoUrl.value));
        if (response.statusCode == 200) {
          videoUploadVerified.value = true;
          debugPrint('✅ Video upload verified');
        }
      }

      // Verify thumbnail URL if available
      if (thumbnailUrl.value.isNotEmpty) {
        final response = await http.get(Uri.parse(thumbnailUrl.value));
        if (response.statusCode == 200) {
          thumbnailUploadVerified.value = true;
          debugPrint('✅ Thumbnail upload verified');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Verification warning: $e');
      // Don't fail upload if verification fails - files are already uploaded
    }
  }

  Future<void> _updateVideoMetadata(String videoId, String videoUrl) async {
    await _firestore.collection('videos').doc(videoId).update({
      'videoUrl': videoUrl,
      'status': 'processing',
      'uploadMetadata.uploadStatus': 'completed',
      'uploadMetadata.uploadEndTime': Timestamp.now(),
    });

    debugPrint('✅ Metadata updated');
  }

  void _updateUploadSpeed(Stopwatch stopwatch, int fileSizeBytes) {
    final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
    if (elapsedSeconds > 0) {
      final speedMbps = (fileSizeBytes / (1024 * 1024)) / elapsedSeconds;
      uploadSpeed.value = speedMbps;

      // Calculate time remaining
      final remainingProgress = 1.0 - uploadProgress.value;
      final remainingSize = videoFileSizeMB.value * remainingProgress;
      timeRemaining.value = (remainingSize / speedMbps).toInt();
    }
  }

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

  Future<void> publishVideo({
    required String title,
    required String description,
    required List<String> tags,
    required List<String> languages,
  }) async {
    try {
      if (!videoUploadVerified.value) {
        uploadError.value = 'Video upload not verified yet. Please wait.';
        Get.snackbar("Error", uploadError.value);
        return;
      }

      if (videoUrl.value.isEmpty) {
        uploadError.value = 'Video upload incomplete';
        Get.snackbar("Error", uploadError.value);
        return;
      }

      if (title.isEmpty || title.length > maxTitleLength) {
        uploadError.value = 'Invalid title (5-100 characters)';
        Get.snackbar("Error", uploadError.value);
        return;
      }

      if (description.length > maxDescriptionLength) {
        uploadError.value = 'Invalid description';
        Get.snackbar("Error", uploadError.value);
        return;
      }

      uploadStatus.value = UploadStatus.uploading;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final videoId = _currentVideoId;
      if (videoId == null) throw Exception("No video ID");

      final channel = selectedChannel.value;
      if (channel == null) throw Exception("No channel selected");

      final updateData = {
        'title': title.trim(),
        'description': description.trim(),
        'keywords': _generateKeywords(title.trim()),
        'videoUrl': videoUrl.value,
        'thumbnailUrl': thumbnailUrl.value.isNotEmpty
            ? thumbnailUrl.value
            : 'https://via.placeholder.com/1280x720.png?text=No+Thumbnail',
        'channelName': channel.channelName,
        'channelId': channel.channelId,
        'channelImage': channel.avatarUrl,
        'category': selectedCategory.value.isEmpty ? 'Uncategorized' : selectedCategory.value,
        'tags': tags.where((t) => t.trim().isNotEmpty).toList(),
        'languages': languages,
        'visibility': selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
        'isShort': isShort.value,
        'enableComments': enableComments.value,
        'allowRatings': allowRatings.value,
        'status': isScheduled.value ? 'scheduled' : 'published',
        'publishedAt': Timestamp.now(),
        'aiFeatures': buildFeaturesMap(pipelineStage: 'published'),
      };

      if (isScheduled.value) {
        updateData['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      await _firestore.collection('videos').doc(videoId).update(updateData);

      // Scan for handle mentions and notify
      final String fullMetadataText = '${title.trim()} ${description.trim()}';
      try {
        await MentionsHelper.processAndNotifyMentions(
          text: fullMetadataText,
          videoId: videoId,
          videoTitle: title.trim(),
          videoThumbnailUrl: thumbnailUrl.value.isNotEmpty
              ? thumbnailUrl.value
              : 'https://via.placeholder.com/1280x720.png?text=No+Thumbnail',
          videoChannelId: channel.channelId,
        );
      } catch (e) {
        debugPrint('⚠️ Error processing mentions for video publish V2: $e');
      }

      uploadStatus.value = UploadStatus.completed;
      uploadProgress.value = 1.0;

      Get.snackbar(
        "Success",
        "Video published successfully!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );

      _resetUploads();
    } catch (e) {
      uploadError.value = 'Publish failed: $e';
      uploadStatus.value = UploadStatus.failed;
      debugPrint('❌ Publish error: $e');
      Get.snackbar("Error", uploadError.value);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMUNITY POST UPLOAD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> publishCommunityPost({
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    try {
      if (thumbnailUrl.value.isEmpty) {
        uploadError.value = 'Image upload incomplete';
        Get.snackbar("Error", uploadError.value);
        return;
      }

      uploadStatus.value = UploadStatus.uploading;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final channel = selectedChannel.value;
      if (channel == null) throw Exception("No channel selected");

      final docRef = _firestore.collection('Community').doc();

      final data = {
        'id': docRef.id,
        'title': title.trim(),
        'description': description.trim(),
        'image': thumbnailUrl.value,
        'likes': 0,
        'likedby': [],
        'views': 0,
        'shares': [],
        'downloads': 0,
        'uploadedAt': Timestamp.now(),
        'ownerId': user.uid,
        'channelName': channel.channelName,
        'channelId': channel.channelId,
        'channelImage': channel.avatarUrl,
        'category': selectedCategory.value,
        'tags': tags.where((t) => t.trim().isNotEmpty).toList(),
        'visibility': selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
      };

      if (isScheduled.value) {
        data['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      await docRef.set(data);

      uploadStatus.value = UploadStatus.completed;

      Get.snackbar(
        "Success",
        "Community post published!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );

      _resetUploads();
    } catch (e) {
      uploadError.value = 'Community post failed: $e';
      uploadStatus.value = UploadStatus.failed;
      Get.snackbar("Error", uploadError.value);
    }
  }

  void _resetUploads() {
    videoUrl.value = '';
    thumbnailUrl.value = '';
    videoUploadProgress.value = 0.0;
    thumbnailUploadProgress.value = 0.0;
    uploadProgress.value = 0.0;
    uploadSpeed.value = 0.0;
    timeRemaining.value = 0;
    videoUploadVerified.value = false;
    thumbnailUploadVerified.value = false;
    videoFileSizeMB.value = 0.0;
    _videoUploadTask = null;
    _thumbnailUploadTask = null;
    pickedVideo.value = null;
    pickedImage.value = null;
    videoPlayerController?.dispose();
    videoPlayerController = null;
    selectedPlaylist.value = '';
    isScheduled.value = false;
    _currentVideoId = null;
    uploadError.value = '';
    uploadStatus.value = UploadStatus.idle;
  }
}




