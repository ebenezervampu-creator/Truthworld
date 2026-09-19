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
  });

  final String contentType;
  final String title;
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
          thumbnailUrl: thumbnailUrl,
          bannerUrl: bannerUrl,
          subtitle: subtitle,
          avatarUrl: avatarUrl,
          videoCount: videoCount,
          subscriberCount: subscriberCount,
          handle: handle,
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
          thumbnailUrl: thumbnailUrl,
          subtitle: subtitle,
          videoCount: videoCount,
          followerCount: followerCount,
          handle: handle,
        );
      case 'video':
      default:
        return ShareVideoCard(
          title: title,
          thumbnailUrl: thumbnailUrl,
          subtitle: subtitle,
          durationMs: durationMs,
          channelName: channelName,
        );
    }
  }
}
