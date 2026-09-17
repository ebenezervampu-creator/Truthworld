import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';

class VideoReportRepository {
  VideoReportRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int reportThresholdToBlock = 5;

  /// Validate report details for inappropriate content
  Future<ContentValidationResult> validateReportDetails(String details) async {
    if (details.trim().isEmpty) {
      return const ContentValidationResult(isValid: true, message: 'Valid');
    }

    // Check for profanity and offensive content across multi-language dictionaries
    if (ContentValidator.hasProfanity(details)) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate language.',
      );
    }

    return const ContentValidationResult(isValid: true, message: 'Valid');
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
          throw Exception('Video not found.');
        }

        final videoData = snapshot.data()!;
        final reports = (videoData['reports'] as List<dynamic>?) ?? [];
        var reportCount = (videoData['reportCount'] as num?)?.toInt() ?? 0;

        var isUpdated = false;

        // Check for existing report from the same reporter
        for (var i = 0; i < reports.length; i++) {
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
