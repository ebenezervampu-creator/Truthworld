import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share/cards/share_cards_barrel.dart';

export 'package:truthworld/components/ui/share/cards/share_cards_barrel.dart';

/// Polymorphic preview card for social share dialogues and bottom sheets.
///
/// Dispatches rendering to dedicated sub-cards based on [contentType]:
/// - `'clip'`: [ShareClipCard]
/// - `'channel'`: [ShareChannelCard]
/// - `'playlist'`: [SharePlaylistCard]
/// - `'topic'`: [ShareTopicCard]
/// - `'claim'`: [ShareClaimCard]
/// - `'video'` (default): [ShareVideoCard]
class SharePreviewCard extends StatelessWidget {
  const SharePreviewCard({
    required this.contentType,
    required this.title,
    super.key,
    this.url,
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
    this.clipFile,
    this.clipStatus,
    this.isPreparingClip,
    this.claimText,
    this.verdictLabel,
    this.verdictColor,
    this.verdictIcon,
    this.summaryTakeaway,
    this.confidenceText,
    this.sourceDomain,
    this.videoTitle,
    this.onTap,
  });

  final String contentType;
  final String title;
  final String? url;
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
  final Rxn<File>? clipFile;
  final RxString? clipStatus;
  final RxBool? isPreparingClip;
  final String? claimText;
  final String? verdictLabel;
  final Color? verdictColor;
  final IconData? verdictIcon;
  final String? summaryTakeaway;
  final String? confidenceText;
  final String? sourceDomain;
  final String? videoTitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (contentType) {
      case 'clip':
        return ShareClipCard(
          title: title,
          thumbnailUrl: thumbnailUrl,
          durationMs: durationMs,
          channelName: channelName,
          clipStartTime: clipStartTime,
          clipEndTime: clipEndTime,
          clipFile: clipFile,
          clipStatus: clipStatus,
          isPreparingClip: isPreparingClip,
        );
      case 'channel':
        return ShareChannelCard(
          title: title,
          url: url,
          thumbnailUrl: thumbnailUrl,
          bannerUrl: bannerUrl,
          subtitle: subtitle,
          avatarUrl: avatarUrl,
          videoCount: videoCount,
          subscriberCount: subscriberCount,
          handle: handle,
          onTap: onTap,
        );
      case 'playlist':
        return SharePlaylistCard(
          title: title,
          url: url,
          thumbnailUrl: thumbnailUrl,
          subtitle: subtitle,
          videoCount: videoCount,
          channelName: channelName,
          onTap: onTap,
        );
      case 'topic':
        return ShareTopicCard(
          title: title,
          url: url,
          thumbnailUrl: thumbnailUrl,
          bannerUrl: bannerUrl,
          subtitle: subtitle,
          videoCount: videoCount,
          followerCount: followerCount,
          handle: handle,
          onTap: onTap,
        );
      case 'claim':
        return ShareClaimCard(
          title: title,
          claimText: claimText,
          videoTitle: videoTitle,
          channelName: channelName,
          url: url,
          thumbnailUrl: thumbnailUrl,
          verdictLabel: verdictLabel,
          verdictColor: verdictColor,
          verdictIcon: verdictIcon,
          summaryTakeaway: summaryTakeaway,
          confidenceText: confidenceText,
          sourceDomain: sourceDomain,
          onTap: onTap,
        );
      case 'video':
      default:
        return ShareVideoCard(
          title: title,
          url: url,
          thumbnailUrl: thumbnailUrl,
          subtitle: subtitle,
          durationMs: durationMs,
          channelName: channelName,
          onTap: onTap,
        );
    }
  }
}
