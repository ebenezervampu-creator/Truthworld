import 'dart:math';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';

/// Tracks the user's interests within the current browsing session.
/// Session interests decay after 30-60 minutes of inactivity.
/// These have HIGH weight in scoring because they represent immediate intent.
class SessionInterestTracker {
  static const Duration sessionTimeout = Duration(minutes: 45);
  static const int maxSessionEvents = 50;

  final List<SessionEvent> _events = [];
  DateTime? _lastEventTime;

  /// Record a session event
  void recordEvent(SessionEvent event) {
    _checkSessionTimeout();
    _events.insert(0, event);
    if (_events.length > maxSessionEvents) {
      _events.removeLast();
    }
    _lastEventTime = DateTime.now();
  }

  /// Convenience wrapper for tracking session events
  void trackSessionEvent(String type, Map<String, dynamic> data) {
    final event = SessionEvent(
      videoId: data['videoId']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      topics: List<String>.from(data['topics'] ?? []),
      channelId: data['channelId']?.toString() ?? '',
      type: type,
      watchProgress: (data['watchProgress'] as num?)?.toDouble() ?? 0.0,
    );
    recordEvent(event);
  }

  /// Get current session's dominant category
  String? get currentSessionDominantCategory {
    _checkSessionTimeout();
    if (_events.isEmpty) return null;

    final categoryWeights = <String, double>{};

    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      if (e.category.isEmpty) continue;

      // Recency multiplier (more recent events in session count more)
      final recencyFactor = pow(0.9, i).toDouble();
      var weight = 1.0 * recencyFactor;

      if (e.type == 'like') weight *= 1.5;
      if (e.type == 'skip') weight *= -0.5;
      if (e.type == 'dislike') weight *= -1.0;

      categoryWeights[e.category] =
          (categoryWeights[e.category] ?? 0.0) + weight;
    }

    if (categoryWeights.isEmpty) return null;

    final sorted = categoryWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.value > 0 ? sorted.first.key : null;
  }

  /// Get current session's dominant topics
  Set<String> get currentSessionDominantTopics {
    _checkSessionTimeout();
    if (_events.isEmpty) return {};

    final topicWeights = <String, double>{};

    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      final recencyFactor = pow(0.9, i).toDouble();

      for (final topic in e.topics) {
        if (topic.isEmpty) continue;
        var weight = 1.0 * recencyFactor;
        if (e.type == 'like') weight *= 1.5;
        if (e.type == 'skip') weight *= -0.5;
        topicWeights[topic] = (topicWeights[topic] ?? 0.0) + weight;
      }
    }

    final dominant = <String>{};
    topicWeights.forEach((topic, weight) {
      if (weight > 0.5) dominant.add(topic);
    });

    return dominant;
  }

  /// Get session topic affinity for a given set of video topics
  double getSessionTopicAffinity(List<String> topics) {
    _checkSessionTimeout();
    if (_events.isEmpty || topics.isEmpty) return 0.0;

    final dominant = currentSessionDominantTopics;
    if (dominant.isEmpty) return 0.0;

    var affinity = 0.0;
    for (final topic in topics) {
      if (dominant.contains(topic)) {
        affinity += 0.4;
      }
    }

    return min(affinity, 1.0);
  }

  /// Get channels recently watched in this session
  Set<String> getRecentlyWatchedChannels() {
    _checkSessionTimeout();
    final channels = <String>{};
    for (final e in _events) {
      if (e.channelId.isNotEmpty && (e.type == 'watch' || e.type == 'click')) {
        channels.add(e.channelId);
      }
    }
    return channels;
  }

  /// Get recent session events
  List<SessionEvent> get recentEvents => List.unmodifiable(_events);

  /// Check session timeout (clear if inactive for > 45 minutes)
  void _checkSessionTimeout() {
    if (_lastEventTime != null &&
        DateTime.now().difference(_lastEventTime!) > sessionTimeout) {
      resetSession();
    }
  }

  /// Reset session
  void resetSession() {
    _events.clear();
    _lastEventTime = null;
  }
}
