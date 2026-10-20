import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';

class PlaylistDialogController extends BaseController
    with GetTickerProviderStateMixin {
  final RxBool isCreatingPlaylist = false.obs;
  final RxBool isAddingToPlaylist = false.obs;
  final RxString selectedPlaylistId = ''.obs;
  final RxString newPlaylistName = ''.obs;
  final RxBool showCreateForm = false.obs;
  final RxBool isPublicNewPlaylist = false.obs;

  final RxSet<String> togglingPlaylistIds = <String>{}.obs;

  late final TextEditingController newPlaylistCtrl =
      trackTextController(TextEditingController());

  PlaylistModel? selectedPlaylist;

  late final AnimationController scaleController;
  late final AnimationController listController;
  late final Animation<double> scaleAnimation;
  late final Animation<double> listAnimation;

  @override
  void onInit() {
    super.onInit();
    resetForm();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    scaleController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    listController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    scaleAnimation = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: scaleController, curve: Curves.easeOutBack),
    );

    listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: listController, curve: Curves.easeOutCubic),
    );

    scaleController.forward();
    trackTimer(
      Timer(const Duration(milliseconds: 150), () {
        if (!isClosed) {
          listController.forward();
        }
      }),
    );
  }

  @override
  void onClose() {
    resetForm();
    scaleController.dispose();
    listController.dispose();
    super.onClose();
  }

  void setCreatingPlaylist(bool value) {
    isCreatingPlaylist.value = value;
  }

  void setAddingToPlaylist(bool value) {
    isAddingToPlaylist.value = value;
  }

  void setSelectedPlaylist(String id) {
    selectedPlaylistId.value = id;
  }

  void selectPlaylist(PlaylistModel playlist) {
    setSelectedPlaylist(playlist.id);
    selectedPlaylist = playlist;
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
    isPublicNewPlaylist.value = false;
    togglingPlaylistIds.clear();
    selectedPlaylist = null;
    newPlaylistCtrl.clear();
  }

  bool isPlaylistToggling(String playlistId) {
    return togglingPlaylistIds.contains(playlistId);
  }

  Future<void> togglePlaylistMembership({
    required PlaylistModel playlist,
    required String videoId,
  }) async {
    if (togglingPlaylistIds.contains(playlist.id)) return;

    togglingPlaylistIds.add(playlist.id);
    try {
      final playlistController = Get.isRegistered<PlaylistController>()
          ? Get.find<PlaylistController>()
          : Get.put(PlaylistController());

      if (playlist.id == 'watchlater') {
        await playlistController.toggleWatchLater(
          videoId,
          showFeedback: true,
        );
      } else {
        final isIn = playlist.videoIds.contains(videoId);
        if (isIn) {
          await playlistController.removeVideoFromPlaylist(
            playlist.id,
            videoId,
            playlist.isPublic,
          );
        } else {
          await playlistController.addVideoToPlaylist(
            playlist.id,
            videoId,
            playlist.isPublic,
          );
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistDialogController.togglePlaylistMembership',
      );
      AppSnackbar.error('Unable to update playlist. Please try again.');
    } finally {
      togglingPlaylistIds.remove(playlist.id);
    }
  }

  Future<bool> createNewPlaylist(String videoId) async {
    final name = newPlaylistCtrl.text.trim();
    if (name.isEmpty || isCreatingPlaylist.value) return false;

    final nameVal = ContentValidator.validate(
      name,
      fieldName: 'Playlist Name',
      maxLength: 100,
    );
    if (!nameVal.isValid) {
      AppSnackbar.warning(
        nameVal.message,
        title: 'Content Notice',
      );
      return false;
    }

    setCreatingPlaylist(true);
    try {
      final playlistController = Get.isRegistered<PlaylistController>()
          ? Get.find<PlaylistController>()
          : Get.put(PlaylistController());

      final newPlaylist = await playlistController.createPlayList(
        name,
        isPublic: isPublicNewPlaylist.value,
        videoIds: [videoId],
      );

      newPlaylistCtrl.clear();
      showCreateForm.value = false;
      if (newPlaylist != null) {
        AppSnackbar.success('Playlist "$name" created and video added!');
        return true;
      }
      return false;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistDialogController.createNewPlaylist',
      );
      AppSnackbar.error('Unable to create playlist. Please try again.');
      return false;
    } finally {
      setCreatingPlaylist(false);
    }
  }

  Future<bool> addVideoToPlaylist(String videoId) async {
    final selectedId = selectedPlaylistId.value;
    if (selectedId.isEmpty || isAddingToPlaylist.value) {
      return false;
    }

    setAddingToPlaylist(true);
    try {
      final playlistController = Get.isRegistered<PlaylistController>()
          ? Get.find<PlaylistController>()
          : Get.put(PlaylistController());

      if (selectedId == 'watchlater') {
        return await playlistController.toggleWatchLater(
          videoId,
          showFeedback: true,
        );
      } else {
        final isPublic = selectedPlaylist?.isPublic ?? false;
        final isAlreadyIn =
            selectedPlaylist?.videoIds.contains(videoId) ?? false;

        if (isAlreadyIn) {
          await playlistController.removeVideoFromPlaylist(
            selectedId,
            videoId,
            isPublic,
          );
          return true;
        } else {
          await playlistController.addVideoToPlaylist(
            selectedId,
            videoId,
            isPublic,
          );
          return true;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistDialogController.addVideoToPlaylist',
      );
      AppSnackbar.error('Unable to update playlist. Please try again.');
      return false;
    } finally {
      setAddingToPlaylist(false);
    }
  }
}
