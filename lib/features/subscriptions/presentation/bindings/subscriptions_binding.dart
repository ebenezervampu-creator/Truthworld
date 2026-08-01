import 'package:get/get.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';

class SubscriptionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(SubscriptionController.new, fenix: true);
  }
}
