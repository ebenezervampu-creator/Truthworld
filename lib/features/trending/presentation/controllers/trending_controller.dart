import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/trending_videos_service.dart';

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
      setViewState(ViewState.loading);
      error.value = '';

      final rawData = await _trendingService.getTrendingVideos();

      final parsedVideos = rawData
          .map((videoData) => Video.fromMap(videoData, (videoData['id'] as String?) ?? ''))
          .where(VideoVisibilityPolicy.isValidVideo)
          .toList();

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          parsedVideos,
          RecommendationSurface.trending,
          diversityConfig: DiversityConfig.trending,
        );
        final rankedVideos = ranked.map((s) => s.video).toList();
        trendingVideos.assignAll(
          rankedVideos.isNotEmpty ? rankedVideos : parsedVideos,
        );
      } else {
        trendingVideos.assignAll(parsedVideos);
      }

      setViewState(ViewState.success);
    } catch (e) {
      error.value = e.toString();
      setViewState(ViewState.error);
    }
  }

  void refreshTrending() => fetchTrendingVideos();
}
