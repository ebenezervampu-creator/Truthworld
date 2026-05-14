import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/analytics/data/services/impression_tracking_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    /// ❌ DO NOT put AuthService here anymore
    /// It must be initialized in main() using Get.putAsync()

    // Core analytics services (lazy, fenix for recreation if needed)
    Get.lazyPut(() => GeolocationService(), fenix: true);
    Get.lazyPut(() => VideoAnalyticsService(), fenix: true);
    Get.lazyPut(() => ViewerIdentityService(), fenix: true);
    Get.lazyPut(() => ImpressionTrackingService(), fenix: true);
    Get.lazyPut(() => WatchHistoryService(), fenix: true);

    // Controllers (lazy for performance)
    Get.lazyPut(() => MainController(), fenix: true);
    Get.lazyPut(() => PlaylistController(), fenix: true);
  }
}




