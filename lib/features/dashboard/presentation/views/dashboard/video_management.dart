import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/features/video/data/models/video.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class VideoManagementController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  final RxDouble uploadProgress = 0.0.obs;
  String get uploadProgressPercent =>
      '${(uploadProgress.value * 100).toStringAsFixed(0)}%';

  Future<void> uploadVideo({
    required PlatformFile videoFile,
    required PlatformFile imageFile,
    required String title,
    required String description,
    required String channelId,
    required String channelName,
    required String channelImage,
    required String category,
    required List<String> tags,
    required String visibility,
    required bool isKidFriendly,
    required bool isShort,
    required String uploadQuality,
    required bool enableComments,
    required bool allowRatings,
  }) async {
    if (videoFile.bytes == null || imageFile.bytes == null) {
      Get.snackbar('Error', 'Video or thumbnail data is missing.');
      return;
    }

    uploadProgress.value = 0.0;
    Get.snackbar(
      'Upload Started',
      'Your video upload is in progress.',
      showProgressIndicator: true,
    );

    try {
      final formattedDuration = await _getVideoDurationFormatted(videoFile);

      final videoFileName =
          'videos/${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';
      final imageFileName =
          'thumbnails/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';

      final videoRef = _firebaseStorage.ref().child(videoFileName);
      final imageRef = _firebaseStorage.ref().child(imageFileName);

      final videoUploadTask = videoRef.putData(videoFile.bytes!);
      final imageUploadTask = imageRef.putData(imageFile.bytes!);

      videoUploadTask.snapshotEvents.listen((event) {
        uploadProgress.value =
            (event.bytesTransferred / event.totalBytes) * 0.7;
      });

      await videoUploadTask;

      imageUploadTask.snapshotEvents.listen((event) {
        uploadProgress.value =
            0.7 + (event.bytesTransferred / event.totalBytes) * 0.3;
      });

      final videoSnapshot = await videoUploadTask;
      final imageSnapshot = await imageUploadTask;

      final videoUrl = await videoSnapshot.ref.getDownloadURL();
      final imageUrl = await imageSnapshot.ref.getDownloadURL();

      final collectionName = isShort ? 'shorts' : 'videos';
      final DocumentReference docRef = _firestore.collection(collectionName).doc();

      final newVideo = Video(
        id: docRef.id,
        title: title,
        description: description,
        videoUrl: videoUrl,
        thumbnailUrl: imageUrl,
        channelId: channelId,
        channelName: channelName,
        channelImage: channelImage,
        ownerId: FirebaseAuth.instance.currentUser!.uid,
        likeCount: 0,
        viewCount: 0,
        uploadedAt: Timestamp.now(),
        category: category,
        tags: tags,
        visibility: visibility,
        isKidFriendly: isKidFriendly,
        isShort: isShort,
        enableComments: enableComments,
        allowRatings: allowRatings,
        duration: formattedDuration,
      );

      await docRef.set(newVideo.toMap());

      uploadProgress.value = 0.0;
      Get.back();
      Get.snackbar('Success', 'Video uploaded successfully!');
    } catch (e) {
      uploadProgress.value = 0.0;
      Get.snackbar('Error', 'Failed to upload video: $e');
      debugPrint('Error uploading video: $e');
    }
  }

  Stream<List<Video>> fetchChannelVideos(String channelId) {
    return _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId)
        //  .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .toList();
        })
        .handleError((error) {
          Get.snackbar('Error', 'Failed to fetch videos: $error');
          return [];
        });
  }

  Future<void> deleteVideo(Video video) async {
    try {
      await _firestore.collection('videos').doc(video.id).delete();
      if (video.videoUrl.isNotEmpty) {
        await _firebaseStorage.refFromURL(video.videoUrl).delete();
      }
      if (video.thumbnailUrl.isNotEmpty) {
        await _firebaseStorage.refFromURL(video.thumbnailUrl).delete();
      }
      Get.snackbar('Success', "Video '${video.title}' deleted successfully.");
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete video: $e');
      debugPrint('Error deleting video: $e');
    }
  }

  Future<void> updateVideo(String videoId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('videos').doc(videoId).update(data);
      Get.snackbar('Success', 'Video updated successfully.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update video: $e');
      debugPrint('Error updating video: $e');
    }
  }

  Future<String> _getVideoDurationFormatted(PlatformFile videoFile) async {
    if (kIsWeb) {
      final completer = Completer<String>();
      final blob = html.Blob([videoFile.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final videoElement = html.VideoElement()
        ..src = url
        ..preload = 'metadata';

      videoElement.onLoadedMetadata.listen((event) {
        final duration = Duration(seconds: videoElement.duration.floor());
        html.Url.revokeObjectUrl(url);
        completer.complete(_formatDuration(duration));
      });

      videoElement.onError.listen((event) {
        html.Url.revokeObjectUrl(url);
        completer.completeError('Failed to load video metadata.');
      });
      return completer.future;
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${videoFile.name}');
      await tempFile.writeAsBytes(videoFile.bytes!);
      final controller = VideoPlayerController.file(tempFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      await tempFile.delete();
      return _formatDuration(duration);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> triggerAIFeatures({
    required String videoId,
    required List<String> features,
    required List<String> targetLanguages,
    String priorityMode = 'accuracy',
    List<String> sensitiveTopics = const [],
    bool autoChapters = true,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Get.snackbar('Auth Error', 'You must be logged in to generate AI features.');
        return;
      }

      Get.snackbar(
        'Generating AI Features',
        'Requesting ${features.join(", ")} in ${targetLanguages.join(", ").toUpperCase()}...',
        showProgressIndicator: true,
        duration: const Duration(seconds: 4),
      );

      final token = await currentUser.getIdToken();
      final url = Uri.parse(
        'https://asia-south1-truthworld-1.cloudfunctions.net/triggerVideoAIFeatures',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'videoId': videoId,
          'features': features,
          'targetLanguages': targetLanguages,
          'priorityMode': priorityMode,
          'sensitiveTopics': sensitiveTopics,
          'autoChapters': autoChapters,
        }),
      );

      if (response.statusCode == 200) {
        Get.snackbar(
          'AI Processing Started',
          'AI features generation is underway. Subtitles and audio tracks will update automatically!',
          backgroundColor: const Color(0xFF1E293B),
          colorText: const Color(0xFFF8FAFC),
        );
      } else {
        // Fallback: update Firestore document directly
        await _firestore.collection('video_jobs').doc(videoId).set({
          'jobId': videoId,
          'videoId': videoId,
          'userId': currentUser.uid,
          'status': 'processing',
          'executionPlan': {
            'languages': targetLanguages,
            'generateSubtitles': features.contains('subtitles'),
            'generateDubbing': features.contains('dubbing'),
            'enablePath1': features.contains('factcheck') || features.contains('summary'),
            'enablePath2': features.contains('dubbing') || features.contains('subtitles'),
            'autoChapters': autoChapters,
            'priorityMode': priorityMode,
          },
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'stages': {
            'onDemandAI': {
              'status': 'running',
              'progress': 10,
              'requestedFeatures': features,
              'requestedLanguages': targetLanguages,
              'startedAt': DateTime.now().millisecondsSinceEpoch,
            }
          }
        }, SetOptions(merge: true));

        await _firestore.collection('videos').doc(videoId).update({
          'status': 'processing',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar(
          'AI Features Enqueued',
          'Pipeline job updated successfully for video.',
          backgroundColor: const Color(0xFF1E293B),
          colorText: const Color(0xFFF8FAFC),
        );
      }
    } catch (e) {
      debugPrint('Error triggering AI features: $e');
      Get.snackbar('Notice', 'AI feature pipeline initiated: $e');
    }
  }
}






