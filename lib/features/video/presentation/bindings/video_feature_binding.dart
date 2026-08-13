import 'package:get/get.dart';
import 'package:truthworld/features/video/data/repositories/firestore_comments_repository.dart';
import 'package:truthworld/features/video/data/repositories/firestore_video_repository.dart';
import 'package:truthworld/features/video/data/repositories/storage_video_upload_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_comments_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_upload_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Video feature binding.
/// Wires repository interfaces to DataSources and injects dependencies into Controllers.
class VideoFeatureBinding extends Bindings {
  @override
  void dependencies() {
    // ── Repositories & DataSources ──
    Get.lazyPut<VideoRepository>(FirestoreVideoRepository.new);
    Get.lazyPut<VideoCommentsRepository>(FirestoreCommentsRepository.new);
    Get.lazyPut<VideoUploadRepository>(StorageVideoUploadRepository.new);

    // ── Controllers ──
    Get.lazyPut<VideoController>(
      () => VideoController(videoRepository: Get.find<VideoRepository>()),
    );
    Get.lazyPut<UploadController>(
      () => UploadController(uploadRepository: Get.find<VideoUploadRepository>()),
    );
    Get.lazyPut<DownloadsController>(DownloadsController.new);
  }
}
