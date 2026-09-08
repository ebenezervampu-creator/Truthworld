import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/progress_bar.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

class MainControls extends StatelessWidget {
  const MainControls({
    required this.ctrl,
    required this.playerWidth,
    super.key,
  });
  final TowerPlayerController ctrl;
  final double playerWidth;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ctrl.isFullScreen.value;
      final playerHeight = MediaQuery.of(context).size.height;
      final videoAspectRatio = ctrl.isInitialized.value
          ? ctrl.aspectRatio.value
          : null;
      final maxControlsWidth =
          (ctrl.isFullScreen.value &&
              videoAspectRatio != null &&
              videoAspectRatio < 1.0)
          ? (playerHeight * videoAspectRatio).clamp(0.0, playerWidth)
          : playerWidth;

      final isNarrow = maxControlsWidth < 550;
      final isMedium = maxControlsWidth >= 550 && maxControlsWidth < 800;

      return Stack(
        children: [
          // Top controls (Fullscreen Top Bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Obx(
              () => ctrl.isFullScreen.value
                  ? Center(
                      child: SizedBox(
                        width: maxControlsWidth,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {}, // Absorb taps
                          child: PlayerTopBar(ctrl: ctrl),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Centre controls — play / prev / next
          Align(
            child: RepaintBoundary(
              child: CenterRow(ctrl: ctrl, maxControlsWidth: maxControlsWidth),
            ),
          ),

          // Bottom gradient + controls — wrapped in GestureDetector to absorb
          // taps so the outer player GestureDetector (togglePlayPause) doesn't fire.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: maxControlsWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: PlayerBottomBar(
                    ctrl: ctrl,
                    isNarrow: isNarrow,
                    isMedium: isMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    var title = '';
    VideoController? vc;
    ChannelController? channelCtrl;
    try {
      if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
        vc = Get.find<VideoController>(tag: ctrl.tag);
        title = vc.video.title;
        if (Get.isRegistered<ChannelController>(tag: ctrl.tag)) {
          channelCtrl = Get.find<ChannelController>(tag: ctrl.tag);
        } else {
          channelCtrl = Get.put(ChannelController(), tag: ctrl.tag);
        }
      }
    } catch (_) {}
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgPage.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Back / minimize fullscreen
          IconBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            size: 30,
            onTap: ctrl.toggleFullscreen,
          ),
          const SizedBox(width: 8),
          NetworkBadge(ctrl: ctrl),
          const SizedBox(width: 12),
          // Video title
          Expanded(
            child: Text(
              title,
              style: TS.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ctrl.isFullScreen.value &&
              vc != null &&
              channelCtrl != null &&
              MediaQuery.of(context).size.width > 600) ...[
            const SizedBox(width: 20),
            // Avatar
            ClipOval(
              child: vc.video.channelAvatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: vc.video.channelAvatarUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 32,
                      height: 32,
                      color: AppColors.textSecondary,
                      child: const Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Channel Name & Subs
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vc.video.channelName,
                  style: TS.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Obx(
                  () => Text(
                    '${FormatUtils.formatCount(channelCtrl!.subscriberCount.value)} subscribers',
                    style: TS.bodySm.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Subscribe Button & Bell Icon
            Obx(() {
              final isSubbed = channelCtrl!.isSubscribed.value;
              final notificationsEnabled =
                  channelCtrl.notificationsEnabled.value;
              final notificationOption = channelCtrl.notificationOption.value;

              IconData bellIcon;
              if (!notificationsEnabled || notificationOption == 'none') {
                bellIcon = Icons.notifications_off;
              } else if (notificationOption == 'personalized') {
                bellIcon = Icons.notifications_outlined;
              } else {
                bellIcon = Icons.notifications_active;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      if (!AuthService.to.isAuthenticated.value) {
                        Get.snackbar(
                          'Sign In Required',
                          'Please sign in to subscribe to channels.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.bgSurface,
                          colorText: AppColors.textPrimary,
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                          mainButton: TextButton(
                            onPressed: AuthService.to.signInWithGoogle,
                            child: const Text(
                              'SIGN IN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      channelCtrl!.toggleSubscription(vc!.video.channelId);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSubbed
                            ? AppColors.textPrimary.withValues(alpha: 0.1)
                            : AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isSubbed ? 'Subscribed' : 'Subscribe',
                        style: TS.bold.copyWith(
                          color: isSubbed
                              ? AppColors.textPrimary
                              : AppColors.bgPage,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (isSubbed) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showPlayerNotificationsDialog(
                        context,
                        channelCtrl!,
                        vc!.video.channelId,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          bellIcon,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showPlayerNotificationsDialog(
    BuildContext context,
    ChannelController channelCtrl,
    String channelId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notification settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final option = channelCtrl.notificationOption.value;
              final notificationsEnabled =
                  channelCtrl.notificationsEnabled.value;
              final isAll = notificationsEnabled && option == 'all';
              final isPersonalized =
                  notificationsEnabled && option == 'personalized';
              final isNone = !notificationsEnabled || option == 'none';

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_active,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      'All',
                      style: TextStyle(
                        color: isAll ? PT.primary : AppColors.textPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get all notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isAll
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      channelCtrl.updateNotificationPreference(
                        channelId,
                        'all',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      'Personalized',
                      style: TextStyle(
                        color: isPersonalized
                            ? PT.primary
                            : AppColors.textPrimary,
                        fontWeight: isPersonalized
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get personalized notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isPersonalized
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      channelCtrl.updateNotificationPreference(
                        channelId,
                        'personalized',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_off_outlined,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: isNone ? PT.primary : AppColors.textPrimary,
                        fontWeight: isNone
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn off all notifications',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isNone
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      channelCtrl.updateNotificationPreference(
                        channelId,
                        'none',
                      );
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Centre row ────────────────────────────────────────────────────────────────
class CenterRow extends StatelessWidget {
  const CenterRow({
    required this.ctrl,
    required this.maxControlsWidth,
    super.key,
  });
  final TowerPlayerController ctrl;
  final double maxControlsWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = maxControlsWidth < 600;
    final playSize = isMobile ? 48.0 : 68.0;
    final skipSize = isMobile ? 32.0 : 44.0;
    final spacing = isMobile ? 24.0 : 40.0;

    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: ctrl.hasPreviousVideo ? 1.0 : 0.3,
            child: CenterBtn(
              icon: Icons.skip_previous_rounded,
              onTap: ctrl.hasPreviousVideo ? ctrl.playPrevious : null,
              size: skipSize,
            ),
          ),
          SizedBox(width: spacing),
          CenterBtn(
            icon: ctrl.isPlaying.value
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onTap: ctrl.togglePlayPause,
            size: playSize,
            isPrimary: true,
          ),
          SizedBox(width: spacing),
          Opacity(
            opacity: ctrl.hasNextVideo ? 1.0 : 0.3,
            child: CenterBtn(
              icon: Icons.skip_next_rounded,
              onTap: ctrl.hasNextVideo ? ctrl.playNext : null,
              size: skipSize,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    required this.ctrl,
    required this.isNarrow,
    required this.isMedium,
    super.key,
  });
  final TowerPlayerController ctrl;
  final bool isNarrow;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0, 0.6, 1],
          colors: [
            AppColors.bgPage.withValues(alpha: 0.95),
            AppColors.bgPage.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
        borderRadius: ctrl.isFullScreen.value
            ? BorderRadius.zero
            : const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ControlRow(ctrl: ctrl, isNarrow: isNarrow, isMedium: isMedium),
          const SizedBox(height: 6),
          ProgressBar(ctrl: ctrl),
        ],
      ),
    );
  }
}

// ── Control row ───────────────────────────────────────────────────────────────
class ControlRow extends StatelessWidget {
  const ControlRow({
    required this.ctrl,
    required this.isNarrow,
    required this.isMedium,
    super.key,
  });
  final TowerPlayerController ctrl;
  final bool isNarrow;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    final isMobileDevice =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    if (isMobileDevice) {
      return Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TimeDisplay(ctrl: ctrl),
            ),
          ),
          Obx(
            () => Tooltip(
              message: ctrl.subtitlesEnabled.value
                  ? 'Subtitles (on)'
                  : 'Subtitles (off)',
              child: IconBtn(
                icon: ctrl.subtitlesEnabled.value
                    ? Icons.closed_caption_rounded
                    : Icons.closed_caption_outlined,
                onTap: () {
                  if (ctrl.subtitleTracks.isEmpty) {
                    ctrl.showToast('No captions available for this video');
                    return;
                  }
                  if (ctrl.subtitlesEnabled.value) {
                    ctrl.setSubtitles(enabled: false);
                  } else {
                    ctrl.setSubtitles(
                      enabled: true,
                      track: ctrl.subtitleTracks.first,
                    );
                  }
                },
              ),
            ),
          ),
          Tooltip(
            message: 'Settings',
            child: IconBtn(
              icon: Icons.settings_outlined,
              onTap: () => ctrl.openSettings(context),
            ),
          ),
          Obx(
            () => Tooltip(
              message: ctrl.isFullScreen.value
                  ? 'Exit full screen (f)'
                  : 'Full screen (f)',
              child: IconBtn(
                icon: ctrl.isFullScreen.value
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                onTap: ctrl.toggleFullscreen,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Left cluster — hide on narrow
        if (!isNarrow && !isMedium) ...[
          Obx(
            () => IconBtn(
              icon: ctrl.isPlaying.value
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: ctrl.togglePlayPause,
            ),
          ),
          Obx(
            () {
              ctrl.isAudioOnly.value;
              return Opacity(
                opacity: ctrl.hasPreviousVideo ? 1.0 : 0.3,
                child: IconBtn(
                  icon: Icons.skip_previous_rounded,
                  onTap: ctrl.hasPreviousVideo ? ctrl.playPrevious : null,
                ),
              );
            },
          ),
          Obx(
            () {
              ctrl.isAudioOnly.value;
              return Opacity(
                opacity: ctrl.hasNextVideo ? 1.0 : 0.3,
                child: IconBtn(
                  icon: Icons.skip_next_rounded,
                  onTap: ctrl.hasNextVideo ? ctrl.playNext : null,
                ),
              );
            },
          ),
          VolumeControl(ctrl: ctrl),
        ] else if (isMedium) ...[
          Obx(() => IconBtn(icon: ctrl.volumeIcon, onTap: ctrl.toggleMute)),
        ],

        // Time display & chapters
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TimeDisplay(ctrl: ctrl),
          ),
        ),

        // Right cluster
        if (!isNarrow) AbrBadge(ctrl: ctrl),

        // CC / Subtitles (always present alongside Settings)
        Obx(
          () => Tooltip(
            message: ctrl.subtitlesEnabled.value
                ? 'Subtitles (on)'
                : 'Subtitles (off)',
            child: IconBtn(
              icon: ctrl.subtitlesEnabled.value
                  ? Icons.closed_caption_rounded
                  : Icons.closed_caption_outlined,
              onTap: () {
                if (ctrl.subtitleTracks.isEmpty) {
                  ctrl.showToast('No captions available for this video');
                  return;
                }
                if (ctrl.subtitlesEnabled.value) {
                  ctrl.setSubtitles(enabled: false);
                } else {
                  ctrl.setSubtitles(
                    enabled: true,
                    track: ctrl.subtitleTracks.first,
                  );
                }
              },
            ),
          ),
        ),

        // Audio Only
        Obx(
          () => Tooltip(
            message: ctrl.isAudioOnly.value ? 'Audio only (on)' : 'Audio only',
            child: IconBtn(
              icon: ctrl.isAudioOnly.value
                  ? Icons.music_note_rounded
                  : Icons.music_note_outlined,
              onTap: () {
                String? url;
                String? title;
                String? art;
                try {
                  if (ctrl.tag != null &&
                      Get.isRegistered<VideoController>(tag: ctrl.tag)) {
                    final vc = Get.find<VideoController>(tag: ctrl.tag);
                    url = vc.currentResolution.value?.url;
                    title = vc.video.title;
                    art = vc.video.thumbnailUrl;
                  }
                } catch (_) {}
                ctrl.toggleAudioOnly(
                  videoUrl: url,
                  title: title,
                  artworkUrl: art,
                );
              },
            ),
          ),
        ),

        // Settings
        Tooltip(
          message: 'Settings',
          child: IconBtn(
            icon: Icons.settings_outlined,
            onTap: () => ctrl.openSettings(context),
          ),
        ),

        // Fullscreen
        Obx(
          () => Tooltip(
            message: ctrl.isFullScreen.value
                ? 'Exit full screen (f)'
                : 'Full screen (f)',
            child: IconBtn(
              icon: ctrl.isFullScreen.value
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              onTap: ctrl.toggleFullscreen,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NETWORK / ABR BADGES
// ─────────────────────────────────────────────────────────────────────────────
class NetworkBadge extends StatelessWidget {
  const NetworkBadge({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  Color _qColor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
        return AppColors.success;
      case NetworkQuality.good:
        return Colors.lightGreenAccent;
      case NetworkQuality.fair:
        return AppColors.brandHover;
      case NetworkQuality.poor:
        return AppColors.warning;
      default:
        return PT.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final q = ctrl.abr.networkQuality.value;
      final bw = ctrl.abr.measuredBandwidthKbps.value;
      final col = _qColor(q);
      final label = bw > 1000
          ? '${(bw / 1000).toStringAsFixed(1)} Mbps'
          : '${bw.toStringAsFixed(0)} kbps';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.network_check_rounded, color: AppColors.textPrimary, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: col,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class AbrBadge extends StatelessWidget {
  const AbrBadge({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shortTier = ctrl.abr.currentTier.height > 0
          ? '${ctrl.abr.currentTier.height}p'
          : ctrl.abr.currentTier.label;
      final label = ctrl.abr.isAutoMode.value
          ? 'AUTO·$shortTier'
          : shortTier;
      return InkWell(
        onTap: () => ctrl.openSettings(context),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          child: Text(label, style: TS.badge),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR  — hover-expand, LayoutBuilder-safe, chapter markers
// ─────────────────────────────────────────────────────────────────────────────

class VolumeControl extends StatelessWidget {
  const VolumeControl({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => MouseRegion(
        onEnter: (_) => ctrl.volumeSliderVis.value = true,
        onExit: (_) => ctrl.volumeSliderVis.value = false,
        child: Row(
          children: [
            IconBtn(icon: ctrl.volumeIcon, onTap: ctrl.toggleMute),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: ctrl.volumeSliderVis.value
                  ? SizedBox(
                      width: 80,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: PT.primary,
                          inactiveTrackColor: AppColors.textDisabled,
                          thumbColor: PT.primary,
                          overlayColor: PT.primary.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: ctrl.volume.value,
                          onChanged: ctrl.setVolume,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME DISPLAY
// ─────────────────────────────────────────────────────────────────────────────
class TimeDisplay extends StatelessWidget {
  const TimeDisplay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _openChapters(BuildContext context) {
    if (ctrl.chapters.isEmpty) return;
    final isMobileDevice =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    if (isMobileDevice) {
      VideoController? vc;
      try {
        if (ctrl.tag != null &&
            Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          vc = Get.find<VideoController>(tag: ctrl.tag);
        } else if (Get.isRegistered<VideoController>()) {
          vc = Get.find<VideoController>();
        }
      } catch (_) {}
      if (vc != null) {
        VideoChaptersBottomSheet.show(
          context,
          video: vc.video,
          videoTag: ctrl.tag,
        );
        return;
      }
    }
    ctrl.activePanel.value = 'chapters';
    ctrl.settingsOpen.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final currentChapter = ctrl.currentChapter.value;
        final hasChapters = ctrl.chapters.isNotEmpty;
        final chapterTitle =
            currentChapter?.title ?? (hasChapters ? 'Chapters' : null);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_fmt(ctrl.vv.position)} / ${_fmt(ctrl.vv.duration)}',
              style: TS.time,
            ),
            if (chapterTitle != null) ...[
              const SizedBox(width: 6),
              Text(
                '•',
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: InkWell(
                  onTap: () => _openChapters(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PANEL
// ─────────────────────────────────────────────────────────────────────────────

class IconBtn extends StatelessWidget {
  const IconBtn({required this.icon, super.key, this.onTap, this.size = 26});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: PT.primary.withValues(alpha: 0.2),
        highlightColor: PT.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.textPrimary, size: size),
        ),
      ),
    );
  }
}

class CenterBtn extends StatelessWidget {
  const CenterBtn({
    required this.icon,
    super.key,
    this.onTap,
    this.size = 44,
    this.isPrimary = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.2),
        child: Container(
          padding: EdgeInsets.all(isPrimary ? 14 : 10),
          decoration: BoxDecoration(
            color: AppColors.bgPage.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: size, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  const PremiumButton({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PT.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileAutoplaySwitch extends StatelessWidget {
  const MobileAutoplaySwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AppColors.textPrimary : AppColors.textDisabled,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF1E1E1E) : AppColors.textSecondary,
            ),
            child: Icon(
              value ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 14,
              color: value ? AppColors.textPrimary : const Color(0xFF1E1E1E),
            ),
          ),
        ),
      ),
    );
  }
}
