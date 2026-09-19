import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// In-memory high-speed LRU entity cache providing 0ms latency for pre-cached models.
mixin DeepLinkCacheManager {
  static const int maxCacheSize = 100;

  final Map<String, Video> _videoCache = {};
  final Map<String, Channel> _channelCache = {};
  final Map<String, PlaylistModel> _playlistCache = {};
  final Map<String, Topic> _topicCache = {};

  void cacheVideo(Video video) {
    if (video.id.isEmpty) return;
    if (_videoCache.length >= maxCacheSize) {
      _videoCache.remove(_videoCache.keys.first);
    }
    _videoCache[video.id] = video;
  }

  void cacheChannel(Channel channel) {
    if (channel.id.isEmpty) return;
    if (_channelCache.length >= maxCacheSize) {
      _channelCache.remove(_channelCache.keys.first);
    }
    _channelCache[channel.id] = channel;
    if (channel.handle.isNotEmpty) {
      final clean = channel.handle.replaceAll(RegExp('^@'), '').toLowerCase();
      _channelCache['@$clean'] = channel;
      _channelCache[clean] = channel;
    }
  }

  void cachePlaylist(PlaylistModel playlist) {
    if (playlist.id.isEmpty) return;
    if (_playlistCache.length >= maxCacheSize) {
      _playlistCache.remove(_playlistCache.keys.first);
    }
    _playlistCache[playlist.id] = playlist;
  }

  void cacheTopic(Topic topic) {
    if (topic.id.isEmpty && topic.slug.isEmpty) return;
    if (_topicCache.length >= maxCacheSize) {
      _topicCache.remove(_topicCache.keys.first);
    }
    if (topic.id.isNotEmpty) _topicCache[topic.id] = topic;
    if (topic.slug.isNotEmpty) _topicCache[topic.slug] = topic;
  }

  Video? getVideoFromCache(String videoId) => _videoCache[videoId];

  Channel? getChannelFromCache(String idOrHandle) {
    final clean = idOrHandle.replaceAll(RegExp('^@'), '').toLowerCase();
    return _channelCache[idOrHandle] ??
        _channelCache['@$clean'] ??
        _channelCache[clean];
  }

  PlaylistModel? getPlaylistFromCache(String playlistId) =>
      _playlistCache[playlistId];

  Topic? getTopicFromCache(String slugOrId) => _topicCache[slugOrId];

  /// Utility for tests or memory cleanup
  void clearCache() {
    _videoCache.clear();
    _channelCache.clear();
    _playlistCache.clear();
    _topicCache.clear();
  }
}
