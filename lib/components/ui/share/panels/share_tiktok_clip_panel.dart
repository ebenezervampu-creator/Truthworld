import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share/services/share_clip_exporter.dart';
import 'package:truthworld/components/ui/share/share_preview_cards.dart';
import 'package:truthworld/components/ui/share/widgets/share_social_icon.dart';
import 'package:truthworld/theme/app_theme.dart';

class ShareTikTokClipPanel extends StatelessWidget {
  const ShareTikTokClipPanel({
    required this.title,
    required this.url,
    required this.isPreparingClip,
    required this.clipFile,
    required this.clipProgress,
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
    this.channelName,
    this.clipStartTime,
    this.clipEndTime,
    this.videoUrl,
    this.videoId,
    this.videoTitle,
  });

  final String title;
  final String url;
  final RxBool isPreparingClip;
  final Rxn<File> clipFile;
  final RxDouble clipProgress;
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
  final String? channelName;
  final double? clipStartTime;
  final double? clipEndTime;
  final String? videoUrl;
  final String? videoId;
  final String? videoTitle;

  void _exportAndShare(String target) {
    ShareClipExporter.exportAndShareClipVideo(
      title: title,
      url: url,
      isPreparingClip: isPreparingClip,
      clipFile: clipFile,
      clipProgress: clipProgress,
      clipStatus: clipStatus,
      target: target,
      clipStartTime: clipStartTime,
      clipEndTime: clipEndTime,
      durationMs: durationMs,
      videoId: videoId,
      videoUrl: videoUrl,
      channelName: channelName,
      videoTitle: videoTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('tiktok_clip_panel'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              const Text(
                'Share video clip to',
                style: TextStyle(
                  fontSize: 18,
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

        // Clip Preview Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SharePreviewCard(
            contentType: 'clip',
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

        // Section 1: TikTok Style Social Apps Row
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            'Share Video',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            children: [
              ShareSocialIcon(
                imageAsset: 'assets/icons/whatsapp.png',
                label: 'WhatsApp',
                onTap: () => _exportAndShare('whatsapp'),
              ),
              ShareSocialIcon(
                icon: Icons.camera_alt_rounded,
                label: 'Status',
                onTap: () => _exportAndShare('whatsapp_status'),
              ),
              ShareClipAppIcon(
                label: 'Instagram',
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF09433),
                    Color(0xFFE6683C),
                    Color(0xFFDC2743),
                    Color(0xFFCC2366),
                    Color(0xFFBC1888),
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onTap: () => _exportAndShare('instagram'),
              ),
              ShareClipAppIcon(
                label: 'TikTok',
                gradient: const LinearGradient(
                  colors: [Color(0xFF010101), Color(0xFF161616)],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 14,
                      top: 13,
                      child: Text(
                        '♪',
                        style: TextStyle(
                          color: Color(0xFF00F2EA),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 13,
                      top: 11,
                      child: Text(
                        '♪',
                        style: TextStyle(
                          color: Color(0xFFFF0050),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '♪',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                onTap: () => _exportAndShare('tiktok'),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/telegram.png',
                label: 'Telegram',
                onTap: () => _exportAndShare('telegram'),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/facebook.png',
                label: 'Facebook',
                onTap: () => _exportAndShare('facebook'),
              ),
              ShareSocialIcon(
                imageAsset: 'assets/icons/x.png',
                label: 'X',
                onTap: () => _exportAndShare('x'),
              ),
              ShareSocialIcon(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: () => _exportAndShare('more'),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: AppColors.bgDivider, height: 16),
        ),

        // Section 2: Actions Row (Save Video, Copy Link, Share Link)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            'Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
          child: Row(
            children: [
              ShareTikTokActionButton(
                icon: Icons.download_rounded,
                label: 'Save Video',
                onTap: () => ShareClipExporter.saveClipToDevice(
                  title: title,
                  url: url,
                  clipProgress: clipProgress,
                  clipStatus: clipStatus,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                  videoId: videoId,
                  videoUrl: videoUrl,
                ),
              ),
              ShareTikTokActionButton(
                icon: Icons.link_rounded,
                label: 'Copy Link',
                onTap: () => ShareClipExporter.copyClipLink(
                  title: title,
                  url: url,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                  videoId: videoId,
                ),
              ),
              ShareTikTokActionButton(
                icon: Icons.share_outlined,
                label: 'Share Link',
                onTap: () => ShareClipExporter.shareLinkOnly(
                  title: title,
                  url: url,
                  clipStartTime: clipStartTime,
                  clipEndTime: clipEndTime,
                  durationMs: durationMs,
                  videoId: videoId,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
