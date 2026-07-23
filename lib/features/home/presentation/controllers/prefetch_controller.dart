import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Prefetch controller for caching home feed videos and instant perceived loading speed
class PrefetchController extends BaseController {
  final _storage = GetStorage();
  static const String _kVideoCacheKey = 'home_videos_cache';

  final cachedVideos = <Video>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadCachedVideos();
  }

  void loadCachedVideos() {
    try {
      final raw = _storage.read<List>(_kVideoCacheKey);
      if (raw != null) {
        final list = raw.map((item) => Video.fromMap(Map<String, dynamic>.from(item))).toList();
        cachedVideos.assignAll(list);
        logCacheHit(_kVideoCacheKey);
      }
    } catch (e) {
      logException(e);
    }
  }

  void cacheVideos(List<Video> videos) {
    try {
      final data = videos.take(20).map((v) => v.toMap()).toList();
      _storage.write(_kVideoCacheKey, data);
    } catch (e) {
      logException(e);
    }
  }
}
