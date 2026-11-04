import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/storyboard_thumbnail_widget.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_share_card.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check/fact_check_epistemic_banner.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet displaying AI Credibility Claims structured exactly
/// as Video Chapters based on chronological timestamps.
class VideoClaimsChaptersBottomSheet extends StatelessWidget {
  const VideoClaimsChaptersBottomSheet({
    required this.video,
    super.key,
    this.videoTag,
  });

  final Video video;
  final String? videoTag;

  static void show(
    BuildContext context, {
    required Video video,
    String? videoTag,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            VideoClaimsChaptersBottomSheet(video: video, videoTag: videoTag),
      ),
    );
  }

  TowerPlayerController? _getPlayerController() {
    try {
      if (videoTag != null &&
          Get.isRegistered<TowerPlayerController>(tag: videoTag)) {
        return Get.find<TowerPlayerController>(tag: videoTag);
      }
      if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
        return Get.find<TowerPlayerController>(tag: video.id);
      }
      if (Get.isRegistered<TowerPlayerController>()) {
        return Get.find<TowerPlayerController>();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoClaimsChaptersBottomSheet.getPlayerController',
      );
    }
    return null;
  }

  List<ClaimResult> _getTimestampedClaims(TowerPlayerController? playerCtrl) {
    if (playerCtrl != null && playerCtrl.timestampedClaims.isNotEmpty) {
      return playerCtrl.timestampedClaims;
    }

    final keyClaims = video.uiReport?.keyClaims;
    if (keyClaims != null && keyClaims.isNotEmpty) {
      final list = List<ClaimResult>.from(keyClaims);
      list.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));
      return list;
    }

    VideoController? vc;
    try {
      if (videoTag != null && Get.isRegistered<VideoController>(tag: videoTag)) {
        vc = Get.find<VideoController>(tag: videoTag);
      } else if (Get.isRegistered<VideoController>()) {
        vc = Get.find<VideoController>();
      }
    } catch (_) {}

    final rawClaims = vc?.factCheckData['claims'] ??
        vc?.factCheckData['uiReport']?['keyClaims'];
    if (rawClaims is List && rawClaims.isNotEmpty) {
      final list = rawClaims
          .map((c) => ClaimResult.fromMap(
                Map<String, dynamic>.from(
                  c is Map ? c : {'text': c.toString()},
                ),
              ))
          .toList();
      list.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));
      return list;
    }

    return const <ClaimResult>[];
  }

  @override
  Widget build(BuildContext context) {
    final playerCtrl = _getPlayerController();
    final claims = _getTimestampedClaims(playerCtrl);
    final selectedFilter = 'All'.obs;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Drag Indicator Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.fact_check_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Credibility Chapters',
                          style: context.twTypography.headline.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF162A45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            claims.length.toString(),
                            style: const TextStyle(
                              color: AppColors.textLink,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Capsules (All, Verified, Caution, Contradicted)
              if (claims.isNotEmpty)
                _buildFilterBar(context, claims, selectedFilter),

              const Divider(height: 1, color: AppColors.bgDivider),

              // Claims Chapter List
              Expanded(
                child: claims.isEmpty
                    ? Center(
                        child: Text(
                          'No credibility claims available for this video',
                          style: context.twTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : Obx(() {
                        final filter = selectedFilter.value;
                        final filteredList = claims.where((c) {
                          if (filter == 'All') return true;
                          final v = ClaimVerdictHelper.resolveVerdict(c);
                          if (filter == 'Verified') return v.isVerified;
                          if (filter == 'Caution') return v.isCaution;
                          if (filter == 'False') return v.isFalse;
                          return true;
                        }).toList();

                        if (filteredList.isEmpty) {
                          return Center(
                            child: Text(
                              'No claims match the "$filter" filter',
                              style: context.twTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredList.length + 1,
                          itemBuilder: (context, index) {
                            if (index == filteredList.length) {
                              return const Padding(
                                padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                                child: FactCheckEpistemicBanner(),
                              );
                            }
                            final claim = filteredList[index];
                            return ClaimChapterTile(
                              claim: claim,
                              video: video,
                              playerCtrl: playerCtrl,
                              index: index,
                            );
                          },
                        );
                      }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    List<ClaimResult> claims,
    RxString selectedFilter,
  ) {
    var verified = 0;
    var caution = 0;
    var falseCount = 0;

    for (final c in claims) {
      final v = ClaimVerdictHelper.resolveVerdict(c);
      if (v.isVerified) {
        verified++;
      } else if (v.isCaution) {
        caution++;
      } else if (v.isFalse) {
        falseCount++;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() {
          final current = selectedFilter.value;
          return Row(
            children: [
              _buildFilterPill('All', 'All (${claims.length})', current, selectedFilter),
              if (verified > 0) ...[
                const SizedBox(width: 8),
                _buildFilterPill('Verified', 'Verified ($verified)', current, selectedFilter,
                    accentColor: const Color(0xFF4CAF50)),
              ],
              if (caution > 0) ...[
                const SizedBox(width: 8),
                _buildFilterPill('Caution', 'Caution ($caution)', current, selectedFilter,
                    accentColor: const Color(0xFFFFB300)),
              ],
              if (falseCount > 0) ...[
                const SizedBox(width: 8),
                _buildFilterPill('False', 'Contradicted ($falseCount)', current, selectedFilter,
                    accentColor: const Color(0xFFFF5252)),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFilterPill(
    String filterKey,
    String label,
    String currentSelected,
    RxString selectedFilter, {
    Color? accentColor,
  }) {
    final isSelected = currentSelected == filterKey;
    final dotColor = accentColor ?? AppColors.textLink;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => selectedFilter.value = filterKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSurfaceHover : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? dotColor : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accentColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Claim Chapter Tile displaying thumbnail, timestamp, statement, verdict pill,
/// citations, and instant seek interaction.
class ClaimChapterTile extends StatelessWidget {
  const ClaimChapterTile({
    required this.claim,
    required this.video,
    super.key,
    this.playerCtrl,
    this.index = 0,
    this.onTapOverride,
  });

  final ClaimResult claim;
  final Video video;
  final TowerPlayerController? playerCtrl;
  final int index;
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context) {
    final ctrl = playerCtrl;
    if (ctrl == null) {
      return _buildContent(context, isCurrent: false);
    }
    return Obx(() {
      final active = ctrl.activeClaim.value;
      final isCurrent = active != null &&
          (active == claim ||
              (active.start == claim.start && active.text == claim.text));
      return _buildContent(context, isCurrent: isCurrent);
    });
  }

  Widget _buildContent(BuildContext context, {required bool isCurrent}) {
    final verdict = ClaimVerdictHelper.resolveVerdict(claim);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTapOverride ??
          () {
            if (playerCtrl != null) {
              unawaited(playerCtrl!.seekTo(claim.startDuration));
              playerCtrl!.videoPlayerController.play();
              playerCtrl!.activeClaim.value = claim;
              playerCtrl!.showToast('Playing: ${verdict.label}');
            }
          },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.bgSurfaceHover : Colors.transparent,
          border: isCurrent
              ? Border(
                  left: BorderSide(
                    color: verdict.color,
                    width: 3.5,
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim Thumbnail Container with Verdict Badge Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 130,
                    height: 74,
                    color: AppColors.bgInput,
                    child: _buildClaimThumbnailWidget(),
                  ),
                ),
                // Verdict Overlay Chip on Thumbnail
                Positioned(
                  bottom: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: verdict.color.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          verdict.icon,
                          color: verdict.color,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          verdict.label,
                          style: TextStyle(
                            color: verdict.color,
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
            const SizedBox(width: 12),

            // Middle Column: Claim Statement, Meta, Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Meta Row: Index & Confidence
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (claim.classificationConfidence != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${(claim.classificationConfidence! * 100).round()}% AI Conf.',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: verdict.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              color: verdict.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Claim Statement
                  Text(
                    claim.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      height: 1.25,
                    ),
                  ),

                  // Source attribution line
                  if (claim.effectiveSources.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          size: 11,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            claim.effectiveSources.first.domain ??
                                claim.effectiveSources.first.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Action Icons when Active
                  if (isCurrent) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Share Claim Card Button
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            ClaimShareService.shareClaim(
                              context: context,
                              video: video,
                              claimText: claim.text,
                              verdict: verdict,
                              primarySourceDomain: claim.effectiveSources.isNotEmpty
                                  ? claim.effectiveSources.first.domain
                                  : null,
                              claimIndex: index,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.share_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Replay Segment Button
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            if (playerCtrl != null) {
                              unawaited(playerCtrl!.seekTo(claim.startDuration));
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.repeat_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Provide Evidence Action
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            ClaimSourceSubmissionDialog.show(
                              context: context,
                              video: video,
                              claimText: claim.text,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.add_link_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF162A45),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                claim.formattedStartTime,
                style: const TextStyle(
                  color: AppColors.textLink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimThumbnailWidget() {
    // 1. Dedicated custom/resolved claim thumbnail (must be distinct from video main cover)
    final hasDedicatedClaimThumbnail = claim.thumbnailUrl != null &&
        claim.thumbnailUrl!.trim().isNotEmpty &&
        claim.thumbnailUrl != video.thumbnailUrl;

    if (hasDedicatedClaimThumbnail) {
      return CachedNetworkImage(
        imageUrl: claim.thumbnailUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 260,
        memCacheHeight: 148,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
      );
    }

    // 2. Matching video chapter thumbnail if this claim falls into a chapter with a dedicated thumbnail
    if (video.chapters.isNotEmpty && claim.start != null) {
      final claimTime = claim.startDuration;
      VideoChapter? matched;
      for (final ch in video.chapters) {
        if (ch.startTime <= claimTime) {
          if (matched == null || ch.startTime > matched.startTime) {
            matched = ch;
          }
        }
      }
      if (matched != null &&
          matched.thumbnailUrl != null &&
          matched.thumbnailUrl!.trim().isNotEmpty &&
          matched.thumbnailUrl != video.thumbnailUrl) {
        return CachedNetworkImage(
          imageUrl: matched.thumbnailUrl!,
          fit: BoxFit.cover,
          memCacheWidth: 260,
          memCacheHeight: 148,
          placeholder: (context, url) => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      }
    }

    // 3. High-density storyboard frame preview at claim.startDuration
    final track = playerCtrl?.storyboardTrack.value ??
        ((video.storyboardUrl.isNotEmpty ||
                video.storyboardVariants.isNotEmpty ||
                video.thumbnailVariants.isNotEmpty)
            ? StoryboardService.generateHighDensityTrack(
                totalDuration: video.durationValue,
                multiSheetUrls: video.storyboardVariants,
                singleSheetUrl: video.storyboardUrl,
                thumbnailVariants: video.thumbnailVariants,
              )
            : null);

    if (track != null && track.isNotEmpty && claim.start != null) {
      return StoryboardThumbnailWidget(
        position: claim.startDuration,
        storyboardTrack: track,
        fallbackThumbnailUrl: video.thumbnailUrl,
        width: 130,
        height: 74,
        borderRadius: BorderRadius.zero,
      );
    }

    // 4. Fallback to main video cover thumbnail
    if (video.thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: video.thumbnailUrl,
        fit: BoxFit.cover,
        memCacheWidth: 260,
        memCacheHeight: 148,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.play_circle_outline,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
