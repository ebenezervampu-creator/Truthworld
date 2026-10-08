import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/clip_share_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Preview card displaying a video clip ready to be shared with segment details and preparation state.
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
        mainAxisSize: MainAxisSize.min,
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
                      child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
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
                    '✨ Truthworld Video Clip',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isPreparingClip != null || clipFile != null || clipStatus != null)
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
