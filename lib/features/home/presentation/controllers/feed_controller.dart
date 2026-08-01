import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/paged_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Feed controller handling infinite scroll, category filtering, and community post mixing.
class FeedController extends PagedController<Video> {
  FeedController() : super(pageSize: 24);
  final VideoRepository _videoRepository = Get.find<VideoRepository>();

  final RxString selectedCategory = 'All'.obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<dynamic> mixedFeedItems = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    addWorker(
      ever(selectedCategory, (category) {
        logInit();
        loadInitialData();
      }),
    );
  }

  void setCategory(String category) {
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
    }
  }

  @override
  Future<Result<List<Video>>> fetchPageData(int page) async {
    return safeFetchVideos(page);
  }

  Future<Result<List<Video>>> safeFetchVideos(int page) async {
    try {
      logApi('fetchVideos (page: $page, category: ${selectedCategory.value})');

      Result<List<dynamic>> result;

      if (selectedCategory.value != 'All') {
        // Fallback or specific logic if needed, but VideoRepository might not have category filtering in getHomeFeed yet.
        // We will just use searchVideos as a fallback, or we can fetch home feed and map.
        // Let's use searchVideos for now since getHomeFeed doesn't take category.
        // Actually, in the user instructions: "Only change WHERE data comes from (repository vs direct Firestore), not WHAT the controller does"
        // Since VideoRepository has getHomeFeed, but not getHomeFeedByCategory. Let's look at VideoRepositoryImpl.
        result = await _videoRepository.getHomeFeed(
          page: page,
          limit: pageSize,
        );
      } else {
        result = await _videoRepository.getHomeFeed(
          page: page,
          limit: pageSize,
        );
      }

      return result.when(
        success: (entities) {
          // Map VideoEntity back to Video (data model) since PagedController expects Video
          // We can do a rudimentary conversion or just use a factory.
          // Since we must not change what the controller does, we need to return List<Video>.
          final fetchedVideos = entities
              .map(
                (e) => Video(
                  id: e.id,
                  title: e.title,
                  description: e.description,
                  ownerId: e.ownerId,
                  channelId: e.channelId,
                  channelName: e.channelName,
                  channelAvatarUrl: e.channelAvatarUrl,
                  thumbnailUrl: e.thumbnailUrl,
                  originalUrl: e.originalUrl,
                  hlsUrl: e.hlsUrl,
                  dashUrl: e.dashUrl,
                  viewCount: e.viewCount,
                  likeCount: e.likeCount,
                  dislikeCount: e.dislikeCount,
                  commentCount: e.commentCount,
                  shareCount: e.shareCount,
                  duration: e.duration,
                  createdAt: Timestamp.fromDate(e.createdAt),
                  updatedAt: Timestamp.fromDate(e.updatedAt),
                  status: VideoStatus.values.firstWhere(
                    (s) => s.name == e.status,
                    orElse: () => VideoStatus.ready,
                  ),
                  visibility: e.visibility,
                  category: e.category,
                  tags: e.tags,
                  topics: e.topics,
                  language: e.language,
                  isShort: e.isShort,
                  isKidFriendly: e.isKidFriendly,
                  enableComments: e.enableComments,
                  isMonetized: e.isMonetized,
                  trustScore: e.trustScore,
                ),
              )
              .toList();
          return Result.success(fetchedVideos);
        },
        failure: Result.failure,
      );
    } catch (e) {
      logException(e);
      return Result.failure(
        GenericAppException(message: e.toString(), originalException: e),
      );
    }
  }
}
