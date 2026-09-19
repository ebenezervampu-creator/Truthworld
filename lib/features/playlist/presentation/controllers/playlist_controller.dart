import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist/playlist_barrel.dart';
import 'package:truthworld/features/video/data/models/video.dart';

export 'playlist/playlist_barrel.dart';

/// Central coordinator for user playlists, watch later synchronization,
/// channel playlists, and video collections.
class PlaylistController extends BaseController with ContentValidationMixin {
  PlaylistController({
    FirebaseFirestore? firestore,
    PlaylistSyncManager? syncManager,
    PlaylistWatchLaterManager? watchLaterManager,
    PlaylistVideoManager? videoManager,
    PlaylistCrudManager? crudManager,
    PlaylistUiFilterManager? filterManager,
  }) {
    final fs = firestore ?? FirebaseFirestore.instance;
    _syncManager = syncManager ??
        PlaylistSyncManager(getUserId: () => user, firestore: fs);
    _watchLaterManager = watchLaterManager ??
        PlaylistWatchLaterManager(
          getUserId: () => user,
          firestore: fs,
          rxIsLoading: rxIsLoading,
        );
    _videoManager = videoManager ??
        PlaylistVideoManager(getUserId: () => user, firestore: fs);
    _filterManager = filterManager ?? PlaylistUiFilterManager();
    _crudManager = crudManager ??
        PlaylistCrudManager(
          getUserId: () => user,
          syncManager: _syncManager,
          refreshPlaylistsTick: _filterManager.refreshPlaylistsTick,
          firestore: fs,
        );
  }

  late final PlaylistSyncManager _syncManager;
  late final PlaylistWatchLaterManager _watchLaterManager;
  late final PlaylistVideoManager _videoManager;
  late final PlaylistCrudManager _crudManager;
  late final PlaylistUiFilterManager _filterManager;

  // Current authenticated user ID
  String get user => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Reactive state pass-throughs
  RxList<Channel> get channels => _syncManager.channels;
  set channels(RxList<Channel> val) => _syncManager.channels.value = val;

  RxList<PlaylistModel> get playlists => _syncManager.playlists;
  set playlists(RxList<PlaylistModel> val) =>
      _syncManager.playlists.value = val;

  RxList<PlaylistModel> get publicPlaylists => _syncManager.publicPlaylists;
  set publicPlaylists(RxList<PlaylistModel> val) =>
      _syncManager.publicPlaylists.value = val;

  Rx<Channel?> get selectedChannel => _syncManager.selectedChannel;
  set selectedChannel(Rx<Channel?> val) =>
      _syncManager.selectedChannel.value = val.value;

  final RxBool rxIsLoading = false.obs;

  RxBool get isPlaylistsLoaded => _syncManager.isPlaylistsLoaded;
  RxBool get isPublicPlaylistsLoaded => _syncManager.isPublicPlaylistsLoaded;

  // UI state pass-throughs
  RxBool get isSearching => _filterManager.isSearching;
  RxBool get isSearchExpanded => _filterManager.isSearchExpanded;
  RxBool get isListView => _filterManager.isListView;
  RxString get sortBy => _filterManager.sortBy;
  RxBool get isAscending => _filterManager.isAscending;
  RxString get searchQuery => _filterManager.searchQuery;
  RxInt get refreshTick => _filterManager.refreshTick;
  RxSet<String> get selectedVideoIds => _filterManager.selectedVideoIds;
  RxString get selectedPlaylistType => _filterManager.selectedPlaylistType;

  // Filter state
  RxString get selectedCategory => _filterManager.selectedCategory;
  List<String> get categories => _filterManager.categories;

  void setCategory(String category) => _filterManager.setCategory(category);
  void toggleView() => _filterManager.toggleView();
  void toggleSearch() => _filterManager.toggleSearch();
  void setSortBy(String newSortBy) => _filterManager.setSortBy(newSortBy);
  void updateSearchQuery(String query) =>
      _filterManager.updateSearchQuery(query);
  void toggleVideoSelection(String videoId) =>
      _filterManager.toggleVideoSelection(videoId);
  void refreshPlaylistsTick() => _filterManager.refreshPlaylistsTick();

  List<PlaylistModel> get allUserPlaylists =>
      _filterManager.getAllUserPlaylists(
        playlists: playlists,
        publicPlaylists: publicPlaylists,
        user: user,
        selectedChannel: selectedChannel.value,
      );

  Iterable<PlaylistModel> get userCreatedPlaylists =>
      _filterManager.getUserCreatedPlaylists(
        allUserPlaylists: allUserPlaylists,
        rawPlaylists: playlists,
      );

  // Watch Later pass-throughs
  RxList<String> get watchLaterVideoIds =>
      _watchLaterManager.watchLaterVideoIds;
  void listenToWatchLater() => _watchLaterManager.listenToWatchLater();
  PlaylistModel? getWatchLaterPlaylist() =>
      _watchLaterManager.getWatchLaterPlaylist();
  Future<void> toggleWatchLater(String videoId) =>
      _watchLaterManager.toggleWatchLater(videoId);
  bool isInWatchLater(String videoId) =>
      _watchLaterManager.isInWatchLater(videoId);

  @override
  void onInit() {
    super.onInit();
    fetchChannels();

    addWorker(
      ever(AuthService.to.currentUser, (u) {
        if (u != null) {
          fetchPlaylists();
          fetchPublicPlaylists();
          listenToWatchLater();
        } else {
          _syncManager.handleUserLoggedOut();
          _watchLaterManager.watchLaterVideoIds.clear();
        }
      }),
    );

    if (user.isNotEmpty) {
      fetchPlaylists();
      fetchPublicPlaylists();
      listenToWatchLater();
    }
  }

  @override
  void onClose() {
    _syncManager.dispose();
    _watchLaterManager.dispose();
    super.onClose();
  }

  // Playlist CRUD pass-throughs
  Future<PlaylistModel?> createPlayList(
    String playlistName, {
    bool isPublic = false,
    List<String> videoIds = const [],
    String description = '',
    String customThumbnailUrl = '',
  }) =>
      _crudManager.createPlayList(
        playlistName,
        isPublic: isPublic,
        videoIds: videoIds,
        description: description,
        customThumbnailUrl: customThumbnailUrl,
      );

  Future<void> deletePlaylist(String playlistId, bool isPublic) =>
      _crudManager.deletePlaylist(playlistId, isPublic);

  Future<PlaylistModel> getPlaylist(
    String playlistId, {
    required bool isPublic,
  }) =>
      _crudManager.getPlaylist(playlistId, isPublic: isPublic);

  Future<void> editPlaylist(
    String playlistId,
    String newName,
    bool isPublic,
  ) =>
      _crudManager.editPlaylist(playlistId, newName, isPublic);

  Future<void> updateSortIndex(
    String playlistId,
    int newIndex,
    bool isPublic,
  ) =>
      _crudManager.updateSortIndex(playlistId, newIndex, isPublic);

  Future<void> togglePlaylistVisibility(
    String playlistId,
    bool currentIsPublic,
  ) =>
      _crudManager.togglePlaylistVisibility(playlistId, currentIsPublic);

  Future<void> sharePlaylist(String playlistId, {String? name}) =>
      _crudManager.sharePlaylist(playlistId, name: name);

  // Video Management pass-throughs
  Future<List<String>> fetchPlaylistVideoIds(
    String playlistId,
    bool isPublic, {
    String? ownerId,
  }) =>
      _videoManager.fetchPlaylistVideoIds(
        playlistId,
        isPublic,
        ownerId: ownerId,
        watchLaterVideoIds: watchLaterVideoIds,
      );

  Future<void> addMultipleVideosToPlaylist(
    String playlistId,
    List<String> videoIdsToAdd,
    bool isPublic,
  ) =>
      _videoManager.addMultipleVideosToPlaylist(
        playlistId,
        videoIdsToAdd,
        isPublic,
      );

  Future<void> addVideoToPlaylist(
    String playlistId,
    String videoId,
    bool isPublic,
  ) =>
      _videoManager.addVideoToPlaylist(playlistId, videoId, isPublic);

  Future<void> removeVideoFromPlaylist(
    String playlistId,
    String videoId,
    bool isPublic,
  ) =>
      _videoManager.removeVideoFromPlaylist(playlistId, videoId, isPublic);

  Future<void> deleteVideoFromAllPlaylists(String videoId) =>
      _videoManager.deleteVideoFromAllPlaylists(videoId);

  Future<List<Video>> fetchVideos(List<String> videoIds) =>
      _videoManager.fetchVideos(videoIds);

  // Fetching & sync pass-throughs
  Stream<List<PlaylistModel>> getPrivatePlaylists() =>
      _syncManager.getPrivatePlaylists();
  Stream<List<PlaylistModel>> getPublicPlaylists() =>
      _syncManager.getPublicPlaylists();
  void fetchChannels() => _syncManager.fetchChannels();
  void fetchPlaylists() => _syncManager.fetchPlaylists();
  Future<void> refreshPlaylists() => _syncManager.refreshPlaylists();
  void fetchPublicPlaylists() => _syncManager.fetchPublicPlaylists();
  Future<void> refreshPublicPlaylists() =>
      _syncManager.refreshPublicPlaylists();
}
