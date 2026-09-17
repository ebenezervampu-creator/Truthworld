import 'package:get/get.dart';

import 'package:truthworld/core/base/base_controller.dart';

class VideoAnalysisController extends BaseController {
  final RxSet<int> expandedClaimIndices = <int>{}.obs;
  final RxString selectedClaimFilter = 'All'.obs;

  void toggleClaimExpanded(int index) {
    if (expandedClaimIndices.contains(index)) {
      expandedClaimIndices.remove(index);
    } else {
      expandedClaimIndices.add(index);
    }
  }

  void setClaimFilter(String filter) {
    selectedClaimFilter.value = filter;
  }
}
