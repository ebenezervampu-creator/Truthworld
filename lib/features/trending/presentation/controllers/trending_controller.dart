import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/trending_videos_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrendingController extends BaseController {
  final TrendingVideosService _trendingService = TrendingVideosService();
  
  final RxList<Video> trendingVideos = <Video>[].obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchTrendingVideos();
  }

  Future<void> fetchTrendingVideos() async {
    try {
      setState(ViewState.loading);
      error.value = '';
      
      final List<Map<String, dynamic>> rawVideos = await _trendingService.getTrendingVideos();
      
      trendingVideos.assignAll(rawVideos.map((videoData) {
        return Video(
          id: videoData['id'] ?? '',
          title: videoData['title'] ?? '',
          thumbnailUrl: videoData['thumbnailUrl'] ?? '',
          videoUrl: videoData['videoUrl'] ?? '',
          channelName: videoData['channelName'] ?? '',
          channelImage: videoData['channelImage'] ?? '',
          views: int.tryParse(videoData['views']?.toString() ?? '0') ?? 0,
          likes: int.tryParse(videoData['likes']?.toString() ?? '0') ?? 0,
          duration: videoData['duration'] ?? '0:00',
          uploadedAt: Timestamp.fromDate(
            DateTime.tryParse(videoData['uploadedAt'] ?? '') ?? DateTime.now(),
          ),
          ownerId: videoData['ownerId'] ?? '',
          channelId: videoData['channelId'] ?? '',
          category: videoData['category'] ?? 'general',
          tags: (videoData['tags'] as List<dynamic>?)
                  ?.map((tag) => tag.toString())
                  .toList() ??
              [],
          visibility: videoData['visibility'] ?? 'public',
          isKidFriendly: videoData['isKidFriendly'] ?? false,
          isShort: videoData['isShort'] ?? false,
          enableComments: videoData['enableComments'] ?? true,
          allowRatings: videoData['allowRatings'] ?? true,
          reportCount: int.tryParse(videoData['reportCount']?.toString() ?? '0') ?? 0,
          reports: (videoData['reports'] as List<dynamic>?)
                  ?.map((r) => Map<String, dynamic>.from(r as Map))
                  .toList() ??
              [],
          isBlocked: videoData['isBlocked'] ?? false,
          fileName: videoData['fileName'] ?? '',
          likedBy: (videoData['likedBy'] as List<dynamic>?)
                  ?.map((id) => id.toString())
                  .toList() ??
              [],
          shares: (videoData['shares'] as List<dynamic>?)
                  ?.map((s) => s.toString())
                  .toList() ??
              [],
          downloads: int.tryParse(videoData['downloads']?.toString() ?? '0') ?? 0,
          description: videoData['description'] ?? '',
        );
      }).toList());
      setState(ViewState.success);
    } catch (e) {
      error.value = e.toString();
      setState(ViewState.error);
    }
  }

  void refreshTrending() => fetchTrendingVideos();
}





