import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

/// GetX controller managing scroll state, key registry, and
/// claim expansion state for the FactCheck overlay.
class FactCheckOverlayController extends BaseController {
  late final ScrollController scrollController;
  final Map<int, GlobalKey> claimKeys = {};
  final RxSet<int> expandedClaimIndices = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    scrollController = trackScrollController(ScrollController());
  }

  void toggleClaimExpanded(int index) {
    if (expandedClaimIndices.contains(index)) {
      expandedClaimIndices.remove(index);
    } else {
      expandedClaimIndices.add(index);
    }
  }

  void scrollToClaim(int index) {
    final key = claimKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }
}
