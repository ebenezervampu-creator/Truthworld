import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class FeedbackController extends GetxController {
  final _firestore = FirebaseFirestore.instance;

  final feedbackType = 'General'.obs;
  final feedbackText = ''.obs;
  final rating = 0.obs;
  final isSubmitting = false.obs;

  Future<void> submitFeedback({
    required String userId,
    required String userEmail,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
  }) async {
    if (feedbackText.value.isEmpty) {
      Get.snackbar('Error', 'Please enter your feedback');
      return;
    }

    final feedbackData = {
      'userId': userId,
      'userEmail': userEmail,
      'feedbackType': feedbackType.value,
      'feedbackText': feedbackText.value,
      'rating': rating.value,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'new',
      'appVersion': appVersion,
      'deviceInfo': deviceInfo,
    };

    try {
      isSubmitting.value = true;
      debugPrint('📤 Trying to write feedback: $feedbackData');

      await _firestore
          .collection(FirestoreCollections.feedback)
          .add(feedbackData);

      debugPrint('✅ Feedback successfully saved to Firestore!');
      Get.snackbar('Success', 'Feedback submitted successfully');

      // reset
      feedbackText.value = '';
      rating.value = 0;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error [${e.code}]: ${e.message}');
      Get.snackbar('Error', 'Firestore error: ${e.message}');
    } catch (e, stack) {
      debugPrint('❌ Unexpected error: $e');
      debugPrint(stack as String?);
      Get.snackbar('Error', 'Unexpected error: $e');
    } finally {
      isSubmitting.value = false;
    }
  }
}
