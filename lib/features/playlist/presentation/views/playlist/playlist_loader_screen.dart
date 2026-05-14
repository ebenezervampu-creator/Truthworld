// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/seo_helper.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/widgets/deep_link_loader_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Production-ready playlist loader for deep links (/playlist/:playlistId).
///
/// Flow:
/// 1. Extract playlistId from route parameters
/// 2. Fetch playlist from Firestore (public first, then private Ã¢â‚¬â€ max 2 reads)
/// 3. Update SEO meta tags (web only)
/// 4. Navigate to playlist detail screen
/// 5. Show branded error state on failure with retry option
class PlaylistLoaderController extends GetxController {
  final hasError = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlaylist());
  }

  Future<void> _loadPlaylist() async {
    final playlistId = Get.parameters['playlistId'];

    if (playlistId == null || playlistId.trim().isEmpty) {
      _setError('Invalid playlist link. No playlist ID was provided.');
      return;
    }

    hasError.value = false;

    try {
      final playlist = await DeepLinkService.instance.loadPlaylist(
        playlistId.trim(),
      );

      if (playlist == null) {
        _setError(
          'This playlist may have been removed, is private, or the link is invalid.',
        );
        return;
      }

      // Update SEO meta tags (web only)
      if (kIsWeb) {
        SeoHelper.setPage(
          title: playlist.playlistName,
          description:
              '${playlist.playlistName} — ${playlist.videoIds.length} videos on TruthWorld',
          url: '/playlist/${playlist.id}',
          image: playlist.thumbnailUrl,
        );
      }

      // Navigate, replacing this screen in the stack
      Get.offNamed('/playlist-detail', arguments: {'playlist': playlist});
    } catch (e) {
      debugPrint('PlaylistLoader: Unexpected error: $e');
      _setError('Something went wrong while loading the playlist.');
    }
  }

  void retry() {
    hasError.value = false;
    errorMessage.value = '';
    _loadPlaylist();
  }

  void _setError(String message) {
    hasError.value = true;
    errorMessage.value = message;
  }
}

class PlaylistLoaderScreen extends StatelessWidget {
  const PlaylistLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlaylistLoaderController());

    return Obx(
      () => DeepLinkLoaderWidget(
        title: 'Loading Playlist',
        subtitle: 'Fetching your playlist...',
        icon: Icons.playlist_play_rounded,
        accentColor: AppTheme.colors.textSecondary,
        hasError: controller.hasError.value,
        errorMessage: controller.errorMessage.value,
        onRetry: controller.retry,
        onGoHome: () => Get.offAllNamed('/'),
      ),
    );
  }
}




