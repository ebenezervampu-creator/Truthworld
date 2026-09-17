import 'dart:io' as io;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

mixin UploadMediaPickerMixin on UploadControllerBase {
  Future<void> pickImage({required bool forCommunity}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final extension = pickedFile.extension?.toLowerCase();
        const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif'};
        if (extension == null || !allowedExtensions.contains(extension)) {
          AppSnackbar.warning(
            'Unsupported image format. Allowed formats: JPG, JPEG, PNG, GIF.',
          );
          return;
        }

        // Validate size (2MB limit for video thumbnails, 10MB limit for community posts)
        final maxSize = forCommunity ? 10 * 1024 * 1024 : 2 * 1024 * 1024;
        if (pickedFile.size > maxSize) {
          final sizeLimitMB = forCommunity ? '10MB' : '2MB';
          AppSnackbar.warning(
            'Selected image exceeds the $sizeLimitMB limit.',
          );
          return;
        }

        if (forCommunity) {
          pickedCommunityImage.value = pickedFile;
        } else {
          pickedImage.value = pickedFile;
        }
        await startImageUpload(pickedFile, forCommunity: forCommunity);
      } else {
        AppSnackbar.info('No image selected.');
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'UploadController.pickImage');
      AppSnackbar.error('Unable to select image. Please try again.');
    }
  }

  Future<void> pickVideo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        const maxSizeInBytes = 2 * 1024 * 1024 * 1024; // 2GB
        if (pickedFile.size > maxSizeInBytes) {
          AppSnackbar.warning('Selected video exceeds the 2GB limit.');
          return;
        }

        final extension = pickedFile.extension?.toLowerCase();
        const allowedExtensions = {
          'mp4',
          'mov',
          'avi',
          'wmv',
          'webm',
          'flv',
          '3gpp',
          '3gp',
          'mpeg',
          'mpg',
          'mkv',
          'mpegps',
          'm4v',
          'dnxhr',
          'prores',
          'cineform',
          'hevc',
        };
        if (extension == null || !allowedExtensions.contains(extension)) {
          AppSnackbar.warning(
            'Unsupported video format. Allowed formats: MP4, MOV, AVI, WMV, WEBM, FLV, MKV.',
          );
          return;
        }

        const maxDurationSeconds = 60 * 60; // 60 minutes

        int duration;
        if (kIsWeb) {
          final blob = html.Blob([pickedFile.bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final video = html.VideoElement()
            ..src = url
            ..preload = 'metadata';

          await video.onLoadedMetadata.first;
          duration = video.duration.floor();
          html.Url.revokeObjectUrl(url);
        } else {
          final file = io.File(pickedFile.path!);
          final controller = VideoPlayerController.file(file);

          await controller.initialize();
          duration = controller.value.duration.inSeconds;
          await controller.dispose();
        }

        // Validate Daily Upload Limit & Video Duration against selected channel
        final channel = selectedChannel.value;
        if (channel != null) {
          final todayUsed = await getTodayUploadedDurationSeconds(channel.id);
          todayUploadedDurationSeconds.value = todayUsed;
          remainingDailyDurationSeconds.value =
              (1200 - todayUsed).clamp(0, 1200);
          isDailyLimitReached.value = todayUsed >= 1200;

          final validation = validateChannelVideoUpload(
            channel,
            durationSeconds: duration,
            dailyUploadedDurationSeconds: todayUsed,
          );

          if (!validation.isValid) {
            AppSnackbar.warning(
              validation.message,
            );
            return;
          }
        } else {
          if (duration > maxDurationSeconds) {
            AppSnackbar.warning('Video exceeds 60 minute limit.');
            return;
          }
        }

        pickedVideo.value = pickedFile;
        AppSnackbar.success('Video selected successfully!');

        await initializeVideoPlayer();
        await startVideoUpload(pickedVideo.value!);
      } else {
        AppSnackbar.info('No video selected.');
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'UploadController.pickVideo');
      AppSnackbar.error('Unable to select video. Please try again.');
    }
  }

  @override
  Future<void> initializeVideoPlayer() async {
    if (pickedVideo.value == null) return;

    final file = pickedVideo.value!;

    if (videoPlayerController != null) {
      await videoPlayerController!.dispose();
      videoPlayerController = null;
    }

    if (kIsWeb) {
      if (file.bytes == null) return;
      final blob = html.Blob([file.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      if (file.path == null || !File(file.path!).existsSync()) return;
      videoPlayerController = VideoPlayerController.file(File(file.path!));
    }

    await videoPlayerController!.initialize();
    videoPlayerController!.setLooping(true);

    // Auto-detect if video is a Short (duration <= 60 seconds and vertical aspect ratio)
    final size = videoPlayerController!.value.size;
    final duration = videoPlayerController!.value.duration;
    isShort.value = size.height > size.width && duration.inSeconds <= 60;
    debugPrint(
      '🎥 Auto-detected isShort: ${isShort.value} (size: $size, duration: ${duration.inSeconds}s)',
    );

    update();
  }

  Future<String> getVideoDurationFormatted(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';

        final durationInSeconds = await videoElement.onLoadedMetadata.first
            .then((_) => videoElement.duration);

        html.Url.revokeObjectUrl(url);

        final duration = Duration(seconds: durationInSeconds.floor());
        return _formatDuration(duration);
      } else {
        final File tempFile;
        if (videoFile.path != null && File(videoFile.path!).existsSync()) {
          tempFile = File(videoFile.path!);
        } else {
          final tempDir = await getTemporaryDirectory();
          tempFile = File('${tempDir.path}/${videoFile.name}');
          if (videoFile.bytes != null) {
            await tempFile.writeAsBytes(videoFile.bytes!);
          }
        }

        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        final duration = controller.value.duration;
        await controller.dispose();

        return _formatDuration(duration);
      }
    } catch (e) {
      throw Exception('Failed to get video duration: $e');
    }
  }

  Future<int> getVideoDurationMs(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        if (videoFile.bytes == null) {
          return videoPlayerController?.value.duration.inMilliseconds ?? 0;
        }
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';

        try {
          await videoElement.onLoadedMetadata.first.timeout(
            const Duration(seconds: 4),
          );
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'UploadController.onLoadedMetadata.timeout',
          );
        }

        final durationInSeconds = videoElement.duration;

        html.Url.revokeObjectUrl(url);

        if (durationInSeconds.isNaN ||
            durationInSeconds.isInfinite ||
            durationInSeconds <= 0) {
          return videoPlayerController?.value.duration.inMilliseconds ?? 0;
        }

        return (durationInSeconds * 1000).floor();
      } else {
        if (videoPlayerController != null &&
            videoPlayerController!.value.isInitialized &&
            videoPlayerController!.value.duration.inMilliseconds > 0) {
          return videoPlayerController!.value.duration.inMilliseconds;
        }
        if (videoFile.bytes == null && videoFile.path == null) {
          return 0;
        }
        final File tempFile;
        if (videoFile.path != null && File(videoFile.path!).existsSync()) {
          tempFile = File(videoFile.path!);
        } else {
          final tempDir = await getTemporaryDirectory();
          tempFile = File('${tempDir.path}/${videoFile.name}');
          if (videoFile.bytes != null) {
            await tempFile.writeAsBytes(videoFile.bytes!);
          }
        }

        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        final durationMs = controller.value.duration.inMilliseconds;
        await controller.dispose();

        return durationMs;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UploadMediaPickerMixin.getVideoDurationMs',
      );
      return videoPlayerController?.value.duration.inMilliseconds ?? 0;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
