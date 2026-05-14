import 'package:get/get.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:truthworld/features/video/domain/database_helpers.dart';

class OfflineVideoController extends GetxController {
  final videoUrl = ''.obs;
  final isLoading = true.obs;
  late String videoId;

  Future<void> loadVideo() async {
    final bytes = await getVideoBytes(videoId);
    if (bytes == null) {
      isLoading.value = false;
      return;
    }
    final blob = html.Blob([bytes], 'video/mp4');
    final url = html.Url.createObjectUrl(blob);
    registerVideoElement(videoId, url);
    videoUrl.value = url;
    isLoading.value = false;
  }

  @override
  void onClose() {
    if (videoUrl.value.isNotEmpty) {
      html.Url.revokeObjectUrl(videoUrl.value);
    }
    super.onClose();
  }
}

// Register the video element
void registerVideoElement(String videoId, String videoUrl) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory('video-$videoId', (int viewId) {
    final video = html.VideoElement()
      ..src = videoUrl
      ..controls = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
    return video;
  });
}




