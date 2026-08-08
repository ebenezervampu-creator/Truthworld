import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/geographic_map_widget.dart';

/// Binding for the Analytics feature.
class AnalyticsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CreatorAnalyticsController>()) {
      Get.lazyPut(CreatorAnalyticsController.new);
    }
    if (!Get.isRegistered<GeographicMapController>()) {
      Get.lazyPut(GeographicMapController.new);
    }
  }
}
