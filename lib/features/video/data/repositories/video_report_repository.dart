import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';

class VideoReportRepository {
  VideoReportRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;
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

    final callable = _functions.httpsCallable('submitVideoReport');
    await callable.call(<String, dynamic>{
      'videoId': videoId,
      'reportType': reportType,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
  }
}
