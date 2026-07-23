/// Pure domain entity for playlists — no framework dependencies.
class PlaylistEntity {

  const PlaylistEntity({
    required this.id,
    required this.title,
    required this.ownerId, required this.createdAt, required this.updatedAt, this.description = '',
    this.thumbnailUrl = '',
    this.videoCount = 0,
    this.visibility = 'public',
  });
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String thumbnailUrl;
  final int videoCount;
  final String visibility; // public, private, unlisted
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
