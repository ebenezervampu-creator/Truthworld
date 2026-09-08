import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_panels.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class AdOverlay extends StatelessWidget {
  const AdOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ad = ctrl.currentAd.value;
      final apc = ctrl.adPlayerController;
      if (ad == null || apc == null) return const SizedBox.shrink();

      // ── 5-Sec Pre-Roll Sponsor Bumper: Do not show any text overlays on the video
      if (ad.isSponsorBumper) {
        return Stack(
          children: [
            // ── Bottom Progress Bar (Yellow timeline - No text) ───────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 4,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: apc,
                builder: (context, value, child) {
                  final duration = value.duration.inMilliseconds;
                  final position = value.position.inMilliseconds;
                  final progress = duration > 0
                      ? (position / duration).clamp(0.0, 1.0)
                      : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.textDisabled,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.warning,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }

      return Stack(
        children: [
          // ── Bottom Progress Bar (Yellow timeline) ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 4,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: apc,
              builder: (context, value, child) {
                final duration = value.duration.inMilliseconds;
                final position = value.position.inMilliseconds;
                final progress = duration > 0
                    ? (position / duration).clamp(0.0, 1.0)
                    : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.textDisabled,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.warning,
                  ),
                );
              },
            ),
          ),

          // ── Advertiser Brand Banner (Bottom Left) ──────────────────────
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgPage.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Ad',
                          style: TextStyle(
                            color: AppColors.bgPage,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ad.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      try {
                        await launchUrl(
                          Uri.parse(ad.clickUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        debugPrint('Could not launch ${ad.clickUrl}: $e');
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Learn More',
                            style: TextStyle(
                              color: AppColors.bgPage,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new_rounded,
                            color: AppColors.bgPage,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Skip Card (Bottom Right) ──────────────────────────────
          Positioned(
            right: 16,
            bottom: 24,
            child: Obx(() {
              final canSkip = ctrl.adCanSkip.value;
              final countdown = ctrl.skipCountdown.value;
              final remaining = ctrl.adTimeRemaining.value;

              if (canSkip) {
                return ElevatedButton(
                  onPressed: ctrl.skipAd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgPage.withValues(alpha: 0.75),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.textDisabled),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip Ad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.skip_next_rounded, size: 18),
                    ],
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Text(
                    ad.skippable
                        ? 'Skip in ${countdown}s'
                        : 'Ad will end in ${remaining}s',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
            }),
          ),

          // ── Tower Premium Promotion (Top Right) ───────────────────────────
          Positioned(
            right: 16,
            top: 16,
            child: InkWell(
              onTap: () => showPremiumDialog(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Try Truthworld Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Active Ad Subtitles Text Overlay ───────────────────────
          if (ctrl.isAdSubtitlesEnabled.value &&
              ctrl.currentAdSubtitle.value.isNotEmpty)
            Positioned(
              left: 32,
              right: 32,
              bottom: 84,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    ctrl.currentAdSubtitle.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(blurRadius: 3, offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Ad AI Tools (Subtitles & Dubbing Controls - Top Left) ───
          Positioned(
            left: 16,
            top: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ad.subtitles != null && ad.subtitles!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildAdSubtitlesButton(context, ad),
                  ),
                if (ad.audioTracks != null && ad.audioTracks!.isNotEmpty)
                  _buildAdDubbingButton(context, ad),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAdSubtitlesButton(BuildContext context, MockAd ad) {
    final subs = ad.subtitles ?? {};
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Ad Subtitles',
        color: const Color(0xFF1E1E1E),
        icon: Icon(
          ctrl.isAdSubtitlesEnabled.value
              ? Icons.closed_caption_rounded
              : Icons.closed_caption_disabled_rounded,
          color: Colors.white,
          size: 18,
        ),
        onSelected: (lang) {
          if (lang == 'toggle') {
            ctrl.toggleAdSubtitles();
          } else {
            ctrl.isAdSubtitlesEnabled.value = true;
            ctrl.setAdSubtitleLanguage(lang);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'toggle',
            child: Row(
              children: [
                Icon(
                  ctrl.isAdSubtitlesEnabled.value
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  ctrl.isAdSubtitlesEnabled.value
                      ? 'Disable Subtitles'
                      : 'Enable Subtitles',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          for (final entry in subs.entries)
            PopupMenuItem<String>(
              value: entry.key,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (ctrl.activeAdSubtitleLang.value == entry.key &&
                      ctrl.isAdSubtitlesEnabled.value)
                    const Icon(Icons.check, color: Colors.white, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdDubbingButton(BuildContext context, MockAd ad) {
    final dubs = ad.audioTracks ?? {};
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Ad Voice Dubbing',
        color: const Color(0xFF1E1E1E),
        icon: const Icon(
          Icons.record_voice_over_rounded,
          color: Colors.white,
          size: 18,
        ),
        onSelected: ctrl.setAdAudioLanguage,
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'original',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Original Audio',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                if (ctrl.activeAdAudioLang.value == 'original')
                  const Icon(Icons.check, color: Colors.white, size: 16),
              ],
            ),
          ),
          for (final entry in dubs.entries)
            PopupMenuItem<String>(
              value: entry.key,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dubbed: ${entry.key.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (ctrl.activeAdAudioLang.value == entry.key)
                    const Icon(Icons.check, color: Colors.white, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
