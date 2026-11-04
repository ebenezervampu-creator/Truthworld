import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// High-fidelity preview card displaying a fact-checked claim according to TruthWorld social preview architecture:
/// - 16:9 widescreen video context thumbnail with [FACT CHECK] and verdict pill overlays
/// - Quotation styling for the claim statement (bold, white)
/// - Fact-check verdict takeaway card with confidence & primary source domain
/// - Truthworld footer with link icon & chevron
/// - Interactive tap to navigate directly to Truthworld claim verification
class ShareClaimCard extends StatelessWidget {
  const ShareClaimCard({
    required this.title,
    super.key,
    this.claimText,
    this.videoTitle,
    this.channelName,
    this.url,
    this.thumbnailUrl,
    this.verdictLabel,
    this.verdictColor,
    this.verdictIcon,
    this.summaryTakeaway,
    this.confidenceText,
    this.sourceDomain,
    this.onTap,
  });

  final String title;
  final String? claimText;
  final String? videoTitle;
  final String? channelName;
  final String? url;
  final String? thumbnailUrl;
  final String? verdictLabel;
  final Color? verdictColor;
  final IconData? verdictIcon;
  final String? summaryTakeaway;
  final String? confidenceText;
  final String? sourceDomain;
  final VoidCallback? onTap;

  void _handleNavigate() {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
    if (url != null && url!.isNotEmpty) {
      DeepLinkService.instance.handleDeepLink(url!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveClaim = (claimText != null && claimText!.trim().isNotEmpty)
        ? claimText!.trim()
        : title.trim();

    final effectiveVideoTitle = (videoTitle != null && videoTitle!.trim().isNotEmpty)
        ? videoTitle!.trim()
        : (channelName != null && channelName!.trim().isNotEmpty
            ? channelName!.trim()
            : 'Truthworld Video Verification');

    final effectiveVerdictLabel = (verdictLabel != null && verdictLabel!.trim().isNotEmpty)
        ? verdictLabel!.trim()
        : 'FACT CHECK';

    final effectiveVerdictColor = verdictColor ?? const Color(0xFFF59E0B);
    final effectiveVerdictIcon = verdictIcon ?? Icons.verified_user_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (url != null && url!.isNotEmpty) || onTap != null ? _handleNavigate : null,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161719),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Section: Video Thumbnail with Badges
              SizedBox(
                height: 125,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildThumbnailFallback(effectiveVerdictColor),
                        errorWidget: (context, url, err) => _buildThumbnailFallback(effectiveVerdictColor),
                      )
                    else
                      _buildThumbnailFallback(effectiveVerdictColor),

                    // Top Gradient Shadow for readability
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Top-Left: [FACT CHECK] Pill Badge
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'FACT CHECK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Left: Verdict Badge Pill
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: effectiveVerdictColor.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              effectiveVerdictIcon,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              effectiveVerdictLabel.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Claim Content & Fact-Check Details
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video Context Row
                    Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          color: Color(0xFF8E8E93),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            effectiveVideoTitle,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Claim Statement with Quote Icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: Colors.white.withValues(alpha: 0.35),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '"$effectiveClaim"',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // 3. Verdict Takeaway Card (if summary or source is available)
                    if (summaryTakeaway != null && summaryTakeaway!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: effectiveVerdictColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: effectiveVerdictColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summaryTakeaway!.trim(),
                              style: const TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((confidenceText != null && confidenceText!.trim().isNotEmpty) ||
                                (sourceDomain != null && sourceDomain!.trim().isNotEmpty)) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (confidenceText != null && confidenceText!.trim().isNotEmpty)
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified_rounded,
                                            color: Color(0xFF9CA3AF),
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Confidence: ${confidenceText!.trim()}',
                                              style: const TextStyle(
                                                color: Color(0xFF9CA3AF),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (confidenceText != null &&
                                      confidenceText!.trim().isNotEmpty &&
                                      sourceDomain != null &&
                                      sourceDomain!.trim().isNotEmpty)
                                    const SizedBox(width: 8),
                                  if (sourceDomain != null && sourceDomain!.trim().isNotEmpty)
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.link_rounded,
                                            color: Color(0xFF60A5FA),
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              sourceDomain!.trim(),
                                              style: const TextStyle(
                                                color: Color(0xFF60A5FA),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // 4. Truthworld Footer with Link Icon & Chevron
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'Truthworld Fact Check',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailFallback(Color accentColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF19042B),
            Color(0xFF2A0A4A),
            Color(0xFF0A0014),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            color: Colors.white.withValues(alpha: 0.25),
            size: 32,
          ),
          const SizedBox(width: 8),
          Text(
            'TRUTH CHECK',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}
