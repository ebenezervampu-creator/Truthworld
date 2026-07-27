/// Pure domain entity for channel — no framework dependencies.
class ChannelEntity { // active, suspended, deleted

  const ChannelEntity({
    required this.id,
    required this.name,
    required this.handle,
    required this.ownerId, required this.createdAt, required this.updatedAt, this.description = '',
    this.avatarUrl = '',
    this.bannerUrl = '',
    this.subscriberCount = 0,
    this.videoCount = 0,
    this.totalViews = 0,
    this.isVerified = false,
    this.status = 'active',
    this.category = 'other',
    this.categories = const [],
  });
  final String id;
  final String name;
  final String handle;
  final String description;
  final String avatarUrl;
  final String bannerUrl;
  final String ownerId;

  // Stats
  final int subscriberCount;
  final int videoCount;
  final int totalViews;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final String status;
  final String category;
  final List<String> categories;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
