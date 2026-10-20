import 'package:get/get.dart';

import 'package:truthworld/core/base/base_controller.dart';

class VideoAnalysisController extends BaseController {
  final RxSet<int> expandedClaimIndices = <int>{}.obs;
  final RxString selectedClaimFilter = 'All'.obs;
  final RxInt selectedTab = 0.obs;

  // Search & Sorting state for claims
  final RxString searchQuery = ''.obs;
  final RxBool isSearchOpen = false.obs;
  final RxString sortOrder = 'Video Order'.obs;

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

  void setSelectedTab(int index) {
    selectedTab.value = index;
  }

  void toggleSearch() {
    isSearchOpen.value = !isSearchOpen.value;
    if (!isSearchOpen.value) {
      searchQuery.value = '';
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void setSortOrder(String order) {
    sortOrder.value = order;
  }
}
