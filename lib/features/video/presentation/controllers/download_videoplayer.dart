import 'dart:io' as io;

import 'package:flutter/foundation.dart';
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
    rxIsLoading.value = true;
    try {
      if (kIsWeb) {
        final bytes = await getVideoBytes(videoId);
        if (bytes == null) {
          rxIsLoading.value = false;
          return;
        }
        final blob = html.Blob([bytes], 'video/mp4');
        final url = html.Url.createObjectUrl(blob);
        registerVideoElement(videoId, url);
        videoUrl.value = url;
      } else {
        final filePath = await getVideoFilePath(videoId);
        if (filePath != null && io.File(filePath).existsSync()) {
          videoUrl.value = filePath;
        } else {
          final bytes = await getVideoBytes(videoId);
          if (bytes != null) {
            final dir = await getOfflineDirectory();
            final file = io.File('${dir.path}/$videoId.mp4');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes);
            videoUrl.value = file.path;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading offline video: $e');
    } finally {
      rxIsLoading.value = false;
    }
  }

  @override
  void onClose() {
    if (kIsWeb && videoUrl.value.isNotEmpty && videoUrl.value.startsWith('blob:')) {
      try {
        html.Url.revokeObjectUrl(videoUrl.value);
      } catch (_) {}
    }
    super.onClose();
  }
}
