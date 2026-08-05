import 'package:truthworld/core/network/result.dart';

/// Repository interface for admin panel operations.
///
/// Centralizes all admin Firestore calls behind a clean interface,
/// enabling mock testing and preventing direct Firestore access in controllers.
abstract class AdminRepository {
  /// Fetch all users with pagination and optional search.
  Future<Result<List<Map<String, dynamic>>>> getUsers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
  });

  /// Fetch a single user by ID.
  Future<Result<Map<String, dynamic>>> getUserById(String userId);

  /// Ban a user.
  Future<Result<void>> banUser(String userId, {String? reason});

  /// Unban a user.
  Future<Result<void>> unbanUser(String userId);

  /// Delete a user account.
  Future<Result<void>> deleteUser(String userId);

  /// Fetch all reported content with pagination.
  Future<Result<List<Map<String, dynamic>>>> getReportedContent({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Resolve a content report.
  Future<Result<void>> resolveReport(
    String reportId, {
    required String action,
    String? note,
  });

  /// Fetch platform analytics summary.
  Future<Result<Map<String, dynamic>>> getPlatformAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch all feedback submissions with pagination.
  Future<Result<List<Map<String, dynamic>>>> getFeedback({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Update feedback status.
  Future<Result<void>> updateFeedbackStatus(
    String feedbackId,
    String status,
  );
}
