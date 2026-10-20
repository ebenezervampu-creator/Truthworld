import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';

class PlaylistDetailController extends BaseController {
  final Rxn<PlaylistModel> activePlaylist = Rxn<PlaylistModel>();
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

  @override
  void onInit() {
    super.onInit();
    initFromRoute();

    if (Get.isRegistered<PlaylistController>()) {
      final playlistController = Get.find<PlaylistController>();
      addWorker(
        ever(playlistController.watchLaterVideoIds, (_) {
          if (activePlaylist.value?.id == 'watchlater') {
            activePlaylist.value = playlistController.getWatchLaterPlaylist();
          }
        }),
      );
    }
  }

  void initFromRoute() {
    final args = Get.arguments;
    if (args != null) {
      if (args is PlaylistModel) {
        activePlaylist.value = args;
        rxIsLoading.value = false;
        return;
      } else if (args is Map && args['playlist'] is PlaylistModel) {
        activePlaylist.value = args['playlist'] as PlaylistModel;
        rxIsLoading.value = false;
        return;
      }
    }

    if (Get.isRegistered<HomeController>()) {
      final rawPlaylist = Get.find<HomeController>().selectedPlaylist.value;
      if (rawPlaylist is PlaylistModel) {
        activePlaylist.value = rawPlaylist;
        rxIsLoading.value = false;
        return;
      }
    }

    final playlistId =
        Get.parameters['playlistId'] ??
        Get.parameters['list'] ??
        Get.parameters['id'];
    if (playlistId != null && playlistId.isNotEmpty) {
      if (playlistId == 'watchlater' && Get.isRegistered<PlaylistController>()) {
        final wl = Get.find<PlaylistController>().getWatchLaterPlaylist();
        if (wl != null && wl.videoCount > 0) {
          activePlaylist.value = wl;
          rxIsLoading.value = false;
          return;
        }
      }
      loadPlaylistFromDeepLink(playlistId);
    }
  }

  void syncPlaylist(PlaylistModel? playlist) {
    if (playlist != null) {
      if (activePlaylist.value?.id != playlist.id ||
          activePlaylist.value?.effectiveVideoCount !=
              playlist.effectiveVideoCount) {
        activePlaylist.value = playlist;
        reset();
      }
    }
  }

  Future<void> loadPlaylistFromDeepLink(String playlistId) async {
    final cached = DeepLinkService.instance.getPlaylistFromCache(playlistId);
    if (cached != null) {
      debugPrint('[PlaylistDetailController] ⚡ 0ms instant cache hit for playlist: $playlistId');
      activePlaylist.value = cached;
      rxIsLoading.value = false;
      return;
    }

    if (playlistId == 'watchlater' && Get.isRegistered<PlaylistController>()) {
      final wl = Get.find<PlaylistController>().getWatchLaterPlaylist();
      if (wl != null && wl.videoCount > 0) {
        activePlaylist.value = wl;
        rxIsLoading.value = false;
        return;
      }
    }

    try {
      rxIsLoading.value = true;
      debugPrint('[PlaylistDetailController] ⏳ Loading deep-linked playlist from Firestore: $playlistId');
      final playlist = await DeepLinkService.instance.loadPlaylist(playlistId);
      if (playlist != null) {
        DeepLinkService.instance.cachePlaylist(playlist);
        activePlaylist.value = playlist;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistDetailController.loadPlaylistFromDeepLink',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

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
