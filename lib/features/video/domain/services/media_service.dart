import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class MediaResult {

  MediaResult({
    required this.file,
    this.durationSeconds = 0,
    this.webUrl,
  });
  final PlatformFile file;
  final int durationSeconds;
  final String? webUrl;
}

class MediaService {
  String? _webVideoObjectUrl;

  Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      return result.files.first;
    }
    return null;
  }

  Future<MediaResult?> pickVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    
    if (result != null && result.files.isNotEmpty) {
      final pickedFile = result.files.first;

      const maxSizeInBytes = 2 * 1024 * 1024 * 1024; // 2GB
      if (pickedFile.size > maxSizeInBytes) {
        throw Exception('Selected video exceeds the 2GB limit.');
      }

      var extension = pickedFile.extension?.toLowerCase();
      if (extension == null || extension.isEmpty) {
        final name = pickedFile.name;
        if (name.contains('.')) {
          extension = name.split('.').last.toLowerCase();
        }
      }
      const allowedExtensions = {
        'mp4', 'mov', 'avi', 'wmv', 'webm', 'flv', '3gpp', '3gp', 'mpeg', 'mpg', 'mkv', 'mpegps', 'm4v', 'dnxhr', 'prores', 'cineform', 'hevc'
      };
      if (extension == null || !allowedExtensions.contains(extension)) {
        throw Exception('Unsupported video format. YouTube allowed formats are supported.');
      }

      const maxDurationSeconds = 60 * 60; // 60 minutes
      final duration = await getVideoDuration(pickedFile, _webVideoObjectUrl);

      if (duration > maxDurationSeconds) {
        throw Exception('Video exceeds 60 minute limit.');
      }

      return MediaResult(
        file: pickedFile,
        durationSeconds: duration,
        webUrl: _webVideoObjectUrl,
      );
    }
    return null;
  }
  
  Future<int> getVideoDuration(PlatformFile videoFile, String? webUrl) async {
    try {
      if (kIsWeb) {
        final url = webUrl ?? videoFile.xFile.path;
        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';
        await videoElement.onLoadedMetadata.first;
        return videoElement.duration.floor();
      } else {
        final file = io.File(videoFile.path!);
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        final duration = controller.value.duration.inSeconds;
        await controller.dispose();
        return duration;
      }
    } catch (e) {
      return 0; // Fallback or handle estimation
    }
  }

  void dispose() {
    if (kIsWeb && _webVideoObjectUrl != null) {
      try {
        html.Url.revokeObjectUrl(_webVideoObjectUrl!);
      } catch (_) {}
    }
  }
}
