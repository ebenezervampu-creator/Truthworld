import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_trust_score.dart';

/// Central reactive in-memory cache providing 0ms latency for channel entities across TruthWorld.
class ChannelMemoryCache {
  ChannelMemoryCache._();

  /// Internal synchronous storage preventing inadvertent Obx subscriptions on cache reads.
  static final Map<String, Channel> _channels = <String, Channel>{};

  /// Reactive dictionary of channel entities keyed by document ID, owner ID, or handle.
  static final RxMap<String, Channel> channels = <String, Channel>{}.obs;

  /// Internal synchronous storage for trust scores.
  static final Map<String, ChannelTrustScore> _trustScores =
      <String, ChannelTrustScore>{};

  /// Reactive dictionary of channel trust scores keyed by channel document ID or owner ID.
  static final RxMap<String, ChannelTrustScore> trustScores =
      <String, ChannelTrustScore>{}.obs;

  static void _updateReactiveChannel(String key, Channel channel) {
    try {
      final binding = WidgetsBinding.instance;
      if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        binding.addPostFrameCallback((_) {
          channels[key] = channel;
        });
        return;
      }
    } catch (_) {
      // Binding not initialized (e.g. pure unit test environment)
    }
    channels[key] = channel;
  }

  static void _updateReactiveTrustScore(String key, ChannelTrustScore score) {
    try {
      final binding = WidgetsBinding.instance;
      if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        binding.addPostFrameCallback((_) {
          trustScores[key] = score;
        });
        return;
      }
    } catch (_) {
      // Binding not initialized (e.g. pure unit test environment)
    }
    trustScores[key] = score;
  }

  /// Stores a channel into the reactive memory cache and multi-indexes by document ID,
  /// owner ID, and handle for instant lookup.
  static void set(String key, Channel channel) {
    final cleanKey = key.trim();
    if (cleanKey.isNotEmpty) {
      _channels[cleanKey] = channel;
      _updateReactiveChannel(cleanKey, channel);
    }
    if (channel.id.trim().isNotEmpty) {
      final docId = channel.id.trim();
      _channels[docId] = channel;
      _updateReactiveChannel(docId, channel);
    }
    if (channel.ownerId.trim().isNotEmpty) {
      final ownerId = channel.ownerId.trim();
      _channels[ownerId] = channel;
      _updateReactiveChannel(ownerId, channel);
    }
    if (channel.handle.trim().isNotEmpty) {
      final clean = channel.handle.replaceAll(RegExp('^@'), '').toLowerCase();
      _channels['@$clean'] = channel;
      _channels[clean] = channel;
      _updateReactiveChannel('@$clean', channel);
      _updateReactiveChannel(clean, channel);
    }
    DeepLinkService.instance.cacheChannel(channel);
  }

  /// Stores a channel's verified trust score.
  static void setTrustScore(String key, ChannelTrustScore? score) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty || score == null) return;
    _trustScores[cleanKey] = score;
    _updateReactiveTrustScore(cleanKey, score);
  }

  /// Retrieves a channel trust score if previously cached.
  static ChannelTrustScore? getTrustScore(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;
    return _trustScores[cleanKey];
  }

  /// Retrieves a channel from reactive memory cache, falling back to DeepLinkService LRU cache.
  static Channel? get(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;
    final cached = _channels[cleanKey];
    if (cached != null) return cached;
    return DeepLinkService.instance.getChannelFromCache(cleanKey);
  }

  /// Reactive getter that subscribes Obx to live channel updates, falling back to synchronous lookup.
  static Channel? getReactive(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;
    return channels[cleanKey] ?? get(cleanKey);
  }

  /// Checks if a channel exists in memory cache.
  static bool has(String key) => get(key) != null;

  /// Resets the cache (useful for user sign-out or unit testing).
  static void clear() {
    _channels.clear();
    channels.clear();
    _trustScores.clear();
    trustScores.clear();
    DeepLinkService.instance.clearCache();
  }
}
