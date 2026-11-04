import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_player_settings_sheet.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Feedback coordinator for download snackbars and in-app push notifications.
///
/// Implements pixel-accurate designs matching user specification:
/// 1. Download Started Bottom Snackbar (Image 1):
///    - Clean white floating card with subtle elevation and rounded corners
///    - Left: Video thumbnail with rounded corners
///    - Text: "Downloading..." with resolution badge in matching fonts & theme
///    - Right: "View" action button in signature link blue
///    - Fully WCAG AA compliant (black/dark charcoal on white)
/// 2. Live In-App Push Notification Card (Image 2):
///    - Top floating push notification card with TruthWorld logo squircle
///    - Video title with "Now" timestamp
///    - Real-time linear progress bar
///    - Live formatted byte counts ("15 MB / 290 MB")
///    - Video thumbnail on the right edge
///    - Tappable to open downloads view
class DownloadFeedbackHelper {
  DownloadFeedbackHelper._();

  static void _safeCloseSnackbar() {
    try {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    } catch (_) {}
  }

  /// Displays the YouTube-style bottom snackbar when a download starts (Image 1).
  static void showDownloadStartedSnackbar({
    required Video video,
    String? resolutionText,
    bool isAudioOnly = false,
  }) {
    _safeCloseSnackbar();

    final resolutionLabel = isAudioOnly
        ? 'Audio'
        : (resolutionText != null &&
                resolutionText.isNotEmpty &&
                resolutionText != 'Standard'
            ? resolutionText
            : '');

    Get.rawSnackbar(
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 10,
      backgroundColor: Colors.white,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      messageText: Row(
        children: [
          // 1. Video Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 28,
              child: video.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFE0E0E0)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFE0E0E0),
                        child: const Icon(
                          Icons.video_library,
                          size: 16,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(
                        Icons.video_library,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // 2. "Downloading..." + Resolution Label
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Downloading...',
                  style: TextStyle(
                    fontFamily: 'TruthWorld Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F0F0F),
                  ),
                ),
                if (resolutionLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      resolutionLabel,
                      style: const TextStyle(
                        fontFamily: 'TruthWorld Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F0F0F),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. "View" action button
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              _safeCloseSnackbar();
              Get.toNamed(AppRoutes.downloads);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'View',
                style: TextStyle(
                  fontFamily: 'TruthWorld Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF065FD4),
                ),
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  /// Displays the "Downloaded" bottom snackbar when a download finishes successfully.
  static void showDownloadedSnackbar({
    required Video video,
    String? resolutionText,
    bool isAudioOnly = false,
  }) {
    _safeCloseSnackbar();

    final resolutionLabel = isAudioOnly
        ? 'Audio'
        : (resolutionText != null && resolutionText.isNotEmpty
            ? resolutionText
            : '');

    Get.rawSnackbar(
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 10,
      backgroundColor: Colors.white,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      messageText: Row(
        children: [
          // 1. Video Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 28,
              child: video.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFE0E0E0)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFE0E0E0),
                        child: const Icon(
                          Icons.download_done_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(
                        Icons.download_done_rounded,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // 2. "Downloaded" + Resolution Label
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Downloaded',
                  style: TextStyle(
                    fontFamily: 'TruthWorld Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F0F0F),
                  ),
                ),
                if (resolutionLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      resolutionLabel,
                      style: const TextStyle(
                        fontFamily: 'TruthWorld Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F0F0F),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. "Options" / "View" action button
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              _safeCloseSnackbar();
              VideoPlayerSettingsSheet.showDownloadedOptionsSheet(
                context: Get.context,
                video: video,
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Options',
                style: TextStyle(
                  fontFamily: 'TruthWorld Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF065FD4),
                ),
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  /// Displays the interactive in-app push notification banner matching Image 2.
  ///
  /// Useful for mobile web apps, desktop web, and in-app foreground tracking across platforms.
  static void showInAppPushNotification({
    required ActiveDownloadTask task,
  }) {
    final context = Get.context;
    final topPadding =
        context != null ? MediaQuery.of(context).padding.top : 0.0;

    Get.rawSnackbar(
      snackPosition: SnackPosition.TOP,
      dismissDirection: DismissDirection.up,
      margin: EdgeInsets.only(
        top: topPadding + 10,
        left: 16,
        right: 16,
      ),
      padding: const EdgeInsets.all(12),
      backgroundColor: AppColors.bgSurface,
      borderRadius: 16,
      borderColor: AppColors.bgDivider,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      duration: const Duration(seconds: 6),
      messageText: InkWell(
        onTap: () {
          _safeCloseSnackbar();
          Get.toNamed(AppRoutes.downloads);
        },
        child: Row(
          children: [
            // Left: TruthWorld Squircle Logo
            const AppLogo(size: 38, borderRadius: 10),
            const SizedBox(width: 12),

            // Center: Title, Progress Bar, Byte Counts
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with "Now v"
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'TruthWorld Sans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Reactive Progress bar
                  Obx(() {
                    final prog = task.progress.value.clamp(0.0, 1.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: prog,
                        minHeight: 3.5,
                        backgroundColor: const Color(0xFF404040),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3EA6FF),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 5),

                  // Reactive Bytes details (e.g. "15 MB / 290 MB")
                  Obx(() {
                    final text = task.byteProgressText;
                    final display =
                        text.isNotEmpty ? text : task.status.value;
                    return Text(
                      display,
                      style: const TextStyle(
                        fontFamily: 'TruthWorld Sans',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right: Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 34,
                child: task.video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: task.video.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.bgSurfaceHigh),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.bgSurfaceHigh,
                          child: const Icon(
                            Icons.video_library,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.bgSurfaceHigh,
                        child: const Icon(
                          Icons.video_library,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
