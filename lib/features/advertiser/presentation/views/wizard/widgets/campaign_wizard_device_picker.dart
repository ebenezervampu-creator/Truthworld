import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

/// Helper to pick a media file from user's device, validate length/size, and upload to storage.
Future<void> pickCampaignDeviceMediaFile({
  required BuildContext context,
  required FileType fileType,
  required TextEditingController targetController,
  required RxString pickedFileNameNotifier,
  required RxBool isUploadingNotifier,
  required RxDouble uploadProgressNotifier,
  required RxString uploadStatusNotifier,
  RxString? pickedMetaNotifier,
  List<String>? allowedExtensions,
  double? maxDurationSeconds,
  String? durationLimitWarningText,
}) async {
  isUploadingNotifier.value = true;
  uploadProgressNotifier.value = 0.05;
  uploadStatusNotifier.value = 'Opening file selector...';

  try {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: (allowedExtensions != null && allowedExtensions.isNotEmpty)
            ? FileType.custom
            : fileType,
        allowedExtensions: allowedExtensions,
        withData: kIsWeb,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => null,
      );
    } catch (pickerErr, stackTrace) {
      ErrorHandler.log(
        pickerErr,
        stackTrace: stackTrace,
        tag: 'CampaignWizardDevicePicker.pickFiles',
      );
      isUploadingNotifier.value = false;
      uploadStatusNotifier.value = '';
      AppSnackbar.error('Unable to open file selector. Please try again.');
      return;
    }

    if (result == null || result.files.isEmpty) {
      isUploadingNotifier.value = false;
      uploadStatusNotifier.value = '';
      return;
    }

    final pickedFile = result.files.first;
    final fileSize = pickedFile.size;

    final isVideoOrAudio = fileType == FileType.video ||
        fileType == FileType.audio ||
        fileType == FileType.media ||
        (allowedExtensions != null &&
            allowedExtensions.any(
              (e) => [
                'mp4',
                'mov',
                'webm',
                'mkv',
                'avi',
                'mp3',
                'wav',
                'm4a',
                'aac',
                'ogg',
              ].contains(e.toLowerCase()),
            ));

    // File size validation: 500MB for video/audio, 15MB for images
    final maxSizeBytes = isVideoOrAudio
        ? 500 * 1024 * 1024
        : 15 * 1024 * 1024;
    if (fileSize > maxSizeBytes) {
      isUploadingNotifier.value = false;
      uploadStatusNotifier.value = '';
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      AppSnackbar.show(
        'File Size Limit Exceeded',
        'Selected file is $sizeMb MB. The maximum allowed size is $maxMb MB.',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }

    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    final sizeStr = formatBytes(fileSize);
    uploadStatusNotifier.value = 'Inspecting media...';
    uploadProgressNotifier.value = 0.15;

    // Safe, non-blocking duration inspection
    double? extractedDurationSec;
    if (isVideoOrAudio) {
      try {
        if (kIsWeb) {
          if (pickedFile.bytes != null) {
            final ext = pickedFile.extension?.toLowerCase() ?? 'mp4';
            final mime = [
              'mp3',
              'wav',
              'm4a',
              'aac',
              'ogg',
            ].contains(ext)
                ? 'audio/$ext'
                : 'video/$ext';
            final blob = html.Blob([pickedFile.bytes], mime);
            final blobUrl = html.Url.createObjectUrlFromBlob(blob);
            try {
              final videoEl = html.VideoElement()
                ..src = blobUrl
                ..preload = 'metadata';
              await videoEl.onLoadedMetadata.first.timeout(
                const Duration(seconds: 3),
                onTimeout: () => html.Event('timeout'),
              );
              final dur = videoEl.duration;
              if (!dur.isNaN && !dur.isInfinite && dur > 0) {
                extractedDurationSec = dur.toDouble();
              }
            } catch (webProbeErr, stackTrace) {
              ErrorHandler.log(
                webProbeErr,
                stackTrace: stackTrace,
                tag: 'CampaignWizardDevicePicker.webDurationProbe',
              );
            } finally {
              html.Url.revokeObjectUrl(blobUrl);
            }
          }
        } else {
          if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
            final ioFile = io.File(pickedFile.path!);
            if (await ioFile.exists()) {
              VideoPlayerController? tempCtrl;
              try {
                tempCtrl = VideoPlayerController.file(ioFile);
                await tempCtrl.initialize().timeout(
                  const Duration(seconds: 4),
                  onTimeout: () {
                    debugPrint(
                      '[AdvertiserPortal] Native video player probe timed out',
                    );
                  },
                );
                if (tempCtrl.value.isInitialized) {
                  final durSec =
                      tempCtrl.value.duration.inMilliseconds / 1000.0;
                  if (durSec > 0) {
                    extractedDurationSec = durSec;
                  }
                }
              } catch (nativeProbeErr, stackTrace) {
                ErrorHandler.log(
                  nativeProbeErr,
                  stackTrace: stackTrace,
                  tag: 'CampaignWizardDevicePicker.nativeDurationProbe',
                );
              } finally {
                await tempCtrl?.dispose();
              }
            }
          }
        }
      } catch (durErr, stackTrace) {
        ErrorHandler.log(
          durErr,
          stackTrace: stackTrace,
          tag: 'CampaignWizardDevicePicker.extractDuration',
        );
      }

      // Validate duration limit if specified
      if (extractedDurationSec != null && maxDurationSeconds != null) {
        if (extractedDurationSec > maxDurationSeconds) {
          isUploadingNotifier.value = false;
          uploadStatusNotifier.value = '';
          final durFormatted = extractedDurationSec.toStringAsFixed(1);
          final limitFormatted = maxDurationSeconds.toStringAsFixed(0);
          AppSnackbar.show(
            'Media Exceeds Duration Limit',
            durationLimitWarningText ??
                'Selected media is $durFormatted seconds, which exceeds the $limitFormatted second limit.',
            backgroundColor: AppColors.error,
            colorText: Colors.white,
          );
          return;
        }
      }
    }

    var durationFormatted = '';
    if (extractedDurationSec != null && extractedDurationSec > 0) {
      final totalSecs = extractedDurationSec.round();
      final mins = totalSecs ~/ 60;
      final secs = totalSecs % 60;
      durationFormatted = '$mins:${secs.toString().padLeft(2, '0')}';
    }
    final metaInfo = durationFormatted.isNotEmpty
        ? '$sizeStr • $durationFormatted'
        : sizeStr;
    pickedMetaNotifier?.value = metaInfo;

    // Stream upload to Firebase Storage with real-time progress
    uploadStatusNotifier.value = 'Uploading to cloud storage...';
    uploadProgressNotifier.value = 0.2;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName = pickedFile.name.replaceAll(
      RegExp('[^a-zA-Z0-9._-]'),
      '_',
    );
    final storagePath = 'ad_campaigns_media/${timestamp}_$sanitizedName';
    final ext = pickedFile.extension?.toLowerCase() ?? '';

    var mimeType = 'application/octet-stream';
    if ([
      'mp4',
      'mov',
      'webm',
      'mkv',
      'avi',
      'm4v',
      '3gp',
    ].contains(ext)) {
      mimeType = 'video/mp4';
    } else if ([
      'mp3',
      'wav',
      'm4a',
      'aac',
      'ogg',
    ].contains(ext)) {
      mimeType = 'audio/mpeg';
    } else if (['jpg', 'jpeg'].contains(ext)) {
      mimeType = 'image/jpeg';
    } else if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    } else if (ext == 'gif') {
      mimeType = 'image/gif';
    }

    String? finalUrl;
    try {
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (kIsWeb) {
        if (pickedFile.bytes == null) {
          throw Exception('File bytes are null on Web platform');
        }
        uploadTask = storageRef.putData(
          pickedFile.bytes!,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {
              'uploaderId': ?currentUid,
            },
          ),
        );
      } else {
        if (pickedFile.path == null || pickedFile.path!.isEmpty) {
          throw Exception('File path is null on Native platform');
        }
        final ioFile = io.File(pickedFile.path!);
        uploadTask = storageRef.putFile(
          ioFile,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {
              'uploaderId': ?currentUid,
            },
          ),
        );
      }

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            uploadProgressNotifier.value = 0.2 + (progress * 0.75);
            uploadStatusNotifier.value =
                'Uploading ${(progress * 100).toStringAsFixed(0)}% (${formatBytes(snapshot.bytesTransferred)} / ${formatBytes(snapshot.totalBytes)})...';
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'CampaignWizardDevicePicker.uploadTask',
        ),
      );

      final taskSnapshot = await uploadTask;
      uploadStatusNotifier.value = 'Finalizing URL...';
      uploadProgressNotifier.value = 0.98;
      finalUrl = await taskSnapshot.ref.getDownloadURL();
    } catch (uploadErr, stackTrace) {
      ErrorHandler.log(
        uploadErr,
        stackTrace: stackTrace,
        tag: 'CampaignWizardDevicePicker.cloudStorageUpload',
      );
      if (!kIsWeb && pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        finalUrl = pickedFile.path;
      }
    }

    targetController.text = finalUrl ?? pickedFile.name;
    pickedFileNameNotifier.value = pickedFile.name;
    uploadProgressNotifier.value = 1.0;
    uploadStatusNotifier.value = 'Ready';
    isUploadingNotifier.value = false;

    AppSnackbar.show(
      'Media Attached Successfully',
      '${pickedFile.name} ($metaInfo) is ready for campaign launch.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  } catch (e) {
    ErrorHandler.log(e);
    isUploadingNotifier.value = false;
    uploadStatusNotifier.value = '';
    AppSnackbar.error(
      'Unable to process selected media. Please try again.',
    );
  }
}


/// Backward-compatible alias.
Future<void> pickDeviceMediaFile({
  required BuildContext context,
  required FileType fileType,
  required TextEditingController targetController,
  required RxString pickedFileNameNotifier,
  required RxBool isUploadingNotifier,
  required RxDouble uploadProgressNotifier,
  required RxString uploadStatusNotifier,
  RxString? pickedMetaNotifier,
  List<String>? allowedExtensions,
  double? maxDurationSeconds,
  String? durationLimitWarningText,
}) => pickCampaignDeviceMediaFile(
  context: context,
  fileType: fileType,
  targetController: targetController,
  pickedFileNameNotifier: pickedFileNameNotifier,
  isUploadingNotifier: isUploadingNotifier,
  uploadProgressNotifier: uploadProgressNotifier,
  uploadStatusNotifier: uploadStatusNotifier,
  pickedMetaNotifier: pickedMetaNotifier,
  allowedExtensions: allowedExtensions,
  maxDurationSeconds: maxDurationSeconds,
  durationLimitWarningText: durationLimitWarningText,
);
