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
          thumbnailUrl: thumbnailUrl,
          subtitle: subtitle,
          videoCount: videoCount,
          channelName: channelName,
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
