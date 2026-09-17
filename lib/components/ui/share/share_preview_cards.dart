import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/clip_share_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/theme/app_theme.dart';

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } else {
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

String _formatMsDuration(int ms) {
  return _formatDuration(Duration(milliseconds: ms));
}

String _formatCount(int count) {
  if (count < 0) return '0';
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return count.toString();
}

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

class ShareClipCard extends StatelessWidget {
  const ShareClipCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.durationMs,
    this.channelName,
    this.clipStartTime,
    this.clipEndTime,
    this.clipFile,
    this.clipStatus,
    this.isPreparingClip,
  });

  final String title;
  final String? thumbnailUrl;
  final int? durationMs;
  final String? channelName;
  final double? clipStartTime;
  final double? clipEndTime;
  final Rxn<File>? clipFile;
  final RxString? clipStatus;
  final RxBool? isPreparingClip;

  @override
  Widget build(BuildContext context) {
    final start = clipStartTime ?? 0.0;
        final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
        final segment = ClipShareService.formatClipSegment(start, end);
    
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgSurfaceHover,
                AppColors.bgSurfaceHover.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Clip Thumbnail with overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 124,
                          height: 124 * 9 / 16,
                          color: AppColors.bgInput,
                          child: thumbnailUrl != null &&
                                  thumbnailUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: AppColors.bgInput),
                                  errorWidget: (context, url, err) => const Center(
                                    child: Icon(
                                      Icons.content_cut_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.content_cut_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.bgDivider,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.content_cut,
                                color: Colors.white,
                                size: 9,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                FormatUtils.formatDuration(
                                  Duration(seconds: (end - start).toInt()),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
    
                  // Clip Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                'CLIP',
                                style: TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                channelName ?? 'TruthWorld Creator',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Segment: $segment',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Verified Truthworld Watermark Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgPage.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '✨ Truthworld Watermarked Video Clip',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Obx(() {
                      if (isPreparingClip?.value ?? false) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 1.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ((clipStatus?.value ?? '').isNotEmpty)
                                  ? (clipStatus?.value ?? '')
                                  : 'Preparing...',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        );
                      }
                      if (clipFile?.value != null) {
                        return const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ready to share',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

class ShareVideoCard extends StatelessWidget {
  const ShareVideoCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.subtitle,
    this.durationMs,
    this.channelName,
  });

  final String title;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? durationMs;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgSurfaceHover,
                AppColors.bgSurfaceHover.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Video Thumbnail + Duration Overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 124,
                      height: 124 * 9 / 16,
                      color: AppColors.bgInput,
                      child:
                          thumbnailUrl != null &&
                              thumbnailUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.bgInput),
                              errorWidget: (context, url, err) => const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                    ),
                  ),
                  if (durationMs != null)
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.bgDivider,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _formatMsDuration(durationMs!),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
    
              // Video Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            channelName ?? 'TruthWorld Creator',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

class ShareChannelCard extends StatelessWidget {
  const ShareChannelCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.bannerUrl,
    this.subtitle,
    this.avatarUrl,
    this.videoCount,
    this.subscriberCount,
    this.handle,
  });

  final String title;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final String? subtitle;
  final String? avatarUrl;
  final int? videoCount;
  final int? subscriberCount;
  final String? handle;

  @override
  Widget build(BuildContext context) {
    final effectiveBanner = bannerUrl != null && bannerUrl!.isNotEmpty
            ? bannerUrl
            : (thumbnailUrl != null &&
                    thumbnailUrl != avatarUrl &&
                    thumbnailUrl!.isNotEmpty
                ? thumbnailUrl
                : null);
        final effectiveAvatar = avatarUrl != null && avatarUrl!.isNotEmpty
            ? avatarUrl
            : thumbnailUrl;
        final cleanHandle = handle != null && handle!.isNotEmpty
            ? (handle!.startsWith('@')
                ? handle!
                : '@${handle!}')
            : '@channel';
    
        final hasBanner = effectiveBanner != null && effectiveBanner.isNotEmpty;
    
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasBanner)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner Image (16:9 widescreen header)
                    SizedBox(
                      height: 90,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: effectiveBanner,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ColoredBox(
                          color: AppColors.bgInput,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, err) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.brand.withValues(alpha: 0.6),
                                AppColors.bgSurface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gradient Shadow Overlay on Banner bottom
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Channel Badge in Top Right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tv_rounded, color: Colors.white, size: 11),
                            SizedBox(width: 4),
                            Text(
                              'CHANNEL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    
              // Channel Details Body
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Circular Avatar
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgSurface,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 46,
                          height: 46,
                          color: AppColors.bgInput,
                          child: effectiveAvatar != null && effectiveAvatar.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: effectiveAvatar,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: AppColors.bgInput),
                                  errorWidget: (context, url, err) => const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
    
                    // Text Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                cleanHandle,
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: AppColors.textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${subscriberCount != null ? '${_formatCount(subscriberCount!)} subscribers' : 'Channel'} • ${videoCount != null ? '$videoCount videos' : 'TruthWorld'}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!.trim(),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

class SharePlaylistCard extends StatelessWidget {
  const SharePlaylistCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.subtitle,
    this.videoCount,
    this.channelName,
  });

  final String title;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? videoCount;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgSurfaceHover,
                AppColors.bgSurfaceHover.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Playlist Thumbnail + Overlay Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 124,
                      height: 124 * 9 / 16,
                      color: AppColors.bgInput,
                      child:
                          thumbnailUrl != null &&
                              thumbnailUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.bgInput),
                              errorWidget: (context, url, err) => const Icon(
                                Icons.playlist_play_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            )
                          : const Icon(
                              Icons.playlist_play_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                    ),
                  ),
                  // Truthworld-style playlist right side overlay bar
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 38,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.75),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${videoCount ?? 0}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            Icons.playlist_play_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
    
              // Playlist Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'PLAYLIST',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            channelName ?? 'TruthWorld Playlist',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ??
                          'Playlist • ${videoCount ?? 0} videos',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

class ShareTopicCard extends StatelessWidget {
  const ShareTopicCard({
    required this.title,
    super.key,
    this.thumbnailUrl,
    this.subtitle,
    this.videoCount,
    this.followerCount,
    this.handle,
  });

  final String title;
  final String? thumbnailUrl;
  final String? subtitle;
  final int? videoCount;
  final int? followerCount;
  final String? handle;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgSurfaceHover,
                AppColors.bgSurfaceHover.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Topic Thumbnail with brand border ring + Hashtag badge overlay
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 124,
                        height: 124 * 9 / 16,
                        color: AppColors.bgInput,
                        child:
                            thumbnailUrl != null &&
                                thumbnailUrl!.isNotEmpty
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, err) =>
                                        Container(color: AppColors.bgInput),
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.65),
                                  ),
                                  CachedNetworkImage(
                                    imageUrl: thumbnailUrl!,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.bgInput),
                                    errorWidget: (context, url, err) => const Center(
                                      child: Icon(
                                        Icons.tag_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: Icon(
                                  Icons.tag_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bgPage.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
    
              // Topic Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'TOPIC',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            handle != null && handle!.isNotEmpty
                                ? (handle!.startsWith('#') ||
                                          handle!.startsWith('T/') ||
                                          handle!.startsWith('t/')
                                      ? handle!
                                      : '#${handle!}')
                                : '#topic',
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ??
                          '${followerCount != null ? '${_formatCount(followerCount!)} followers' : 'Topic'} • ${videoCount != null ? '$videoCount videos' : 'TruthWorld'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}
