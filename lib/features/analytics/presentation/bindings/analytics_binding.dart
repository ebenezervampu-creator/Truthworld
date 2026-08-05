import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';

/// Binding for the Analytics feature.
class AnalyticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(CreatorAnalyticsController.new);
  }
}
