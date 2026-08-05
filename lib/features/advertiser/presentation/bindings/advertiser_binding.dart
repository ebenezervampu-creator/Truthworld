import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';

/// Binding for the Advertiser Portal feature.
class AdvertiserBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(AdvertiserPortalController.new);
  }
}
