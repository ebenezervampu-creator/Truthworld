import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share/share_bottom_sheet_controller.dart';
import 'package:truthworld/components/ui/share/share_components.dart';

export 'package:truthworld/components/ui/share/panels/share_embed_panel.dart';
export 'package:truthworld/components/ui/share/share_bottom_sheet_controller.dart';
export 'package:truthworld/components/ui/share/share_components.dart';
export 'package:truthworld/components/ui/share/share_preview_cards.dart';

class ShareBottomSheet extends StatelessWidget {
  const ShareBottomSheet({
    required this.title,
    required this.url,
    super.key,
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

  static void show({
    required String title,
    required String url,
    String? thumbnailUrl,
    String? bannerUrl,
    String? subtitle,
    String? avatarUrl,
    int? durationMs,
    int? videoCount,
    int? subscriberCount,
    int? followerCount,
    String? handle,
    Duration? currentPosition,
    String? channelName,
    String? type,
    double? clipStartTime,
    double? clipEndTime,
    String? videoUrl,
    String? videoId,
    String? videoTitle,
  }) {
    Get.bottomSheet(
      ShareBottomSheet(
        title: title,
        url: url,
        thumbnailUrl: thumbnailUrl,
        bannerUrl: bannerUrl,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
        durationMs: durationMs,
        videoCount: videoCount,
        subscriberCount: subscriberCount,
        followerCount: followerCount,
        handle: handle,
        currentPosition: currentPosition,
        channelName: channelName,
        type: type,
        clipStartTime: clipStartTime,
        clipEndTime: clipEndTime,
        videoUrl: videoUrl,
        videoId: videoId,
        videoTitle: videoTitle,
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 300),
      exitBottomSheetDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ShareBottomSheetController>(
      init: ShareBottomSheetController(
        title: title,
        url: url,
        thumbnailUrl: thumbnailUrl,
        bannerUrl: bannerUrl,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
        durationMs: durationMs,
        videoCount: videoCount,
        subscriberCount: subscriberCount,
        followerCount: followerCount,
        handle: handle,
        currentPosition: currentPosition,
        channelName: channelName,
        type: type,
        clipStartTime: clipStartTime,
        clipEndTime: clipEndTime,
        videoUrl: videoUrl,
        videoId: videoId,
        videoTitle: videoTitle,
      ),
      builder: (controller) {
        final contentType = controller.detectType();

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Obx(() {
                if (controller.showEmbedPanel.value) {
                  return ShareEmbedPanel(
                    getIframeCode: controller.getIframeCode,
                    onBack: () => controller.showEmbedPanel.value = false,
                    showControls: controller.showControls,
                    privacyMode: controller.privacyMode,
                    startAtChecked: controller.startAtChecked,
                    currentPosition: currentPosition,
                  );
                }

                if (contentType == 'clip') {
                  return ShareTikTokClipPanel(
                    title: title,
                    url: url,
                    isPreparingClip: controller.isPreparingClip,
                    clipFile: controller.clipFile,
                    clipProgress: controller.clipProgress,
                    clipStatus: controller.clipStatus,
                    thumbnailUrl: thumbnailUrl,
                    bannerUrl: bannerUrl,
                    subtitle: subtitle,
                    avatarUrl: avatarUrl,
                    durationMs: durationMs,
                    videoCount: videoCount,
                    subscriberCount: subscriberCount,
                    followerCount: followerCount,
                    handle: handle,
                    channelName: channelName,
                    clipStartTime: clipStartTime,
                    clipEndTime: clipEndTime,
                    videoUrl: videoUrl,
                    videoId: videoId,
                    videoTitle: videoTitle,
                  );
                }

                return ShareMainPanel(
                  title: title,
                  url: url,
                  contentType: contentType,
                  startAtChecked: controller.startAtChecked,
                  showEmbedPanel: controller.showEmbedPanel,
                  isPreparingClip: controller.isPreparingClip,
                  clipFile: controller.clipFile,
                  clipStatus: controller.clipStatus,
                  thumbnailUrl: thumbnailUrl,
                  bannerUrl: bannerUrl,
                  subtitle: subtitle,
                  avatarUrl: avatarUrl,
                  durationMs: durationMs,
                  videoCount: videoCount,
                  subscriberCount: subscriberCount,
                  followerCount: followerCount,
                  handle: handle,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  videoTitle: videoTitle,
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
