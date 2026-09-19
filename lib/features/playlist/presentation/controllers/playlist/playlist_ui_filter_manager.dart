import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';

/// Manager coordinating UI state, search, sorting, filtering, and categories for PlaylistScreen.
class PlaylistUiFilterManager {
  // UI State for PlaylistScreen
  final RxBool isSearching = false.obs;
  final RxBool isSearchExpanded = false.obs;
  final RxBool isListView = true.obs;
  final RxString sortBy = 'recent'.obs;
  final RxBool isAscending = false.obs;
  final RxString searchQuery = ''.obs;
  final RxInt refreshTick = 0.obs;
  final RxSet<String> selectedVideoIds = <String>{}.obs;
  final RxString selectedPlaylistType = 'private'.obs;

  // Filter State
  final RxString selectedCategory = 'Playlists'.obs;
  final List<String> categories = const [
    'Playlists',
    'Music',
    'Podcasts',
    'Courses',
    'Owned',
    'Saved',
  ];

  void setCategory(String category) => selectedCategory.value = category;

  void toggleView() => isListView.value = !isListView.value;

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) searchQuery.value = '';
  }

  void setSortBy(String newSortBy) {
    if (sortBy.value == newSortBy) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = newSortBy;
      isAscending.value = false;
    }
  }

  void updateSearchQuery(String query) => searchQuery.value = query;

  void toggleVideoSelection(String videoId) {
    if (selectedVideoIds.contains(videoId)) {
      selectedVideoIds.remove(videoId);
    } else {
      selectedVideoIds.add(videoId);
    }
    selectedVideoIds.refresh();
  }

  void refreshPlaylistsTick() => refreshTick.value++;

  List<PlaylistModel> getAllUserPlaylists({
    required List<PlaylistModel> playlists,
    required List<PlaylistModel> publicPlaylists,
    required String user,
    required Channel? selectedChannel,
  }) {
    final map = <String, PlaylistModel>{};
    for (final p in playlists) {
      map[p.id] = p;
    }
    for (final p in publicPlaylists) {
      if (user.isEmpty ||
          p.ownerId == user ||
          (selectedChannel != null &&
              p.channelId == selectedChannel.channelId)) {
        map[p.id] = p;
      }
    }
    return map.values.toList();
  }

  Iterable<PlaylistModel> getUserCreatedPlaylists({
    required List<PlaylistModel> allUserPlaylists,
    required List<PlaylistModel> rawPlaylists,
  }) {
    final filtered = allUserPlaylists.where((p) {
      final name = p.playlistName.toLowerCase().trim();
      final isWatchLater = name == 'watch later' ||
          name == 'watchlater' ||
          name == 'watch_later' ||
          name.contains('watch later');

      final hasThumbnail = p.thumbnailUrl.trim().isNotEmpty;

      return !isWatchLater && name.isNotEmpty && hasThumbnail;
    });

    logger.debug(
      'Playlist filtering: ${rawPlaylists.length} total → ${filtered.length} visible',
      tag: 'PLAYLIST',
    );
    return filtered;
  }
}
