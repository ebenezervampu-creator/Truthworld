import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Sub-controller responsible for fetching, ranking, filtering, and caching
/// video recommendations, channel videos, related topics, and playlists.
class VideoRecommendationsController extends BaseController {
  VideoRecommendationsController({
    required this.getVideo,
    this.getCurrentPlaylist,
    this.getPlaylistVideos,
    this.getNavigatedFromTopic,
  });

  final Video Function() getVideo;
  final PlaylistModel? Function()? getCurrentPlaylist;
  final List<Video> Function()? getPlaylistVideos;
  final bool Function()? getNavigatedFromTopic;

  // Recommendations Cache
  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<Video> moreFromChannel = <Video>[].obs;
  final RxBool isLoadingRecommendations = true.obs;
  final RxString selectedRecommendationFilter = 'All'.obs;
  final RxInt recommendationActiveTab = 0.obs;

  // Topics and Playlists recommendation tabs state
  final RxList<Topic> videoTopicsList = <Topic>[].obs;
  final RxList<PlaylistModel> videoPlaylistsList = <PlaylistModel>[].obs;
  final RxMap<String, List<Video>> topicVideosCache =
      <String, List<Video>>{}.obs;
  final RxMap<String, List<Video>> playlistVideosCache =
      <String, List<Video>>{}.obs;

  List<dynamic> get recommendedItems {
    final video = getVideo();
    final displayVideos = filteredRecommendedVideos;
    final isFlipped = (selectedRecommendationFilter.value == 'Flip Coin') ||
        (Get.isRegistered<FlipCoinService>() &&
            Get.find<FlipCoinService>().isVideoFlipped(video.id));
    if (isFlipped) {
      return List<dynamic>.from(displayVideos);
    }

    final mixed = <dynamic>[];
    var videoIndex = 0;
    var postIndex = 0;
    var topicIndex = 0;
    var adIndex = 0;
    final scrollAds = Get.isRegistered<AdService>()
        ? AdService.to.getAdsForType('scroll')
        : <AdItem>[];

    while (videoIndex < displayVideos.length ||
        postIndex < communityPosts.length ||
        topicIndex < videoTopicsList.length) {
      for (var i = 0; i < 4 && videoIndex < displayVideos.length; i++) {
        mixed.add(displayVideos[videoIndex++]);
      }
      if (scrollAds.isNotEmpty && videoIndex < displayVideos.length) {
        mixed.add(scrollAds[adIndex++ % scrollAds.length]);
      }
      if (topicIndex < videoTopicsList.length) {
        mixed.add(videoTopicsList[topicIndex++]);
      }
      if (postIndex < communityPosts.length) {
        mixed.add(communityPosts[postIndex++]);
      }
    }
    return mixed;
  }

  List<String> get recommendationFilters {
    final video = getVideo();
    final list = ['All', 'Flip Coin'];

    // 1. Topics tab (ONLY if navigated from Topics page)
    if (getNavigatedFromTopic?.call() ?? false) {
      for (final topic in videoTopicsList) {
        final name = 'Topic: ${topic.title}';
        if (!list.contains(name) && !list.contains(topic.title)) {
          list.add(name);
        }
      }
    }

    // 2. Channel tab
    if (video.channelName.isNotEmpty) {
      list.add('From ${video.channelName}');
    }

    // 3. Tags / Category
    if (video.tags.isNotEmpty) {
      for (final t in video.tags.take(3)) {
        if (!list.contains(t)) list.add(t);
      }
    } else if (video.category.isNotEmpty && !list.contains(video.category)) {
      list.add(video.category);
    }

    return list;
  }

  List<Video> get filteredRecommendedVideos {
    final video = getVideo();
    final filter = selectedRecommendationFilter.value;
    if (filter == 'All' || filter == 'Flip Coin') {
      return recommendedVideos;
    }

    // Check if filter is a Playlist tab
    final currentPlaylist = getCurrentPlaylist?.call();
    final playlistVideos = getPlaylistVideos?.call() ?? <Video>[];
    if (filter.startsWith('Playlist: ')) {
      final plName = filter.replaceFirst('Playlist: ', '');
      if (currentPlaylist != null && currentPlaylist.playlistName == plName) {
        if (playlistVideos.isNotEmpty) return playlistVideos;
      }
      final matchedPlaylist = videoPlaylistsList.firstWhereOrNull(
        (p) => p.playlistName == plName,
      );
      if (matchedPlaylist != null) {
        return playlistVideosCache[matchedPlaylist.id] ?? [];
      }
    }

    final matchedPlaylistDirect = videoPlaylistsList.firstWhereOrNull(
      (p) => p.playlistName == filter,
    );
    if (matchedPlaylistDirect != null) {
      return playlistVideosCache[matchedPlaylistDirect.id] ?? [];
    }

    // Check if filter is a Topic tab
    if (filter.startsWith('Topic: ')) {
      final topicTitle = filter.replaceFirst('Topic: ', '');
      final matchedTopic = videoTopicsList.firstWhereOrNull(
        (t) => t.title == topicTitle,
      );
      if (matchedTopic != null) {
        return topicVideosCache[matchedTopic.id] ?? [];
      }
    }

    final matchedTopicDirect = videoTopicsList.firstWhereOrNull(
      (t) => t.title == filter,
    );
    if (matchedTopicDirect != null) {
      return topicVideosCache[matchedTopicDirect.id] ?? [];
    }

    if (filter == 'From ${video.channelName}') {
      return moreFromChannel;
    }

    final filterLower = filter.toLowerCase();
    return recommendedVideos.where((v) {
      final titleLower = v.title.toLowerCase();
      final descLower = v.description.toLowerCase();
      final tagMatch = v.tags.any((t) => t.toLowerCase() == filterLower);
      final categoryMatch = v.category.toLowerCase() == filterLower;
      return titleLower.contains(filterLower) ||
          descLower.contains(filterLower) ||
          tagMatch ||
          categoryMatch;
    }).toList();
  }

  Future<void> fetchRecommendations() async {
    selectedRecommendationFilter.value = 'All';
    isLoadingRecommendations.value = true;
    try {
      final video = getVideo();
      final videoId = video.id;

      // 1. If we are in a playlist, fetch other videos from the playlist
      var hasPlaylistVideos = false;
      final currentPlaylist = getCurrentPlaylist?.call();
      if (currentPlaylist != null) {
        final playlistVideoIds = currentPlaylist.videoIds
            .where((id) => id != videoId)
            .take(15)
            .toList();

        if (playlistVideoIds.isNotEmpty) {
          final playlistVideos = <Video>[];
          for (var i = 0; i < playlistVideoIds.length; i += 10) {
            final chunk = playlistVideoIds.sublist(
              i,
              i + 10 > playlistVideoIds.length
                  ? playlistVideoIds.length
                  : i + 10,
            );
            final playlistVidsQuery = await FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

            playlistVideos.addAll(
              playlistVidsQuery.docs
                  .map(Video.fromDocumentSnapshot)
                  .where(VideoVisibilityPolicy.canViewVideo),
            );
          }

          // Sort them to match playlist order if possible
          playlistVideos.sort((a, b) {
            final indexA = currentPlaylist.videoIds.indexOf(a.id);
            final indexB = currentPlaylist.videoIds.indexOf(b.id);
            return indexA.compareTo(indexB);
          });

          recommendedVideos.value = playlistVideos;
          moreFromChannel.value =
              playlistVideos; // In playlist mode, they are the same
          hasPlaylistVideos = true;
        }
      }

      if (!hasPlaylistVideos) {
        final isFlipped = (selectedRecommendationFilter.value == 'Flip Coin') ||
            (Get.isRegistered<FlipCoinService>() &&
                Get.find<FlipCoinService>().isVideoFlipped(video.id));

        if (isFlipped) {
          final candidateList = <Video>[];

          // 1. If video has an explicit paired counter-video (Coin Battle pair), fetch it directly!
          if (video.coinBattlePairVideoId != null &&
              video.coinBattlePairVideoId!.isNotEmpty) {
            try {
              final pairDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.videos)
                  .doc(video.coinBattlePairVideoId)
                  .get();
              if (pairDoc.exists && pairDoc.data() != null) {
                final cand = Video.fromDocumentSnapshot(pairDoc);
                if (VideoVisibilityPolicy.isVisibleForRecommendation(cand)) {
                  candidateList.add(cand);
                }
              }
            } catch (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchCoinBattlePair');
            }
          }

          // 2. Fetch a broad pool of public candidate videos
          try {
            final candidatesQuery = await FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('status', isEqualTo: 'public')
                .where('visibility', isEqualTo: 'public')
                .limit(60)
                .get();

            for (final doc in candidatesQuery.docs) {
              if (doc.id != videoId &&
                  !candidateList.any((v) => v.id == doc.id)) {
                final cand = Video.fromDocumentSnapshot(doc);
                if (VideoVisibilityPolicy.isVisibleForRecommendation(cand)) {
                  candidateList.add(cand);
                }
              }
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchFlipCandidates');
          }

          if (Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideosForCurrentVideoOpposite(
              video,
              candidateList,
            );
            recommendedVideos.value = ranked.map((s) => s.video).toList();
          } else {
            recommendedVideos.value = candidateList;
          }
        } else {
          // Normal recommendations logic
          final channelId = video.channelId;

          // Single efficient fetch for channel videos
          final channelVidsQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: channelId)
              .where(FieldPath.documentId, isNotEqualTo: videoId)
              .limit(10)
              .get();

          final channelVideos = channelVidsQuery.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .toList();

          // Fill the rest with general videos
          final generalVidsQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, isNotEqualTo: videoId)
              .limit(20)
              .get();

          final generalVideos = generalVidsQuery.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .where(
                (v) =>
                    v.id != videoId && !channelVideos.any((cv) => cv.id == v.id),
              )
              .toList();

          moreFromChannel.value = channelVideos;
          final rawRecommended = {...channelVideos, ...generalVideos}.toList();

          if (Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideos(
              rawRecommended,
              RecommendationSurface.videoRelated,
              diversityConfig: DiversityConfig.videoRelated,
            );
            final rankedList = ranked.map((s) => s.video).toList();
            recommendedVideos.value = rankedList.isNotEmpty
                ? rankedList
                : rawRecommended;
          } else {
            recommendedVideos.value = rawRecommended;
          }
        }
      }

      // Fetch topics and playlists containing this video
      await _fetchTopicsAndPlaylistsForRecommendations();

      // Fetch community posts
      try {
        final postsSnapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.community)
            .where('visibility', isEqualTo: 'Public')
            .limit(30)
            .get();
        final posts = postsSnapshot.docs
            .map((doc) => CommunityPostModel.fromMap(doc.data()))
            .toList();
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.assignAll(posts.take(5));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchCommunityPosts');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchRecommendations');
    } finally {
      isLoadingRecommendations.value = false;
    }
  }

  Future<void> _fetchTopicsAndPlaylistsForRecommendations() async {
    try {
      final video = getVideo();
      final videoId = video.id;

      // Clear previous caches
      videoTopicsList.clear();
      videoPlaylistsList.clear();
      topicVideosCache.clear();
      playlistVideosCache.clear();

      // --- 1. Topics ---
      final foundTopics = <Topic>[];
      if (video.topics.isNotEmpty) {
        for (var i = 0; i < video.topics.length; i += 10) {
          final chunk = video.topics.sublist(
            i,
            i + 10 > video.topics.length ? video.topics.length : i + 10,
          );
          final topicsSnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .where('slug', whereIn: chunk)
              .where('status', isEqualTo: 'active')
              .get();

          foundTopics.addAll(
            topicsSnapshot.docs
                .map(Topic.fromDocumentSnapshot)
                .where((t) => t.isValidTopic && t.videoCount > 0),
          );
        }
      }

      if (foundTopics.length < 3) {
        try {
          final publicTopicsSnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .where('status', isEqualTo: 'active')
              .orderBy('videoCount', descending: true)
              .limit(10)
              .get();
          final publicTopics = publicTopicsSnapshot.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) =>
                  t.isValidTopic &&
                  t.videoCount > 0 &&
                  !foundTopics.any((ft) => ft.id == t.id))
              .toList();
          foundTopics.addAll(publicTopics);
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchPublicTopicsFallback');
        }
      }

      videoTopicsList.assignAll(
        foundTopics.where((t) => t.isValidTopic && t.videoCount > 0),
      );

      // Fetch videos for each topic in parallel
      final topicFutures = foundTopics.map((topic) async {
        try {
          final query = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('topics', arrayContains: topic.slug)
              .where('visibility', isEqualTo: 'Public')
              .limit(10)
              .get();

          final topicVids = query.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.isVisibleForRecommendation)
              .toList();

          return MapEntry(topic.id, topicVids);
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.loadTopicVideos');
          return MapEntry(topic.id, <Video>[]);
        }
      }).toList();

      final topicResults = await Future.wait(topicFutures);
      for (final entry in topicResults) {
        topicVideosCache[entry.key] = entry.value;
      }

      // --- 2. Playlists ---
      final foundPlaylists = <PlaylistModel>[];

      // Fetch public playlists containing this video
      final publicPlaylistsQuery = await FirebaseFirestore.instance
          .collection('public_playlists')
          .where('videoIds', arrayContains: videoId)
          .limit(5)
          .get();

      foundPlaylists.addAll(
        publicPlaylistsQuery.docs
            .map(PlaylistModel.fromDocumentSnapshot)
            .toList(),
      );

      // Fetch private playlists of the user containing this video
      final currentUserId = AuthService.to.uid;
      if (currentUserId.isNotEmpty) {
        final privatePlaylistsQuery = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(currentUserId)
            .collection(FirestoreCollections.playlists)
            .where('videoIds', arrayContains: videoId)
            .limit(5)
            .get();

        foundPlaylists.addAll(
          privatePlaylistsQuery.docs
              .map(PlaylistModel.fromDocumentSnapshot)
              .toList(),
        );
      }

      videoPlaylistsList.assignAll(foundPlaylists);

      // Fetch videos for each playlist
      for (final playlist in foundPlaylists) {
        if (playlist.videoIds.isNotEmpty) {
          final playlistVids = await _fetchVideosByIds(playlist.videoIds);
          playlistVideosCache[playlist.id] = playlistVids;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController.fetchTopicsAndPlaylists');
    }
  }

  Future<List<Video>> _fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final result = <Video>[];
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        result.addAll(
          snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.canViewVideo),
        );
      }
      // Sort to match original ids list order
      result.sort((a, b) {
        final indexA = ids.indexOf(a.id);
        final indexB = ids.indexOf(b.id);
        return indexA.compareTo(indexB);
      });
      return result;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoRecommendationsController._fetchVideosByIds');
      return [];
    }
  }
}
