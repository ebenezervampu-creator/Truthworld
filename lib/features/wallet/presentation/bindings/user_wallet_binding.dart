import 'package:get/get.dart';
import 'package:truthworld/core/services/user_wallet_service.dart';
import 'package:truthworld/features/wallet/presentation/controllers/user_wallet_controller.dart';

/// Lazy binding for UserWalletController and UserWalletService
class UserWalletBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<UserWalletService>()) {
      Get.put<UserWalletService>(UserWalletService(), permanent: true);
    }
    Get.lazyPut<UserWalletController>(UserWalletController.new);
  }
}
