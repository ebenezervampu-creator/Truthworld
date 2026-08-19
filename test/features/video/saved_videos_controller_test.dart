import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/saved_videos_controller.dart';

class TestSavedVideosController extends SavedVideosController {
  @override
  void onInit() {
    super.onInit();
    setViewState(ViewState.idle);
  }

  @override
  Future<void> loadSavedVideos() async {
    setViewState(ViewState.success);
  }

  @override
  Future<void> toggleSaveVideo(Video video) async {
    if (isSaved(video.id)) {
      savedVideoIds.remove(video.id);
      savedVideos.removeWhere((v) => v.id == video.id);
    } else {
      savedVideoIds.add(video.id);
      if (!savedVideos.any((v) => v.id == video.id)) {
        savedVideos.insert(0, video);
      }
    }
  }
}

Video createDummyVideo(String id) {
  return Video(
    id: id,
    title: 'Title $id',
    description: 'desc',
    thumbnailUrl: '',
    ownerId: 'u1',
    channelId: 'c1',
    channelName: 'channel 1',
    category: 'cat',
    tags: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedVideosController Unit Tests', () {
    late TestSavedVideosController controller;

    setUp(() {
      controller = TestSavedVideosController();
    });

    test('initial state', () {
      expect(controller.savedVideos, isEmpty);
      expect(controller.savedVideoIds, isEmpty);
      expect(controller.isSaved('v1'), isFalse);
    });

    test('toggleSaveVideo saves and removes video', () async {
      final video = createDummyVideo('v1');

      await controller.toggleSaveVideo(video);
      expect(controller.isSaved('v1'), isTrue);
      expect(controller.savedVideos.length, equals(1));
      expect(controller.savedVideoIds.contains('v1'), isTrue);

      await controller.toggleSaveVideo(video);
      expect(controller.isSaved('v1'), isFalse);
      expect(controller.savedVideos, isEmpty);
      expect(controller.savedVideoIds.contains('v1'), isFalse);
    });
  });
}
