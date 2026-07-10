import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/core/utils/format_utils.dart';

import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'progress_bar.dart';

class MainControls extends StatelessWidget {
  final TowerPlayerController ctrl;
  final double playerWidth;
  const MainControls({
    super.key,
    required this.ctrl,
    required this.playerWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final double playerHeight = MediaQuery.of(context).size.height;
      final double? videoAspectRatio = ctrl.vv.isInitialized
          ? ctrl.vv.aspectRatio
          : null;
      final double maxControlsWidth =
          (ctrl.isFullScreen.value &&
              videoAspectRatio != null &&
              videoAspectRatio < 1.0)
          ? (playerHeight * videoAspectRatio).clamp(0.0, playerWidth)
          : playerWidth;

      final bool isNarrow = maxControlsWidth < 550;
      final bool isMedium = maxControlsWidth >= 550 && maxControlsWidth < 800;

      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar — network badge when fullscreen
          ctrl.isFullScreen.value
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

          const Spacer(),

          // Centre controls — play / prev / next
          RepaintBoundary(child: CenterRow(ctrl: ctrl)),

          const Spacer(),

          // Bottom gradient + controls — wrapped in GestureDetector to absorb
          // taps so the outer player GestureDetector (togglePlayPause) doesn't fire.
          Center(
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
        ],
      );
    });
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class PlayerTopBar extends StatelessWidget {
  final TowerPlayerController ctrl;
  const PlayerTopBar({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    String title = '';
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
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
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
          if (ctrl.isFullScreen.value && vc != null && channelCtrl != null) ...[
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
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.white,
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
              final notificationsEnabled = channelCtrl.notificationsEnabled.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () =>
                        channelCtrl!.toggleSubscription(vc!.video.channelId),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSubbed
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isSubbed ? 'Subscribed' : 'Subscribe',
                        style: TS.bold.copyWith(
                          color: isSubbed ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (isSubbed) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showPlayerNotificationsDialog(context, channelCtrl!, vc!.video.channelId),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                          color: Colors.white,
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
      BuildContext context, ChannelController channelCtrl, String channelId) {
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notification settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final isAll = channelCtrl.notificationsEnabled.value;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: isAll ? PT.primary : Colors.white,
                    ),
                    title: Text(
                      'All notifications',
                      style: TextStyle(
                        color: isAll ? PT.primary : Colors.white,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isAll ? Icon(Icons.check, color: PT.primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      channelCtrl.updateNotificationPreference(channelId, true);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_off,
                      color: !isAll ? PT.primary : Colors.white,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: !isAll ? PT.primary : Colors.white,
                        fontWeight: !isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: !isAll ? Icon(Icons.check, color: PT.primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      channelCtrl.updateNotificationPreference(channelId, false);
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
  final TowerPlayerController ctrl;
  const CenterRow({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // Absorb taps so the outer player GestureDetector (togglePlayPause) doesn't fire
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: ctrl.hasPreviousVideo ? 1.0 : 0.3,
              child: CenterBtn(
                icon: Icons.skip_previous_rounded,
                onTap: ctrl.hasPreviousVideo ? ctrl.playPrevious : null,
              ),
            ),
            const SizedBox(width: 40),
            CenterBtn(
              icon: ctrl.vv.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: ctrl.togglePlayPause,
              size: 68,
              isPrimary: true,
            ),
            const SizedBox(width: 40),
            Opacity(
              opacity: ctrl.hasNextVideo ? 1.0 : 0.3,
              child: CenterBtn(
                icon: Icons.skip_next_rounded,
                onTap: ctrl.hasNextVideo ? ctrl.playNext : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────
class PlayerBottomBar extends StatelessWidget {
  final TowerPlayerController ctrl;
  final bool isNarrow, isMedium;
  const PlayerBottomBar({
    super.key,
    required this.ctrl,
    required this.isNarrow,
    required this.isMedium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0, 0.6, 1],
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.55),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProgressBar(ctrl: ctrl),
          const SizedBox(height: 8),
          ControlRow(ctrl: ctrl, isNarrow: isNarrow, isMedium: isMedium),
        ],
      ),
    );
  }
}

// ── Control row ───────────────────────────────────────────────────────────────
class ControlRow extends StatelessWidget {
  final TowerPlayerController ctrl;
  final bool isNarrow, isMedium;
  const ControlRow({
    super.key,
    required this.ctrl,
    required this.isNarrow,
    required this.isMedium,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left cluster — hide on narrow
        if (!isNarrow && !isMedium) ...[
          Obx(
            () => IconBtn(
              icon: ctrl.vv.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: ctrl.togglePlayPause,
            ),
          ),
          Obx(
            () => Opacity(
              opacity: ctrl.hasPreviousVideo ? 1.0 : 0.3,
              child: IconBtn(
                icon: Icons.skip_previous_rounded,
                onTap: ctrl.hasPreviousVideo ? ctrl.playPrevious : null,
              ),
            ),
          ),
          Obx(
            () => Opacity(
              opacity: ctrl.hasNextVideo ? 1.0 : 0.3,
              child: IconBtn(
                icon: Icons.skip_next_rounded,
                onTap: ctrl.hasNextVideo ? ctrl.playNext : null,
              ),
            ),
          ),
          VolumeControl(ctrl: ctrl),
        ] else if (isMedium) ...[
          Obx(() => IconBtn(icon: ctrl.volumeIcon, onTap: ctrl.toggleMute)),
        ],

        // Time display
        Flexible(child: TimeDisplay(ctrl: ctrl)),
        const Spacer(),

        // Right cluster
        if (!isNarrow) AbrBadge(ctrl: ctrl),
        if (!isNarrow)
          Tooltip(
            message: 'Miniplayer',
            child: IconBtn(
              icon: Icons.branding_watermark_outlined,
              onTap: ctrl.togglePiP,
            ),
          ),

        // Autoplay
        if (!isNarrow)
          Obx(
            () => Tooltip(
              message: ctrl.isAutoplay.value ? 'Autoplay is on' : 'Autoplay is off',
              child: IconBtn(
                icon: ctrl.isAutoplay.value
                    ? Icons.playlist_play_rounded
                    : Icons.playlist_remove_rounded,
                onTap: ctrl.toggleAutoplay,
              ),
            ),
          ),

        // CC / Subtitles
        Obx(() {
          if (ctrl.subtitleTracks.isEmpty) return const SizedBox.shrink();
          return Tooltip(
            message: ctrl.subtitlesEnabled.value ? 'Subtitles (on)' : 'Subtitles (off)',
            child: IconBtn(
              icon: ctrl.subtitlesEnabled.value
                  ? Icons.closed_caption_rounded
                  : Icons.closed_caption_disabled_outlined,
              onTap: () {
                if (ctrl.subtitleTracks.isEmpty) return;
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
          );
        }),

        // Audio Only
        Obx(
          () => Tooltip(
            message: ctrl.isAudioOnly.value ? 'Audio only (on)' : 'Audio only',
            child: IconBtn(
              icon: ctrl.isAudioOnly.value
                  ? Icons.music_note_rounded
                  : Icons.music_note_outlined,
              onTap: () {
                String? url, title, art;
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
          child: IconBtn(icon: Icons.settings_outlined, onTap: ctrl.openSettings),
        ),

        // Fullscreen
        Obx(
          () => Tooltip(
            message: ctrl.isFullScreen.value ? 'Exit full screen (f)' : 'Full screen (f)',
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
  final TowerPlayerController ctrl;
  const NetworkBadge({super.key, required this.ctrl});

  Color _qColor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
        return Colors.greenAccent;
      case NetworkQuality.good:
        return Colors.lightGreenAccent;
      case NetworkQuality.fair:
        return Colors.yellowAccent;
      case NetworkQuality.poor:
        return Colors.orangeAccent;
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
            Icon(Icons.network_check_rounded, color: col, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
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
  final TowerPlayerController ctrl;
  const AbrBadge({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final label = ctrl.abr.isAutoMode.value
          ? 'AUTO·${ctrl.abr.currentTier.label}'
          : ctrl.abr.currentTier.label;
      return InkWell(
        onTap: ctrl.openSettings,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
  final TowerPlayerController ctrl;
  const VolumeControl({super.key, required this.ctrl});

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
                          inactiveTrackColor: Colors.white24,
                          thumbColor: PT.primary,
                          overlayColor: PT.primary.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: ctrl.volume.value,
                          onChanged: ctrl.setVolume,
                          min: 0,
                          max: 1,
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
  final TowerPlayerController ctrl;
  const TimeDisplay({super.key, required this.ctrl});

  String _fmt(Duration d) {
    final h = d.inHours,
        m = d.inMinutes.remainder(60).toString().padLeft(2, '0'),
        s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_fmt(ctrl.vv.position)} / ${_fmt(ctrl.vv.duration)}',
            style: TS.time,
          ),
          if (ctrl.currentChapter.value != null) ...[
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ctrl.currentChapter.value!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: PT.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PANEL
// ─────────────────────────────────────────────────────────────────────────────

class IconBtn extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final double size;
  const IconBtn({super.key, required this.icon, this.onTap, this.size = 26});

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
          child: icon is Widget
              ? icon as Widget
              : Icon(icon as IconData, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

class CenterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool isPrimary;
  const CenterBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.2),
        child: Container(
          padding: EdgeInsets.all(isPrimary ? 14 : 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: size, color: Colors.white),
        ),
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const PremiumButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

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
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
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
