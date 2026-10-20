import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// A 1080x1920 (9:16 aspect ratio) dark-mode shareable fact-check card for a video claim.
///
/// Designed with editorial spacing and high legibility suitable for sharing to
/// Instagram Stories, X, WhatsApp Status, and other 9:16 social surfaces.
class ClaimShareCard extends StatelessWidget {
  const ClaimShareCard({
    required this.video,
    required this.claimText,
    required this.verdict,
    super.key,
    this.primarySourceDomain,
  });

  /// The target canvas width for 9:16 high-resolution output.
  static const double cardWidth = 1080.0;

  /// The target canvas height for 9:16 high-resolution output.
  static const double cardHeight = 1920.0;

  final Video video;
  final String claimText;
  final ClaimVerdictInfo verdict;
  final String? primarySourceDomain;

  @override
  Widget build(BuildContext context) {
    final hasConfidence =
        verdict.confidenceText != null &&
        verdict.confidenceText!.trim().isNotEmpty;
    final hasSource =
        primarySourceDomain != null && primarySourceDomain!.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(cardWidth, cardHeight),
          textScaler: TextScaler.noScaling,
        ),
        child: Container(
          width: cardWidth,
          height: cardHeight,
          color: AppColors.bgPage,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header / Top Section ──────────────────────────────────
              _buildTopSection(),

              const Spacer(flex: 2),

              // ── Quotation Mark & Claim Statement ──────────────────────
              _buildClaimSection(),

              const Spacer(flex: 2),

              // ── Verdict Badge & Takeaway Card ─────────────────────────
              _buildVerdictSection(hasConfidence, hasSource),

              const Spacer(flex: 3),

              // ── Divider ───────────────────────────────────────────────
              const Divider(
                color: AppColors.bgDivider,
                thickness: 1.5,
                height: 1.5,
              ),

              const SizedBox(height: 28),

              // ── Footer ────────────────────────────────────────────────
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders the top section containing the video context title.
  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Editorial platform eyebrow
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FACT CHECK DOSSIER',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Video title text (max 2 lines, uiFamily, 28px, w600, textSecondary)
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// Renders decorative quote icon and the large claim text.
  Widget _buildClaimSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large quotation mark icon (48px, Colors.white, alpha 0.15)
        Icon(
          Icons.format_quote_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 16),
        // Claim text (uiFamily, 32px, w500, textPrimary, height: 1.45, max 6 lines)
        Text(
          claimText,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  /// Renders the verdict card with badge, summary takeaway, confidence, and source domain.
  Widget _buildVerdictSection(bool hasConfidence, bool hasSource) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: verdict.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Verdict badge: Horizontal row with verdict icon (Colors.white, 28px)
          // + verdict label text (verdict color, brandFamily, 22px, w700, letterSpacing: 1.2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: verdict.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: verdict.color.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verdict.icon,
                  size: 28,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  verdict.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: verdict.color,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Verdict summary takeaway text (uiFamily, 20px, textSecondary, max 3 lines)
          Text(
            verdict.summaryTakeaway,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 20,
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (hasConfidence || hasSource) ...[
            const SizedBox(height: 24),
            const Divider(
              color: AppColors.bgDivider,
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasConfidence)
                  Text(
                    'Confidence: ${verdict.confidenceText}',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 16,
                      color: AppColors.textTertiary,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (hasSource)
                  Text(
                    primarySourceDomain!.trim(),
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 16,
                      color: AppColors.textLink,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Renders footer with "Verified by TruthWorld" and white shield icon.
  Widget _buildFooter() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small shield icon (Colors.white, 20px)
            Icon(
              Icons.shield_rounded,
              size: 20,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            // "Verified by TruthWorld" text (brandFamily, 18px, textTertiary, letterSpacing: 1.0)
            Text(
              'Verified by TruthWorld',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 18,
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          'truthworld.in',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 16,
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Service providing headless raster capture and sharing for [ClaimShareCard].
class ClaimShareService {
  ClaimShareService._();

  /// Captures a [ClaimShareCard] as a high-resolution 9:16 PNG image and
  /// opens the native system share sheet.
  ///
  /// Flow:
  /// 1. Inserts an [OverlayEntry] off-stage containing the card wrapped in [RepaintBoundary].
  /// 2. Waits for post-frame callback to ensure raster rendering completes.
  /// 3. Rasterizes the [RenderRepaintBoundary] to a 3.0 pixelRatio image.
  /// 4. Converts the image to PNG byte data and saves it in the temporary directory.
  /// 5. Summons [Share.shareXFiles] with the generated image.
  /// 6. Safely cleans up the [OverlayEntry] in all execution paths.
  /// Static alias for [shareClaimCard].
  static Future<void> shareClaim({
    required BuildContext context,
    required Video video,
    required String claimText,
    required ClaimVerdictInfo verdict,
    String? primarySourceDomain,
    int? claimIndex,
  }) =>
      shareClaimCard(
        context: context,
        video: video,
        claimText: claimText,
        verdict: verdict,
        primarySourceDomain: primarySourceDomain,
        claimIndex: claimIndex,
      );

  static Future<void> shareClaimCard({
    required BuildContext context,
    required Video video,
    required String claimText,
    required ClaimVerdictInfo verdict,
    String? primarySourceDomain,
    int? claimIndex,
  }) async {
    // Obtain share origin synchronously before any async operations
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final targetClaimIndex = claimIndex ?? 0;
    final claimUrl = DeepLinkUrlBuilderAndShare.claimUrl(
      video.id,
      claimIndex: targetClaimIndex,
    );

    final subject = 'TruthWorld Fact Check: ${verdict.label}';
    final text =
        'Fact Check by TruthWorld\n'
        'Claim: "$claimText"\n'
        'Verdict: ${verdict.label}\n'
        '${video.title}\n\n'
        'Verify on TruthWorld:\n'
        '$claimUrl';

    // On Web, invoke native share directly
    if (kIsWeb) {
      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    AppSnackbar.info(
      'Generating shareable fact-check card...',
    );

    final repaintBoundaryKey = GlobalKey();
    OverlayEntry? overlayEntry;

    try {
      final overlayState =
          Overlay.maybeOf(context) ??
          (Get.overlayContext != null
              ? Overlay.maybeOf(Get.overlayContext!)
              : null);

      if (overlayState == null) {
        throw StateError('Unable to locate Overlay in the current context.');
      }

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: 0,
          top: 0,
          width: ClaimShareCard.cardWidth,
          height: ClaimShareCard.cardHeight,
          child: Material(
            type: MaterialType.transparency,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: RepaintBoundary(
                  key: repaintBoundaryKey,
                  child: ClaimShareCard(
                    video: video,
                    claimText: claimText,
                    verdict: verdict,
                    primarySourceDomain: primarySourceDomain,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      overlayState.insert(overlayEntry);

      // Wait one frame for the layout pass
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        completer.complete();
      });
      await completer.future;

      // Small delay to ensure render pipeline completes rasterization
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw StateError('RenderRepaintBoundary could not be resolved.');
      }

      // Capture boundary to image at 3.0 pixelRatio
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw StateError('Failed to encode image to PNG byte data.');
      }

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/truthworld_fact_check_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      // Clean up overlay before showing share sheet
      if (overlayEntry.mounted) {
        overlayEntry.remove();
        overlayEntry = null;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject,
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      ErrorHandler.log(e, tag: 'ClaimShareService.shareClaim');
      // Direct text fallback so the user is never blocked from sharing
      try {
        await Share.share(
          text,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        );
      } catch (fallbackError) {
        AppSnackbar.error(
          'Unable to share fact-check card. Please try again.',
        );
      }
    } finally {
      if (overlayEntry != null && overlayEntry.mounted) {
        overlayEntry.remove();
      }
    }
  }
}
