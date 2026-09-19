import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/share/services/share_dispatcher.dart';
import 'package:truthworld/components/ui/share/share_preview_cards.dart';
import 'package:truthworld/components/ui/share/utils/share_utils.dart';
import 'package:truthworld/components/ui/share/widgets/share_social_icon.dart';
import 'package:truthworld/theme/app_theme.dart';

class ShareMainPanel extends StatelessWidget {
  const ShareMainPanel({
    required this.title,
    required this.url,
    required this.contentType,
    required this.startAtChecked,
    required this.showEmbedPanel,
    required this.isPreparingClip,
    required this.clipFile,
    required this.clipStatus,
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
    this.clipStartTime,
    this.clipEndTime,
    this.videoTitle,
  });

  final String title;
  final String url;
  final String contentType;
  final RxBool startAtChecked;
  final RxBool showEmbedPanel;
  final RxBool isPreparingClip;
  final Rxn<File> clipFile;
  final RxString clipStatus;
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
  final double? clipStartTime;
  final double? clipEndTime;
  final String? videoTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('main_panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: Get.back,
              ),
            ],
          ),
        ),

        const Divider(color: AppColors.bgDivider, height: 1),

        // 1. Preview Card
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: SharePreviewCard(
            contentType: contentType,
            title: title,
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
            clipFile: clipFile,
            clipStatus: clipStatus,
            isPreparingClip: isPreparingClip,
          ),
        ),

        // 2. Start At Checkbox (Video Only)
        if (contentType == 'video' && currentPosition != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Obx(
              () => Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: startAtChecked.value,
                      activeColor: AppColors.brand,
                      checkColor: AppColors.textPrimary,
                      side: const BorderSide(
                        color: AppColors.textSecondary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        startAtChecked.value = val ?? false;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      startAtChecked.value = !startAtChecked.value;
                    },
                    child: Text(
                      'Start at ${ShareUtils.formatDuration(currentPosition!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. Social Icons Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              ShareSocialIcon(
                imageAsset: 'assets/icons/whatsapp.png',
                label: 'WhatsApp',
                onTap: () => ShareDispatcher.shareToSocial(
                  platform: 'whatsapp',
                  title: title,
                  url: url,
                  startAtChecked: startAtChecked.value,
                  contentType: contentType,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  handle: handle,
                  videoTitle: videoTitle,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                ),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/facebook.png',
                label: 'Facebook',
                onTap: () => ShareDispatcher.shareToSocial(
                  platform: 'facebook',
                  title: title,
                  url: url,
                  startAtChecked: startAtChecked.value,
                  contentType: contentType,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  handle: handle,
                  videoTitle: videoTitle,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                ),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/x.png',
                label: 'X',
                onTap: () => ShareDispatcher.shareToSocial(
                  platform: 'twitter',
                  title: title,
                  url: url,
                  startAtChecked: startAtChecked.value,
                  contentType: contentType,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  handle: handle,
                  videoTitle: videoTitle,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                ),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/telegram.png',
                label: 'Telegram',
                onTap: () => ShareDispatcher.shareToSocial(
                  platform: 'telegram',
                  title: title,
                  url: url,
                  startAtChecked: startAtChecked.value,
                  contentType: contentType,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  handle: handle,
                  videoTitle: videoTitle,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                ),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/email.png',
                label: 'Email',
                onTap: () => ShareDispatcher.shareToSocial(
                  platform: 'email',
                  title: title,
                  url: url,
                  startAtChecked: startAtChecked.value,
                  contentType: contentType,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  handle: handle,
                  videoTitle: videoTitle,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                ),
              ),
              if (contentType == 'video')
                ShareSocialIcon(
                  icon: Icons.code_rounded,
                  label: 'Embed',
                  onTap: () => showEmbedPanel.value = true,
                ),
              ShareSocialIcon(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: () => ShareDispatcher.shareNative(
                  title: title,
                  url: url,
                  startAtChecked: startAtChecked.value,
                  contentType: contentType,
                  currentPosition: currentPosition,
                  channelName: channelName,
                  handle: handle,
                  videoTitle: videoTitle,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                ),
              ),
            ],
          ),
        ),

        // 4. Link Copy Section
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy Link',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => Text(
                          ShareUtils.getShareUrl(
                            url: url,
                            startAtChecked: startAtChecked.value,
                            currentPosition: currentPosition,
                          ),
                          style: GoogleFonts.robotoMono(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => ShareDispatcher.copyToClipboard(
                        url: url,
                        startAtChecked: startAtChecked.value,
                        currentPosition: currentPosition,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Copy'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
