import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/components/ui/share/dialogs/share_dialogs.dart';
import 'package:truthworld/components/ui/share/services/share_dispatcher.dart';
import 'package:truthworld/components/ui/share/utils/share_utils.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/clip_share_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

class ShareClipExporter {
  const ShareClipExporter._();

  static Future<File?> prepareClipFile({
    required String title,
    required String url,
    required RxBool isPreparingClip,
    required Rxn<File> clipFile,
    required RxDouble clipProgress,
    required RxString clipStatus,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
    String? videoId,
    String? videoUrl,
    String? channelName,
    String? videoTitle,
  }) async {
    const canGenerateVideo = !kIsWeb;
    if (!canGenerateVideo) return null;

    if (clipFile.value != null && await clipFile.value!.exists()) {
      return clipFile.value;
    }
    isPreparingClip.value = true;
    clipProgress.value = 0.1;
    clipStatus.value = 'Preparing TikTok-style Truthworld clip...';

    final start = clipStartTime ?? 0.0;
    final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
    final vId = videoId ?? ShareUtils.extractVideoId(url);

    try {
      final file = await ClipShareService.instance.getOrGenerateClipFile(
        videoId: vId,
        videoUrl: videoUrl,
        channelName: channelName,
        videoTitle: videoTitle ?? title,
        clipTitle: title,
        startSeconds: start,
        endSeconds: end,
        onProgress: (progress, status) {
          clipProgress.value = progress;
          clipStatus.value = status;
        },
      );
      if (file != null && await file.exists()) {
        clipFile.value = file;
        clipProgress.value = 1.0;
        clipStatus.value = 'Clip ready!';
        return file;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ShareClipExporter.prepareClipFile',
      );
    } finally {
      isPreparingClip.value = false;
    }
    return null;
  }

  static Future<void> exportAndShareClipVideo({
    required String title,
    required String url,
    required RxBool isPreparingClip,
    required Rxn<File> clipFile,
    required RxDouble clipProgress,
    required RxString clipStatus,
    String? target,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
    String? videoId,
    String? videoUrl,
    String? channelName,
    String? videoTitle,
  }) async {
    final start = clipStartTime ?? 0.0;
    final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
    final vId = videoId ?? ShareUtils.extractVideoId(url);

    final shareUrl = ClipShareService.buildClipUrl(
      videoId: vId,
      startSeconds: start,
      endSeconds: end,
      clipTitle: title,
    );

    final caption = ClipShareService.buildWatermarkCaption(
      clipTitle: title,
      videoTitle: videoTitle ?? title,
      channelName: channelName,
      startSeconds: start,
      endSeconds: end,
      clipUrl: shareUrl,
    );

    const canGenerateVideo = !kIsWeb;
    var file = clipFile.value;
    var cancelled = false;

    if (canGenerateVideo && (file == null || !await file.exists())) {
      ShareDialogs.showTikTokExportDialog(
        title: 'Exporting TikTok-style clip...',
        progress: clipProgress,
        status: clipStatus,
        onCancel: () => cancelled = true,
      );

      file = await prepareClipFile(
        title: title,
        url: url,
        isPreparingClip: isPreparingClip,
        clipFile: clipFile,
        clipProgress: clipProgress,
        clipStatus: clipStatus,
        clipStartTime: clipStartTime,
        clipEndTime: clipEndTime,
        durationMs: durationMs,
        videoId: videoId,
        videoUrl: videoUrl,
        channelName: channelName,
        videoTitle: videoTitle,
      );

      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
    }

    if (cancelled) return;

    final hasVideo = file != null && await file.exists();
    if (canGenerateVideo && !hasVideo) {
      AppSnackbar.info(
        'Video file could not be generated. Sharing clip link instead.',
        title: 'Sharing Clip',
      );
    }

    final xFile = hasVideo
        ? XFile(
            file.path,
            mimeType: 'video/mp4',
            name: '$title (Truthworld Clip).mp4',
          )
        : null;

    Future<void> shareVideoFile() async {
      if (Get.isBottomSheetOpen ?? false) Get.back<void>();
      if (xFile != null) {
        await SharePlus.instance.share(
          ShareParams(files: [xFile], text: caption, subject: title),
        );
      } else if (kIsWeb) {
        var sourceUrl = videoUrl;
        if (sourceUrl == null || sourceUrl.isEmpty) {
          sourceUrl =
              await ClipShareService.instance.resolveVideoSourceUrl(vId);
        }
        if (sourceUrl != null && sourceUrl.isNotEmpty) {
          final safeTitle = title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
          await DownloadHelper.downloadFromUrl(
            sourceUrl,
            'Truthworld_${safeTitle}_Clip.mp4',
          );
        }
        await ShareDispatcher.shareDirectToPlatform(
          platform: target ?? 'more',
          caption: caption,
          shareUrl: shareUrl,
          title: title,
        );
      } else {
        await ShareDispatcher.shareDirectToPlatform(
          platform: target ?? 'more',
          caption: caption,
          shareUrl: shareUrl,
          title: title,
        );
      }
    }

    if (kIsWeb && (target == 'whatsapp' || target == 'whatsapp_status')) {
      await ShareDialogs.showAppGuideDialog(
        emoji: '🎬',
        appName: 'WhatsApp',
        iconColor: const Color(0xFF25D366),
        steps: '1. Your video clip is downloading to your computer.\n\n'
            '2. In WhatsApp, click 📎 (Attach) > Photos & Videos.\n\n'
            '3. Select the downloaded clip to send it directly as a video message!',
        confirmText: 'Got it — Open WhatsApp',
        confirmColor: const Color(0xFF25D366),
      );
      await shareVideoFile();
      return;
    }

    if (xFile == null && !kIsWeb) {
      await shareVideoFile();
      return;
    }

    switch (target) {
      case 'whatsapp_status':
        await ShareDialogs.showWhatsAppStatusGuideDialog();
        await shareVideoFile();

      case 'instagram':
        await ShareDialogs.showAppGuideDialog(
          emoji: '📸',
          appName: 'Instagram',
          iconColor: const Color(0xFFDC2743),
          steps: 'Your Truthworld clip will open in the share sheet.\n\n'
              'In the share sheet:\n'
              '1. Tap "Instagram"\n'
              '2. Select "Reels" or "Story" to post the clip',
          confirmText: 'Got it — Open Instagram',
          confirmColor: const Color(0xFFBC1888),
        );
        await shareVideoFile();

      case 'tiktok':
        await ShareDialogs.showAppGuideDialog(
          emoji: '🎵',
          appName: 'TikTok',
          iconColor: const Color(0xFF010101),
          steps:
              'Your Truthworld watermarked clip will open in the share sheet.\n\n'
              'In the share sheet:\n'
              '1. Tap "TikTok"\n'
              '2. TikTok opens the video in its editor — add caption and post!',
          confirmText: 'Got it — Open TikTok',
          confirmColor: const Color(0xFFFF0050),
        );
        await shareVideoFile();

      default:
        await shareVideoFile();
    }
  }

  static Future<void> saveClipToDevice({
    required String title,
    required String url,
    required RxDouble clipProgress,
    required RxString clipStatus,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
    String? videoId,
    String? videoUrl,
  }) async {
    final start = clipStartTime ?? 0.0;
    final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
    final vId = videoId ?? ShareUtils.extractVideoId(url);

    if (kIsWeb) {
      if (Get.isBottomSheetOpen ?? false) Get.back<void>();
      var sourceUrl = videoUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        sourceUrl = await ClipShareService.instance.resolveVideoSourceUrl(vId);
      }
      if (sourceUrl != null && sourceUrl.isNotEmpty) {
        final safeTitle = title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
        await DownloadHelper.downloadFromUrl(
          sourceUrl,
          'Truthworld_${safeTitle}_Clip.mp4',
        );
        AppSnackbar.success(
          'Truthworld video clip is downloading to your computer.',
          title: 'Downloading Clip',
        );
        return;
      }
    }

    var cancelled = false;

    ShareDialogs.showTikTokExportDialog(
      title: 'Saving video to gallery...',
      progress: clipProgress,
      status: clipStatus,
      onCancel: () => cancelled = true,
    );

    final savedPath = await ClipShareService.instance.saveClipToDevice(
      videoId: vId,
      clipTitle: title,
      videoUrl: videoUrl,
      startSeconds: start,
      endSeconds: end,
      onProgress: (progress, status) {
        clipProgress.value = progress;
        clipStatus.value = status;
      },
    );

    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }

    if (cancelled) return;

    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }

    if (savedPath != null) {
      AppSnackbar.success(
        'Truthworld watermarked video clip saved successfully',
        title: 'Saved to Gallery',
      );
    } else {
      AppSnackbar.error(
        'Could not save video clip to device. Please try again.',
      );
    }
  }

  static void copyClipLink({
    required String title,
    required String url,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
    String? videoId,
  }) {
    final start = clipStartTime ?? 0.0;
    final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
    final vId = videoId ?? ShareUtils.extractVideoId(url);
    final clipUrl = ClipShareService.buildClipUrl(
      videoId: vId,
      startSeconds: start,
      endSeconds: end,
      clipTitle: title,
    );

    Clipboard.setData(ClipboardData(text: clipUrl));
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
    AppSnackbar.info(
      'Clip link copied to clipboard',
      title: 'Copied',
    );
  }

  static void shareLinkOnly({
    required String title,
    required String url,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
    String? videoId,
  }) {
    final start = clipStartTime ?? 0.0;
    final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
    final vId = videoId ?? ShareUtils.extractVideoId(url);
    final clipUrl = ClipShareService.buildClipUrl(
      videoId: vId,
      startSeconds: start,
      endSeconds: end,
      clipTitle: title,
    );

    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }

    SharePlus.instance.share(
      ShareParams(
        text: 'Watch "$title" clip on Truthworld:\n$clipUrl',
        subject: title,
      ),
    );
  }
}
