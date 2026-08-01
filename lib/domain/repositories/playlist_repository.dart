import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/models/playlist_model.dart';

abstract class PlaylistRepository {
  Future<Result<List<PlaylistModel>>> getPlaylists(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  Future<Result<PlaylistModel>> getPlaylistById(String id);

  Future<Result<PlaylistModel>> createPlaylist(PlaylistModel playlist);

  Future<Result<void>> deletePlaylist(String id);

  Future<Result<void>> addVideoToPlaylist(
    String playlistId,
    String videoId, {
    required String title,
    required String thumbnailUrl,
  });

  Future<Result<void>> removeVideoFromPlaylist(
    String playlistId,
    String videoId,
  );
}
