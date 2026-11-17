import 'dart:math';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// YouTube Feed Refresh Service
///
/// Implements YouTube's Two-Stage Refresh & Recommendation Architecture
/// grounded in Google's research papers:
/// 1. "Deep Neural Networks for YouTube Recommendations" (Covington, Adams, Sargin - Google)
/// 2. "Recommending What Video to Watch Next: A Multitask Ranking System" (Zhao et al. - Google)
///
/// Key YouTube Refresh Mechanics:
/// - Session Impression / Seen-Video Tracking:
///   Demotes videos previously displayed on screen to prevent stale, stagnant feeds on pull-to-refresh.
/// - YouTube Refresh Epoch & Seed Variation:
///   Applies dynamic exploration and seed rotation per refresh cycle.
/// - YouTube Small-Catalog Serendipity Rotation:
///   When the video catalog is small (e.g. fewer than 2 * pageSize or when all candidates have been seen),
///   YouTube rotates the candidate window deterministically using the refresh epoch
///   so that different videos rotate into the top hero positions on every refresh.
/// - Zero Catalog Starvation Policy:
///   All valid videos remain accessible in the feed; demoted/seen items are placed below fresh items.
class YouTubeFeedRefreshService {
  int _refreshEpoch = 0;
  int get refreshEpoch => _refreshEpoch;

  final Set<String> _sessionSeenVideoIds = <String>{};
  Set<String> get seenVideoIds => Set.unmodifiable(_sessionSeenVideoIds);

  String? _lastTopVideoId;
  String? get lastTopVideoId => _lastTopVideoId;

  /// Records video IDs displayed to the user into session impression memory
  void markVideosAsSeen(Iterable<String> videoIds) {
    for (final id in videoIds) {
      if (id.trim().isNotEmpty) {
        _sessionSeenVideoIds.add(id.trim());
      }
    }
  }

  /// Increments the YouTube refresh epoch counter on each pull-to-refresh
  void incrementRefreshEpoch() {
    _refreshEpoch++;
  }

  /// Sets the last displayed top video ID to guarantee that consecutive refreshes
  /// never display the identical video at position #0
  void setLastTopVideoId(String? videoId) {
    _lastTopVideoId = videoId;
  }

  /// Resets the session seen video memory (e.g. on app restart or user sign-out)
  void resetSessionSeen() {
    _sessionSeenVideoIds.clear();
    _refreshEpoch = 0;
    _lastTopVideoId = null;
  }

  /// Re-ranks candidate videos applying YouTube seen-demotion, epoch exploration jitter,
  /// and small-catalog serendipity rotation.
  List<Video> reRankFeedForYouTubeRefresh({
    required List<Video> candidates,
    String? category,
    bool isFlipped = false,
    Set<String>? explicitSeenIds,
  }) {
    if (candidates.isEmpty) return const [];

    // Deduplicate candidates by ID
    final seenCandidateIds = <String>{};
    final uniqueCandidates = <Video>[];
    for (final v in candidates) {
      if (v.id.isNotEmpty && seenCandidateIds.add(v.id)) {
        uniqueCandidates.add(v);
      }
    }

    if (uniqueCandidates.length <= 1) {
      if (uniqueCandidates.isNotEmpty) {
        _lastTopVideoId = uniqueCandidates.first.id;
      }
      return uniqueCandidates;
    }

    final activeSeenIds = explicitSeenIds ?? _sessionSeenVideoIds;

    // Partition candidates into unseen vs previously seen
    final unseenCandidates = <Video>[];
    final seenCandidates = <Video>[];

    for (final v in uniqueCandidates) {
      if (activeSeenIds.contains(v.id)) {
        seenCandidates.add(v);
      } else {
        unseenCandidates.add(v);
      }
    }

    final algorithm = Get.isRegistered<TruthworldAlgorithm>()
        ? Get.find<TruthworldAlgorithm>()
        : null;

    // Case 1: Fresh unseen videos exist in the candidate pool
    if (unseenCandidates.isNotEmpty) {
      List<Video> rankedUnseen;
      List<Video> rankedSeen;

      if (algorithm != null) {
        if (isFlipped) {
          rankedUnseen = algorithm
              .rankVideosOpposite(
                unseenCandidates,
                RecommendationSurface.homeFeedAll,
                diversityConfig: DiversityConfig.homeFeed,
              )
              .map((s) => s.video)
              .toList();
          rankedSeen = algorithm
              .rankVideosOpposite(
                seenCandidates,
                RecommendationSurface.homeFeedAll,
                diversityConfig: DiversityConfig.homeFeed,
              )
              .map((s) => s.video)
              .toList();
        } else {
          rankedUnseen = algorithm
              .rankVideos(
                unseenCandidates,
                RecommendationSurface.homeFeedAll,
                diversityConfig: DiversityConfig.homeFeed,
                seenVideoIds: activeSeenIds,
                refreshEpoch: _refreshEpoch,
              )
              .map((s) => s.video)
              .toList();
          rankedSeen = algorithm
              .rankVideos(
                seenCandidates,
                RecommendationSurface.homeFeedAll,
                diversityConfig: DiversityConfig.homeFeed,
                seenVideoIds: activeSeenIds,
                refreshEpoch: _refreshEpoch,
              )
              .map((s) => s.video)
              .toList();
        }
      } else {
        rankedUnseen = unseenCandidates;
        rankedSeen = seenCandidates;
      }

      // YouTube Refresh Strategy:
      // Fresh unseen candidates take priority at the top of the feed.
      // Previously seen candidates follow smoothly below to preserve catalog discoverability.
      final result = <Video>[];
      final seenResultIds = <String>{};
      for (final v in rankedUnseen) {
        if (seenResultIds.add(v.id)) result.add(v);
      }
      for (final v in rankedSeen) {
        if (seenResultIds.add(v.id)) result.add(v);
      }

      // Guarantee that if result.first is identical to _lastTopVideoId and other items exist,
      // rotate so a fresh video is always at position #0 on pull-to-refresh
      if (_lastTopVideoId != null &&
          result.length > 1 &&
          result.first.id == _lastTopVideoId) {
        final firstItem = result.removeAt(0);
        result.insert(1, firstItem);
      }

      if (result.isNotEmpty) {
        _lastTopVideoId = result.first.id;
      }
      return result;
    }

    // Case 2: All candidates were already seen in this session (e.g. small catalog scenario).
    // YouTube Small-Catalog Serendipity Rotation:
    // Deterministically rotate the candidate pool using the refresh epoch so lower videos
    // rotate into the hero #0 position!
    final rotated = _applyYouTubeSmallCatalogRotation(
      uniqueCandidates,
      epoch: _refreshEpoch,
      isFlipped: isFlipped,
      algorithm: algorithm,
    );

    if (rotated.isNotEmpty) {
      _lastTopVideoId = rotated.first.id;
    }
    return rotated;
  }

  /// Deterministically shifts and interleaves videos for small catalogs when all available
  /// videos have been seen, preventing stuck feeds on pull-to-refresh (YouTube behavior).
  List<Video> _applyYouTubeSmallCatalogRotation(
    List<Video> candidates, {
    required int epoch,
    required bool isFlipped,
    TruthworldAlgorithm? algorithm,
  }) {
    if (candidates.length <= 1) return candidates;

    final n = candidates.length;
    // Step size: for 2 items alternate (step 1); for more items step by 2 or 3
    final step = (n <= 2) ? 1 : ((n % 2 == 0) ? 3 : 2);
    var shift = ((max(1, epoch) * step) - 1) % n;
    if (shift < 0) shift += n;

    final rotated = <Video>[
      ...candidates.sublist(shift),
      ...candidates.sublist(0, shift),
    ];

    // Ensure the top video is not identical to the one displayed right before this refresh
    if (_lastTopVideoId != null &&
        rotated.length > 1 &&
        rotated.first.id == _lastTopVideoId) {
      final firstItem = rotated.removeAt(0);
      rotated.insert(1, firstItem);
    }

    // Enforce channel diversity so consecutive items are not from the same creator
    final diversified = <Video>[];
    final deferred = <Video>[];
    String? lastChannelId;

    for (final v in rotated) {
      if (v.channelId.isNotEmpty && v.channelId == lastChannelId) {
        deferred.add(v);
      } else {
        diversified.add(v);
        lastChannelId = v.channelId;
      }
    }

    // Interleave deferred items safely so they don't land adjacent to the same channel
    for (final def in deferred) {
      var inserted = false;
      for (var i = 0; i <= diversified.length; i++) {
        final prevChannel = (i > 0) ? diversified[i - 1].channelId : null;
        final nextChannel = (i < diversified.length) ? diversified[i].channelId : null;
        if (def.channelId != prevChannel && def.channelId != nextChannel) {
          diversified.insert(i, def);
          inserted = true;
          break;
        }
      }
      if (!inserted) {
        diversified.add(def);
      }
    }

    return diversified;
  }
}
