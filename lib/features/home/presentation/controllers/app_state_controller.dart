import 'dart:async';
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:idb_shim/idb_browser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart'
    as app_exceptions;
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:universal_html/html.dart' as html;

// ========================================================================
// EXTENSION: Stream Retry Logic
// ========================================================================

// ========================================================================
// MAIN CONTROLLER
// ========================================================================

/// Main controller managing video operations, comments, interactions, and content discovery

class AppStateController extends BaseController {

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  FirebaseFirestore get _firestore => firestore;
  final FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseAuth get _auth => auth;
  final FlutterVideoInfo videoInfo = FlutterVideoInfo();


  final pickedImage = Rx<PlatformFile?>(null);
  final pickedVideo = Rx<PlatformFile?>(null);


  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> filteredVideos = <Video>[].obs;
  final RxString searchQuery = ''.obs;

  StreamSubscription<List<Video>>? _videoSubscription;


  static const String _videosCollection = 'videos';
    
  String get userId => _auth.currentUser?.uid ?? '';
  int get filteredVideoCount => filteredVideos.length;
  int get totalVideoCount => videos.length;
  bool get isImagePicked => pickedImage.value != null;
  bool get isVideoPicked => pickedVideo.value != null;
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const Duration _filePickerTimeout = Duration(seconds: 30);


  @override
  void onInit() {
    super.onInit();
    _initializeVideoStream();
  }




  /// Initialize video stream with retry logic
  void _initializeVideoStream() {
    _videoSubscription?.cancel();

    _videoSubscription = streamVideos().listen(
      _handleVideoSnapshot,
      onError: _handleVideoStreamError,
    );
    trackSubscription(_videoSubscription!);
  }

  /// Handle incoming video snapshot
  void _handleVideoSnapshot(List<Video> videoList) {
    videos.assignAll(videoList);
    filteredVideos.assignAll(videoList);
    clearError();

  }

  /// Filter videos by search query
  void filterVideos(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredVideos.assignAll(videos);
    } else {
      final lowerQuery = query.toLowerCase();
      filteredVideos.assignAll(
        videos.where((video) {
          return video.title.toLowerCase().contains(lowerQuery) ||
              video.description.toLowerCase().contains(lowerQuery) ||
              video.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList(),
      );
    }

    if (kDebugMode) {
      debugPrint(
        'MainController: Filtered to ${filteredVideos.length} videos for query "$query"',
      );
    }
  }

  /// Handle video stream errors
  void _handleVideoStreamError(dynamic error) {
    if (kDebugMode) {
      debugPrint('MainController video stream error: $error');
    }

    handleError(
      app_exceptions.FirestoreException(
        message: 'Failed to load videos. Please check your connection.',
        originalException: error,
      ),
    );
  }

  /// Stream of videos from Firestore with error handling
  Stream<List<Video>> streamVideos() {
    return _firestore
        .collection(_videosCollection)
        .orderBy('uploadedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error mapping videos: $e');
            }
            return <Video>[];
          }
        })
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('Error in video stream: $error');
          }
          return <Video>[];
        });
  }

  /// Restart video stream (useful for manual refresh)
  Future<void> restartVideoStream() async {
    try {
      await _videoSubscription?.cancel();
      _initializeVideoStream();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error restarting video stream: $e');
      }
    }
  }


  /// Pick image file from device
  Future<void> pickImage() async {
    await safeExecute(_pickImageInternal, showLoading: false);
  }

  /// Internal image picking implementation
  Future<void> _pickImageInternal() async {
    try {
      final result =
          await FilePicker.pickFiles(
            type: FileType.image,
            withData: kIsWeb,
          ).timeout(
            _filePickerTimeout,
            onTimeout: () => throw const app_exceptions.TimeoutException(
              message: 'Image picker timeout',
            ),
          );

      if (result != null && result.files.isNotEmpty) {
        pickedImage.value = result.files.first;
        showSuccess('Image selected successfully');

        if (kDebugMode) {
          debugPrint(
            'MainController: Image picked - ${result.files.first.name}',
          );
        }
      } else {
        showWarning('No image selected');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error picking image: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to pick image',
        originalException: e,
      );
    }
  }

  /// Pick video file from device
  Future<void> pickVideo() async {
    await safeExecute(_pickVideoInternal, showLoading: false);
  }

  /// Internal video picking implementation
  Future<void> _pickVideoInternal() async {
    try {
      final result =
          await FilePicker.pickFiles(
            type: FileType.video,
            withData: kIsWeb,
          ).timeout(
            _filePickerTimeout,
            onTimeout: () => throw const app_exceptions.TimeoutException(
              message: 'Video picker timeout',
            ),
          );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        pickedVideo.value = file;

        final hasData = kIsWeb
            ? file.bytes != null
            : (file.path != null && file.path!.isNotEmpty);

        if (hasData) {
          showSuccess('Video selected successfully');

          if (kDebugMode) {
            debugPrint(
              'MainController: Video picked - ${file.name}',
            );
          }
        } else {
          throw const app_exceptions.ValidationException(
            message: 'Failed to load video file',
          );
        }
      } else {
        showWarning('No video selected');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error picking video: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to pick video',
        originalException: e,
      );
    }
  }


  /// Download video to device
  Future<void> downloadVideoToDevice(Uint8List bytes, String fileName) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'video/mp4');
        final url = html.Url.createObjectUrlFromBlob(blob);

        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();

        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
      }

      showSuccess('Download completed');

      if (kDebugMode) {
        debugPrint('MainController: Download completed for $fileName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error downloading video: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to download video',
        originalException: e,
      );
    }
  }

  /// Save video for offline viewing
  Future<void> saveOfflineVideo(OfflineVideo video, String videoUrl) async {
    try {
      final response = await http
          .get(Uri.parse(videoUrl))
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw app_exceptions.ValidationException(
          message: 'Failed to download video (HTTP ${response.statusCode})',
        );
      }

      final dbFactory = getIdbFactory();
      if (dbFactory == null) return;
      final db = await dbFactory.open(
        'video_db',
        version: 1,
        onUpgradeNeeded: (e) {
          final db = e.database;
          if (!db.objectStoreNames.contains('videos')) {
            db.createObjectStore('videos');
          }
        },
      );

      final txn = db.transaction('videos', 'readwrite');
      final store = txn.objectStore('videos');

      final data = {'meta': video.toJson(), 'bytes': response.bodyBytes};

      await store.put(data, video.id);
      await txn.completed;

      showSuccess('Video saved for offline viewing');

      if (kDebugMode) {
        debugPrint('MainController: Saved offline video ${video.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving offline video: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to save video offline',
        originalException: e,
      );
    }
  }
}
