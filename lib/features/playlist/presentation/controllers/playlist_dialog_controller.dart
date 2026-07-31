import 'package:get/get.dart';

class PlaylistDialogController extends GetxController {
  RxBool isCreatingPlaylist = false.obs;
  RxBool isAddingToPlaylist = false.obs;
  RxString selectedPlaylistId = ''.obs;
  RxString newPlaylistName = ''.obs;
  RxBool showCreateForm = false.obs;

  void setCreatingPlaylist(bool value) {
    isCreatingPlaylist.value = value;
  }

  void setAddingToPlaylist(bool value) {
    isAddingToPlaylist.value = value;
  }

  void setSelectedPlaylist(String id) {
    selectedPlaylistId.value = id;
  }

  void setNewPlaylistName(String name) {
    newPlaylistName.value = name;
  }

  void toggleCreateForm() {
    showCreateForm.toggle();
  }

  void resetForm() {
    selectedPlaylistId.value = '';
    newPlaylistName.value = '';
    showCreateForm.value = false;
    isCreatingPlaylist.value = false;
    isAddingToPlaylist.value = false;
  }
}
