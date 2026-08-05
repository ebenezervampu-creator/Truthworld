import 'package:get/get.dart';

/// Binding for the Feedback feature.
class FeedbackBinding extends Bindings {
  @override
  void dependencies() {
    // FeedbackController is defined inline in feedbacks.dart
    // This binding serves as a registration point for route-based DI
  }
}
