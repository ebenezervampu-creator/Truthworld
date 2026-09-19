import 'dart:io';

import 'package:get/get.dart';
import 'package:truthworld/components/ui/share/share_components.dart';
import 'package:truthworld/core/base/base_controller.dart';

/// Controller managing reactive presentation state and clip export for ShareBottomSheet.
class ShareBottomSheetController extends BaseController {
  ShareBottomSheetController({
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.bannerUrl,
    this.subtitle,
    this.avatarUrl,
    this.durationMs,
    this.videoCount,
    this.subscriberCount,
    this.followerCount,
    this.handle,
    this.currentPosition,
    this.channelName,
    this.type,
    this.clipStartTime,
    this.clipEndTime,
    this.videoUrl,
    this.videoId,
    this.videoTitle,
  });

  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final String? subtitle;
  final String? avatarUrl;
  final int? durationMs;
  final int? videoCount;
  final int? subscriberCount;
  final int? followerCount;
  final String? handle;
  final Duration? currentPosition;
  final String? channelName;
  final String? type;
  final double? clipStartTime;
  final double? clipEndTime;
  final String? videoUrl;
  final String? videoId;
  final String? videoTitle;

  final RxBool startAtChecked = false.obs;
  final RxBool showEmbedPanel = false.obs;
  final RxBool showControls = true.obs;
  final RxBool privacyMode = false.obs;

  final RxBool isPreparingClip = false.obs;
  final Rxn<File> clipFile = Rxn<File>();
  final RxDouble clipProgress = 0.0.obs;
  final RxString clipStatus = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final contentType = detectType();
    if (contentType == 'clip') {
      ShareClipExporter.prepareClipFile(
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
    }
  }

  String detectType() {
    return ShareUtils.detectType(
      type: type,
      clipStartTime: clipStartTime,
      clipEndTime: clipEndTime,
      url: url,
      currentPosition: currentPosition,
      durationMs: durationMs,
      subscriberCount: subscriberCount,
      handle: handle,
      videoCount: videoCount,
      subtitle: subtitle,
      followerCount: followerCount,
    );
  }

  String getIframeCode() {
    return ShareUtils.getIframeCode(
      url: url,
      showControls: showControls.value,
      privacyMode: privacyMode.value,
      startAtChecked: startAtChecked.value,
      currentPosition: currentPosition,
    );
  }
}
