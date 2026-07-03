import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

class PlaylistNavigation {
  /// Unifies navigation to the playlist detail view.
  /// Navigates to `/[playlistNameSlug]` with the playlist arguments.
  /// When returning, it automatically restores the original tab selection.
  static void openPlaylistDetail(dynamic playlist) async {
    if (playlist == null) return;

    // Generate a URL-safe slug from the playlist name
    String slug = playlist.playlistName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s-]+'), '-');
    if (slug.isEmpty) {
      slug = playlist.id;
    }

    final String targetRoute = '/$slug';

    if (Get.isRegistered<HomeController>()) {
      final homeController = Get.find<HomeController>();
      final String currentRoute = Get.currentRoute;

      // Keep track of the original index to restore when popped
      final int originalIndex = homeController.sideNavSelectedIndex.value;

      if (currentRoute == '/' || currentRoute == '/home') {
        // Navigate and wait for return
        await Get.toNamed(targetRoute, arguments: {'openPlaylist': playlist});
        // Restore state after return
        homeController.sideNavSelectedIndex.value = originalIndex;
        homeController.selectedPlaylist.value = null;
      } else {
        // If not on Home, clear other routes and go to Home dashboard showing this playlist
        Get.offAllNamed(targetRoute, arguments: {'openPlaylist': playlist});
      }
    } else {
      Get.offAllNamed(targetRoute, arguments: {'openPlaylist': playlist});
    }
  }
}
