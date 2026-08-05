import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';


class PlaylistDetailController extends BaseController {
  RxBool rxIsLoading = true.obs;
  RxBool isReordering = false.obs;
  RxBool isDragging = false.obs;
  RxString selectedVideoId = ''.obs;
  RxInt draggedIndex = (-1).obs;
  RxString filterValue = ''.obs;
  RxBool showFilterMenu = false.obs;
  RxString selectedView = 'Grid'.obs;
  RxString selectedSort = 'Recent'.obs;
  RxBool isSearchVisible = false.obs;
  RxInt dragStartIndex = (-1).obs;

  void setLoading(bool value) {
    rxIsLoading.value = value;
  }

  void setReordering(bool value) {
    isReordering.value = value;
  }

  void setDragging(bool value) {
    isDragging.value = value;
  }

  void setSelectedVideo(String id) {
    selectedVideoId.value = id;
  }

  void setDraggedIndex(int index) {
    draggedIndex.value = index;
  }

  void setFilterValue(String value) {
    filterValue.value = value;
  }

  void toggleFilterMenu() {
    showFilterMenu.toggle();
  }

  void setSelectedView(String view) {
    selectedView.value = view;
  }

  void setSelectedSort(String sort) {
    selectedSort.value = sort;
  }

  void toggleSearchVisibility() {
    isSearchVisible.toggle();
  }

  void setDragStartIndex(int index) {
    dragStartIndex.value = index;
  }

  void reset() {
    rxIsLoading.value = false;
    isReordering.value = false;
    isDragging.value = false;
    selectedVideoId.value = '';
    draggedIndex.value = -1;
    dragStartIndex.value = -1;
    filterValue.value = '';
    showFilterMenu.value = false;
  }
}
