import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
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
      
      final rawVideos = await _trendingService.getTrendingVideos();
      
      trendingVideos.assignAll(rawVideos.map((videoData) {
        return Video.fromMap(videoData, (videoData['id'] as String?) ?? '');
      }).toList());
      setViewState(ViewState.success);
    } catch (e) {
      error.value = e.toString();
      setViewState(ViewState.error);
    }
  }

  void refreshTrending() => fetchTrendingVideos();
}





