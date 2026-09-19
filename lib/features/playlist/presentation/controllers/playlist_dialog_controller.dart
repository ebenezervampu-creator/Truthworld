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
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: scaleController, curve: Curves.easeOutBack),
    );

    listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: listController, curve: Curves.easeOutCubic),
    );

    scaleController.forward();
    trackTimer(
      Timer(const Duration(milliseconds: 200), () {
        if (!isClosed) {
          listController.forward();
        }
      }),
    );
  }

  @override
  void onClose() {
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
    selectedPlaylist = null;
    newPlaylistCtrl.clear();
  }

  Future<bool> createNewPlaylist(String videoId) async {
    final name = newPlaylistCtrl.text.trim();
    if (name.isEmpty || isCreatingPlaylist.value) return false;

    final nameVal = ContentValidator.validate(name, fieldName: 'Playlist Name');
    if (!nameVal.isValid) {
      AppSnackbar.warning(
        nameVal.message,
        title: 'Content Notice',
      );
      return false;
    }

    setCreatingPlaylist(true);
    try {
      final playlistController = Get.find<PlaylistController>();
      final newPlaylist = await playlistController.createPlayList(
        name,
        isPublic: isPublicNewPlaylist.value,
        videoIds: [videoId],
      );

      newPlaylistCtrl.clear();
      if (newPlaylist != null) {
        AppSnackbar.success('Playlist "$name" created and video added!');
        return true;
      }
      return false;
    } catch (e) {
      ErrorHandler.log(e);
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
      final playlistController = Get.find<PlaylistController>();
      if (selectedId == 'watchlater') {
        final wasIn = playlistController.isInWatchLater(videoId);
        await playlistController.toggleWatchLater(videoId);
        AppSnackbar.success(
          wasIn ? 'Removed from Watch Later' : 'Added to Watch Later',
        );
        return true;
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
          AppSnackbar.success('Removed from playlist successfully');
          return true;
        } else {
          await playlistController.addVideoToPlaylist(
            selectedId,
            videoId,
            isPublic,
          );
          AppSnackbar.success('Video added to playlist successfully');
          return true;
        }
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to update playlist. Please try again.');
      return false;
    } finally {
      setAddingToPlaylist(false);
    }
  }
}
