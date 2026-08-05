import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/features/video/presentation/controllers/register_stub.dart'
    if (dart.library.html) 'register_web.dart';
import 'package:universal_html/html.dart' as html;

class OfflineVideoController extends BaseController {
  final RxString videoUrl = ''.obs;
  final RxBool rxIsLoading = true.obs;
  late String videoId;

  Future<void> loadVideo() async {
    final bytes = await getVideoBytes(videoId);
    if (bytes == null) {
      rxIsLoading.value = false;
      return;
    }
    final blob = html.Blob([bytes], 'video/mp4');
    final url = html.Url.createObjectUrl(blob);
    registerVideoElement(videoId, url);
    videoUrl.value = url;
    rxIsLoading.value = false;
  }

  @override
  void onClose() {
    if (videoUrl.value.isNotEmpty) {
      html.Url.revokeObjectUrl(videoUrl.value);
    }
    super.onClose();
  }
}
