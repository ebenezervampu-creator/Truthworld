import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/data/services/miniplayer_service.dart';

/// DI binding for the miniplayer feature.
///
/// Registers both the controller and the service as **permanent** singletons
/// so they survive route changes and are available app-wide.
///
/// Called once from `InitialBinding.dependencies()`.
class MiniplayerBinding extends Bindings {
  @override
  void dependencies() {
    // ── Controller ──
    if (!Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      Get.put<MiniplayerController>(
        MiniplayerController(),
        tag: 'miniplayer',
        permanent: true,
      );
    }

    // ── Service ──
    if (!Get.isRegistered<MiniplayerService>()) {
      Get.put<MiniplayerService>(
        MiniplayerService(),
        permanent: true,
      );
    }
  }
}





