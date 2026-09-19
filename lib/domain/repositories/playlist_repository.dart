import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/playlist_entity.dart';

abstract class PlaylistRepository {
  Future<Result<List<PlaylistEntity>>> getPlaylists(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  Future<Result<PlaylistEntity>> getPlaylistById(String id);

  Future<Result<PlaylistEntity>> createPlaylist(PlaylistEntity playlist);

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
