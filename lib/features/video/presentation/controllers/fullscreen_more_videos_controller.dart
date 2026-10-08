import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

/// Controller managing scroll bounds, horizontal navigation, and card hover states
/// for the FullscreenMoreVideosOverlay adhering strictly to GetX architecture.
class FullscreenMoreVideosController extends BaseController {
  FullscreenMoreVideosController({required this.playerCtrl});
  final TowerPlayerController playerCtrl;

  final ScrollController scrollController = ScrollController();
  final RxBool canScrollLeft = false.obs;
  final RxBool canScrollRight = false.obs;
  final RxMap<String, bool> hoveredCards = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => updateScrollButtons());
  }

  @override
  void onClose() {
    scrollController.removeListener(updateScrollButtons);
    scrollController.dispose();
    super.onClose();
  }

  void updateScrollButtons() {
    if (!scrollController.hasClients) return;
    canScrollLeft.value = scrollController.offset > 10;
    canScrollRight.value = scrollController.offset <
        (scrollController.position.maxScrollExtent - 10);
  }

  void scroll(double delta) {
    if (!scrollController.hasClients) return;
    final target = (scrollController.offset + delta).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );
    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void handlePointerScroll(double delta) {
    if (!scrollController.hasClients || delta == 0) return;
    final target = (scrollController.offset + delta).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );
    scrollController.jumpTo(target);
  }

  void setCardHovered(String videoId, bool isHovered) {
    hoveredCards[videoId] = isHovered;
  }

  bool isCardHovered(String videoId) => hoveredCards[videoId] == true;
}
