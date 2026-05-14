import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:uuid/uuid.dart';

class ClipController extends GetxController {
  final Video video;
  ClipController({required this.video});

  final RxDouble startSeconds = 0.0.obs;
  final RxDouble endSeconds = 15.0.obs; // Default 15s clip
  final RxString clipTitle = "".obs;
  final RxBool isSaving = false.obs;

  double get maxDuration => 60.0; // Max clip duration 60s

  void updateStart(double value) {
    if (value < endSeconds.value - 1) {
      startSeconds.value = value;
    }
  }

  void updateEnd(double value) {
    if (value > startSeconds.value + 1) {
      if (value - startSeconds.value <= maxDuration) {
        endSeconds.value = value;
      }
    }
  }

  Future<void> saveClip() async {
    if (clipTitle.value.isEmpty) {
      Get.snackbar("Error", "Please enter a title for your clip");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar("Error", "You must be signed in to save clips");
      return;
    }

    isSaving.value = true;
    try {
      final clipId = const Uuid().v4();
      final clip = VideoClip(
        id: clipId,
        videoId: video.id,
        userId: user.uid,
        title: clipTitle.value,
        startTime: startSeconds.value,
        endTime: endSeconds.value,
        thumbnailUrl: video.thumbnailUrl,
        videoTitle: video.title,
        channelName: video.channelName,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('clips')
          .doc(clipId)
          .set(clip.toMap());

      Get.back(); // Close dialog
      Get.snackbar(
        "Success", 
        "Clip saved to your library",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to save clip: $e");
    } finally {
      isSaving.value = false;
    }
  }
}




