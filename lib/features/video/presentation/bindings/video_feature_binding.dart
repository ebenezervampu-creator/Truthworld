import 'package:get/get.dart';
// import 'package:truthworld/features/video/presentation/controllers/mini_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Video feature binding
/// Initializes all controllers for video features
class VideoFeatureBinding extends Bindings {
  @override
  void dependencies() {
    // Video Controller
    Get.lazyPut<VideoController>(VideoController.new);

    // Video Upload
    Get.lazyPut<UploadController>(UploadController.new);

    // Mini Player
    // Get.lazyPut<MiniPlayerController>(() => MiniPlayerController());

    // Comments - Note: CommentsController requires video and mainController
    // These should be provided when actually using this binding
    // For now, commenting out until proper initialization is available
    // Get.lazyPut<CommentsController>(() => CommentsController();

    // Downloads
    Get.lazyPut<DownloadsController>(DownloadsController.new);
  }
}
