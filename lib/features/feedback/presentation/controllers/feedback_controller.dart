import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';

/// Controller for user feedback submission
/// Handles feedback data collection and Firestore submission
class FeedbackController extends BaseController {
  /// Feedback type observable
  final feedbackType = Rx<String>('General');

  /// Feedback text content observable
  final feedbackText = Rx<String>('');

  /// User rating observable (1-5 stars or 0 for no rating)
  final rating = Rx<int>(0);

  /// Submission status observable
  final isSubmitting = Rx<bool>(false);

  /// Firestore reference
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Feedback collection name
  static const String _feedbackCollection = 'feedback';

  // ========================================================================
  // OBSERVABLE GETTERS
  // ========================================================================

  /// Check if feedback can be submitted
  bool get canSubmit =>
      feedbackText.value.trim().isNotEmpty && !isSubmitting.value;

  /// Check if feedback has rating
  bool get hasRating => rating.value > 0;

  // ========================================================================
  // STATE MANAGEMENT METHODS
  // ========================================================================

  /// Set feedback type
  void setFeedbackType(String type) {
    feedbackType.value = type;
  }

  /// Update feedback text
  void updateFeedbackText(String text) {
    feedbackText.value = text;
    clearError();
  }

  /// Set user rating
  void setRating(int value) {
    if (value >= 0 && value <= 5) {
      rating.value = value;
    }
  }

  /// Clear all feedback data
  void clearFeedback() {
    feedbackText.value = '';
    feedbackType.value = 'General';
    rating.value = 0;
    clearError();
  }

  /// Reset to initial state
  void reset() {
    clearFeedback();
  }

  // ========================================================================
  // FEEDBACK SUBMISSION
  // ========================================================================

  /// Validate feedback before submission
  /// Returns true if valid, false otherwise
  bool _validateFeedback() {
    if (feedbackText.value.trim().isEmpty) {
      setError('Please enter your feedback');
      return false;
    }

    if (feedbackText.value.length < 10) {
      setError('Feedback must be at least 10 characters');
      return false;
    }

    if (feedbackText.value.length > 5000) {
      setError('Feedback cannot exceed 5000 characters');
      return false;
    }

    return true;
  }

  /// Submit feedback to Firestore (strictly requires authenticated user)
  Future<void> submitFeedback({
    required String userId,
    required String userEmail,
    String? appVersion,
    Map<String, dynamic>? deviceInfo,
  }) async {
    if (userId.isEmpty || userId == 'anonymous') {
      setError('You must be signed in to submit feedback');
      showWarning(errorMessage);
      return;
    }

    // Validate input
    if (!_validateFeedback()) {
      showWarning(errorMessage);
      return;
    }

    await safeExecute(
      () => _submitFeedbackToFirestore(
        userId: userId,
        userEmail: userEmail,
        appVersion: appVersion,
        deviceInfo: deviceInfo,
      ),
      loadingMessage: 'Submitting feedback...',
    );
  }

  /// Internal method to submit feedback to Firestore
  Future<void> _submitFeedbackToFirestore({
    required String userId,
    required String userEmail,
    String? appVersion,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final feedbackData = {
        'userId': userId,
        'userEmail': userEmail,
        'feedbackType': feedbackType.value,
        'feedbackText': feedbackText.value.trim(),
        'rating': rating.value,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
        if (appVersion != null) ...{'appVersion': appVersion},
        if (deviceInfo != null) ...{'deviceInfo': deviceInfo},
      };

      await _firestore
          .collection(_feedbackCollection)
          .add(feedbackData)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const TimeoutException(
              message: 'Feedback submission timed out',
            ),
          );

      // Show success and reset
      showSuccess('Thank you! Your feedback has been submitted.');
      clearFeedback();
    } on FirebaseException catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'FeedbackController.submitFeedback',
      );
      throw FirestoreException.fromFirebase(e);
    } on TimeoutException catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'FeedbackController.submitFeedback.timeout',
      );
      rethrow;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'FeedbackController.submitFeedback',
      );
      throw FirestoreException(
        message: 'Failed to submit feedback',
        originalException: e,
      );
    }
  }
}
