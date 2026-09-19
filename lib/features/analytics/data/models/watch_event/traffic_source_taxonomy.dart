/// Hierarchical traffic source taxonomy for growth analytics.
/// Level 1: Internal vs External
/// Level 2: Specific source within each category
enum TrafficSourceCategory {
  // Internal sources (within platform)
  homeFeed('home_feed', 'Home Feed', TrafficSourceType.internal),
  suggested('suggested', 'Suggested', TrafficSourceType.internal),
  search('search', 'Search', TrafficSourceType.internal),
  channelPage('channel_page', 'Channel Page', TrafficSourceType.internal),
  library('library', 'Library', TrafficSourceType.internal),
  shortsFeed('shorts_feed', 'Shorts Feed', TrafficSourceType.internal),
  trending('trending', 'Trending', TrafficSourceType.internal),
  notifications('notifications', 'Notifications', TrafficSourceType.internal),
  playlist('playlist', 'Playlist', TrafficSourceType.internal),
  endScreen('end_screen', 'End Screen', TrafficSourceType.internal),

  // External sources (outside platform)
  whatsapp('whatsapp', 'WhatsApp', TrafficSourceType.external),
  instagram('instagram', 'Instagram', TrafficSourceType.external),
  twitter('twitter', 'X / Twitter', TrafficSourceType.external),
  facebook('facebook', 'Facebook', TrafficSourceType.external),
  telegram('telegram', 'Telegram', TrafficSourceType.external),
  directLink('direct_link', 'Direct Link', TrafficSourceType.external),
  embed('embed', 'Embed', TrafficSourceType.external),
  otherExternal('other_external', 'Other External', TrafficSourceType.external),

  // Legacy / fallback
  direct('direct', 'Direct', TrafficSourceType.internal),
  unknown('unknown', 'Unknown', TrafficSourceType.internal);

  final String key;
  final String label;
  final TrafficSourceType type;

  const TrafficSourceCategory(this.key, this.label, this.type);

  /// Parse from string key
  static TrafficSourceCategory fromKey(String key) {
    return TrafficSourceCategory.values.firstWhere(
      (e) => e.key == key,
      orElse: () => TrafficSourceCategory.unknown,
    );
  }

  /// Is this an internal source?
  bool get isInternal => type == TrafficSourceType.internal;

  /// Is this an external source?
  bool get isExternal => type == TrafficSourceType.external;
}

enum TrafficSourceType { internal, external }
