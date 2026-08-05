import 'package:truthworld/core/network/result.dart';

/// Repository interface for feedback operations.
abstract class FeedbackRepository {
  /// Submit user feedback.
  Future<Result<void>> submitFeedback({
    required String userId,
    required String userEmail,
    required String feedbackType,
    required String feedbackText,
    required int rating,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
  });

  /// Fetch all feedback (admin view) with pagination.
  Future<Result<List<Map<String, dynamic>>>> getAllFeedback({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  });

  /// Update feedback status (admin action).
  Future<Result<void>> updateFeedbackStatus(
    String feedbackId,
    String status, {
    String? adminNote,
  });
}
