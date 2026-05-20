import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_report.dart';
import 'package:truthworld/theme/app_theme.dart';

class ReportsController extends GetxController {
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReportsController({required this.channelId});

  var isLoading = true.obs;
  var reports = <VideoReport>[].obs;
  var reportedVideos = <String, Video>{}.obs;
  
  // Grouped reports: videoId -> list of reports
  var groupedReports = <String, List<VideoReport>>{}.obs;
  
  var selectedVideoId = ''.obs;

  StreamSubscription? _reportsSubscription;

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      _loadReports();
    }
  }

  @override
  void onClose() {
    _reportsSubscription?.cancel();
    super.onClose();
  }

  void _loadReports() {
    isLoading.value = true;
    if (kDebugMode) {
      debugPrint('ReportsController: Listening to reports for channel: $channelId');
      debugPrint('ReportsController: Path: channels/$channelId/reports');
    }
    
    _reportsSubscription = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      final List<VideoReport> allReports = snapshot.docs
          .map((doc) => VideoReport.fromDocumentSnapshot(doc))
          .toList();
      
      reports.value = allReports;
      
      // Group reports
      final Map<String, List<VideoReport>> grouped = {};
      final Set<String> videoIds = {};
      
      for (var report in allReports) {
        if (!grouped.containsKey(report.videoId)) {
          grouped[report.videoId] = [];
          videoIds.add(report.videoId);
        }
        grouped[report.videoId]!.add(report);
      }
      
      groupedReports.value = grouped;
      
      // Fetch video details for reported videos
      await _fetchVideoDetails(videoIds.toList());
      
      isLoading.value = false;
    }, onError: (error) {
      if (kDebugMode) {
        debugPrint("ReportsController: Error loading reports: $error");
        if (error.toString().contains('index')) {
          debugPrint("ReportsController: This query likely requires a Firestore index. Check the link in the error message above.");
        }
      }
      isLoading.value = false;
    });
  }

  Future<void> _fetchVideoDetails(List<String> videoIds) async {
    final List<Future<void>> fetchFutures = [];
    
    for (var id in videoIds) {
      if (!reportedVideos.containsKey(id)) {
        fetchFutures.add(() async {
          try {
            final doc = await _firestore.collection('videos').doc(id).get();
            if (doc.exists) {
              reportedVideos[id] = Video.fromDocumentSnapshot(doc);
              if (kDebugMode) {
                debugPrint("ReportsController: Successfully fetched video details for $id: ${reportedVideos[id]?.title}");
              }
            } else {
              if (kDebugMode) {
                debugPrint("ReportsController: Video document does not exist for ID: $id");
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint("ReportsController: Error fetching video $id: $e");
            }
          }
        }());
      }
    }
    
    if (fetchFutures.isNotEmpty) {
      await Future.wait(fetchFutures);
      reportedVideos.refresh();
    }
  }

  void selectVideo(String videoId) {
    if (kDebugMode) {
      debugPrint('ReportsController: Selecting video: $videoId');
    }
    selectedVideoId.value = videoId;
  }

  Future<void> resolveReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar(
        'Success',
        'Report marked as resolved',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.brand,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to resolve report: $e');
    }
  }
}
