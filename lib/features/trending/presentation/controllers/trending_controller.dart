import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/data/repositories/trending_repository_impl.dart';
import 'package:truthworld/domain/usecases/video/get_trending_videos_usecase.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class TrendingController extends BaseController {
  final GetTrendingVideosUseCase _getTrendingVideosUseCase;

  TrendingController({GetTrendingVideosUseCase? getTrendingVideosUseCase})
      : _getTrendingVideosUseCase = getTrendingVideosUseCase ??
            GetTrendingVideosUseCase(
              Get.isRegistered<TrendingRepositoryImpl>()
                  ? Get.find<TrendingRepositoryImpl>()
                  : TrendingRepositoryImpl(),
            );

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

      final result = await _getTrendingVideosUseCase(
        const GetTrendingVideosParams(limit: 50),
      );

      result.when(
        success: (entities) {
          final parsedVideos = entities
              .map(Video.fromEntity)
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
        },
        failure: (failure) {
          ErrorHandler.log(
            failure,
            tag: 'TrendingController.fetchTrendingVideos',
          );
          error.value =
              'Unable to load trending videos. Please check your connection and try again.';
          setViewState(ViewState.error);
        },
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'TrendingController');
      error.value =
          'Unable to load trending videos. Please check your connection and try again.';
      setViewState(ViewState.error);
    }
  }

  void refreshTrending() => fetchTrendingVideos();
}
