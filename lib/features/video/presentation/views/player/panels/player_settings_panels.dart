import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/language_requests.dart';
import 'package:truthworld/features/video/presentation/widgets/language_preferences_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ctrl.closeSettings,
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: AppColors.bgPage.withValues(alpha: 0.5),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb inner taps
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 340,
                  constraints: const BoxConstraints(maxHeight: 520),
                  decoration: BoxDecoration(
                    color: PT.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PT.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.7),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: PT.primary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Obx(() {
                      switch (ctrl.activePanel.value) {
                        case 'speed':
                          return SpeedPanel(ctrl: ctrl);
                        case 'quality':
                          return QualityPanel(ctrl: ctrl);
                        case 'subtitles':
                          return SubtitlesPanel(ctrl: ctrl);
                        case 'language':
                          return LanguagePanel(ctrl: ctrl);
                        case 'rating':
                          return RatingPanel(ctrl: ctrl);
                        case 'chapters':
                          return ChaptersPanel(ctrl: ctrl);
                        default:
                          return MainSettingsMenu(ctrl: ctrl);
                      }
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main menu ─────────────────────────────────────────────────────────────────
class MainSettingsMenu extends StatelessWidget {
  const MainSettingsMenu({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'Settings',
            onBack: null,
            onClose: ctrl.closeSettings,
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.slow_motion_video_rounded,
              title: 'Playback Speed',
              value: ctrl.playbackSpeed.value == 1.0
                  ? 'Normal'
                  : '${ctrl.playbackSpeed.value}×',
              onTap: () => ctrl.activePanel.value = 'speed',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.tune_rounded,
              title: 'Quality',
              value: ctrl.currentQualityLabel,
              badge: ctrl.abr.isAutoMode.value ? 'AUTO' : null,
              onTap: () => ctrl.activePanel.value = 'quality',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.closed_caption_rounded,
              title: 'Subtitles / CC',
              value: ctrl.subtitlesEnabled.value
                  ? ctrl.activeSubLang.value
                  : 'Off',
              onTap: () => ctrl.activePanel.value = 'subtitles',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.translate_rounded,
              title: 'Audio Language',
              value: ctrl.activeAudioLang.value,
              onTap: () => ctrl.activePanel.value = 'language',
            ),
          ),
          Obx(
            () => ctrl.chapters.isNotEmpty
                ? SettingsTile(
                    icon: Icons.list_alt_rounded,
                    title: 'Chapters',
                    value: ctrl.currentChapter.value?.title ?? 'None',
                    onTap: () => ctrl.activePanel.value = 'chapters',
                  )
                : const SizedBox.shrink(),
          ),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Content Details',
            value: ctrl.contentMeta.rating,
            onTap: () => ctrl.activePanel.value = 'rating',
          ),
          const PlayerDivider(),
          Obx(
            () => ToggleTile(
              icon: Icons.repeat_rounded,
              title: 'Loop',
              value: ctrl.isLooping.value,
              onChanged: (_) => ctrl.toggleLoop(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.playlist_play_rounded,
              title: 'Autoplay Next',
              value: ctrl.isAutoplay.value,
              onChanged: (_) => ctrl.toggleAutoplay(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.music_note_rounded,
              title: 'Audio Only Mode',
              value: ctrl.isAudioOnly.value,
              onChanged: (_) => ctrl.toggleAudioOnly(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.analytics_outlined,
              title: 'Stats for Nerds',
              value: ctrl.showStatsForNerds.value,
              onChanged: (_) => ctrl.showStatsForNerds.toggle(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.view_sidebar_rounded,
              title: 'Fullscreen Action Bar',
              value: ctrl.showFullscreenActionsDock.value,
              onChanged: (_) => ctrl.showFullscreenActionsDock.toggle(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.aspect_ratio_rounded,
              title: 'Zoom to Fill',
              value: ctrl.isZoomToFill.value,
              onChanged: (_) => ctrl.toggleZoomToFill(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Chapters panel ─────────────────────────────────────────────────────────────
class ChaptersPanel extends StatelessWidget {
  const ChaptersPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    VideoController? vc;
    try {
      if (ctrl.tag != null && Get.isRegistered<VideoController>(tag: ctrl.tag)) {
        vc = Get.find<VideoController>(tag: ctrl.tag);
      } else if (Get.isRegistered<VideoController>()) {
        vc = Get.find<VideoController>();
      }
    } catch (_) {}

    final video = vc?.video ??
        Video(
          id: '',
          title: '',
          description: '',
          videoUrl: '',
          thumbnailUrl: '',
          duration: 0,
          ownerId: '',
          channelId: '',
          channelName: '',
          category: '',
          tags: const [],
          createdAt: DateTime.now(),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Chapters',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: ctrl.chapters.length,
            itemBuilder: (_, i) {
              final ch = ctrl.chapters[i];
              return ChapterTile(
                chapter: ch,
                video: video,
                playerCtrl: ctrl,
                onTapOverride: () {
                  ctrl.seekTo(ch.startTime);
                  ctrl.closeSettings();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Speed panel ────────────────────────────────────────────────────────────────
class SpeedPanel extends StatelessWidget {
  const SpeedPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Playback Speed',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        ..._speeds.map(
          (s) => Obx(
            () => SelectTile(
              label: s == 1.0 ? 'Normal' : '$s×',
              selected: ctrl.playbackSpeed.value == s,
              onTap: () => ctrl.setSpeed(s),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Quality panel ──────────────────────────────────────────────────────────────
class QualityPanel extends StatelessWidget {
  const QualityPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  String _bwLabel(double k) => k > 1000
      ? '${(k / 1000).toStringAsFixed(1)} Mbps'
      : '${k.toStringAsFixed(0)} kbps';

  Color _qColor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return AppColors.success;
      case NetworkQuality.fair:
        return Colors.yellowAccent;
      default:
        return PT.primary;
    }
  }

  bool _isPremiumUser() {
    try {
      if (!Get.isRegistered<AuthService>()) return false;
      return AuthService.to.isPremiumUser.value;
    } catch (_) {
      return false;
    }
  }

  void _showPremiumDialog(BuildContext context) {
    showPremiumDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      var avail = <VideoResolutionV2>[];
      var none = false;
      try {
        if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          avail = Get.find<VideoController>(tag: ctrl.tag).availableResolutions;
          none = avail.isEmpty;
        }
      } catch (_) {}

      if (none) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeader(
              title: 'Video Quality',
              onBack: () => ctrl.activePanel.value = '',
              onClose: null,
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.videocam_off_rounded, size: 48, color: PT.primary),
                  SizedBox(height: 16),
                  Text('Video Not Available', style: TS.title),
                  SizedBox(height: 8),
                  Text(
                    'No playable resolutions found',
                    textAlign: TextAlign.center,
                    style: TS.bodySm,
                  ),
                ],
              ),
            ),
          ],
        );
      }

      final tiers = ctrl.abr.resolutionLadder;
      final isPremium = _isPremiumUser();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'Video Quality',
            onBack: () => ctrl.activePanel.value = '',
            onClose: null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: AppColors.textTertiary, size: 14),
                const SizedBox(width: 8),
                const Text('Network: ', style: TS.bodySm),
                Text(
                  _bwLabel(ctrl.abr.measuredBandwidthKbps.value),
                  style: TS.bodySm.copyWith(
                    color: _qColor(ctrl.abr.networkQuality.value),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Text('Buffer: ', style: TS.bodySm),
                Text(
                  '${ctrl.abr.bufferHealthSeconds.value.toStringAsFixed(1)}s',
                  style: TS.bodySm.copyWith(
                    color: ctrl.abr.bufferHealthSeconds.value < 3
                        ? PT.primary
                        : AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const PlayerDivider(),
          SelectTile(
            label: 'Auto',
            sublabel: 'Adapts to network speed',
            selected: ctrl.abr.isAutoMode.value,
            badge: ctrl.abr.isAutoMode.value
                ? ctrl.abr.currentTier.label
                : null,
            onTap: ctrl.selectAutoQuality,
          ),
          ...tiers.reversed
              .where((t) => avail.any((r) => r.height == t.height))
              .map((tier) {
                final idx = tiers.indexWhere((t) => t.height == tier.height);
                final isPremiumRes = tier.height > 1080;

                return SelectTile(
                  label: tier.label,
                  sublabel: '${tier.bitrate} kbps',
                  selected:
                      !ctrl.abr.isAutoMode.value &&
                      ctrl.abr.currentTier.height == tier.height,
                  trailing: isPremiumRes && !isPremium
                      ? const Icon(
                          Icons.lock_rounded,
                          color: AppColors.warning,
                          size: 16,
                        )
                      : null,
                  onTap: () {
                    if (isPremiumRes && !isPremium) {
                      _showPremiumDialog(context);
                    } else {
                      if (idx >= 0) ctrl.selectQuality(idx);
                    }
                  },
                );
              }),
          const SizedBox(height: 8),
        ],
      );
    });
  }
}

void showPremiumDialog(BuildContext context) {
  Get.toNamed('/premium');
}

// ── Subtitles panel ────────────────────────────────────────────────────────────
class SubtitlesPanel extends StatelessWidget {
  const SubtitlesPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Subtitles / CC',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        Obx(
          () => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.closed_caption_rounded,
                  color: PT.primary,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Text(
                  'Subtitles',
                  style: TS.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: ctrl.subtitlesEnabled.value,
                  onChanged: (v) => ctrl.setSubtitles(enabled: v),
                  activeThumbColor: PT.primary,
                  activeTrackColor: PT.primary.withValues(alpha: 0.4),
                  inactiveThumbColor: AppColors.textTertiary,
                  inactiveTrackColor: AppColors.bgDivider,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
        const PlayerDivider(),
        ConfigureLanguagesButton(
          onTap: () => showDialog(
            context: context,
            builder: (_) => const LanguagePreferencesDialog(),
          ),
        ),
        const PlayerDivider(),
        RequestLanguageButton(
          type: 'subtitle',
          onTap: () => ctrl.showRequestDialog(context, 'subtitle'),
        ),
        const PlayerDivider(),
        Expanded(
          child: LanguageRequestsList(type: 'subtitle', tag: ctrl.tag),
        ),
        const PlayerDivider(),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Obx(() {
              if (ctrl.subtitleTracks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No subtitles available', style: TS.bodySm),
                  ),
                );
              }
              return Column(
                children: ctrl.subtitleTracks
                    .map(
                      (t) => SelectTile(
                        label: t.label,
                        badge: t.langCode.toUpperCase(),
                        selected:
                            ctrl.subtitlesEnabled.value &&
                            ctrl.activeSubLang.value == t.label,
                        dimmed: !ctrl.subtitlesEnabled.value,
                        onTap: ctrl.subtitlesEnabled.value
                            ? () => ctrl.setSubtitles(enabled: true, track: t)
                            : null,
                      ),
                    )
                    .toList(),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Language panel ────────────────────────────────────────────────────────────
class LanguagePanel extends StatelessWidget {
  const LanguagePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Audio Language',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        ConfigureLanguagesButton(
          onTap: () => showDialog(
            context: context,
            builder: (_) => const LanguagePreferencesDialog(),
          ),
        ),
        const PlayerDivider(),
        RequestLanguageButton(
          type: 'audio',
          onTap: () => ctrl.showRequestDialog(context, 'audio'),
        ),
        const PlayerDivider(),
        Expanded(
          child: LanguageRequestsList(type: 'audio', tag: ctrl.tag),
        ),
        const PlayerDivider(),
        Expanded(
          child: SingleChildScrollView(
            child: Obx(() {
              if (ctrl.audioTracks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Original audio only', style: TS.bodySm),
                  ),
                );
              }
              return Column(
                children: ctrl.audioTracks
                    .map(
                      (t) => SelectTile(
                        label: t.label,
                        sublabel: t.type,
                        badge: t.langCode.toUpperCase(),
                        selected: ctrl.activeAudioLang.value == t.label,
                        onTap: () => ctrl.setAudioLanguage(t),
                      ),
                    )
                    .toList(),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Rating / content details panel ────────────────────────────────────────────
class RatingPanel extends StatelessWidget {
  const RatingPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final m = ctrl.contentMeta;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'Content Details',
            onBack: () => ctrl.activePanel.value = '',
            onClose: null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: PT.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: PT.primary.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        m.rating,
                        style: TS.badge.copyWith(
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: m.advisories
                            .map(
                              (a) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.textPrimary.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  a,
                                  style: TS.bodySm.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
                // Fact Check Report Button
                Builder(
                  builder: (_) {
                    try {
                      final vc = Get.find<VideoController>(tag: ctrl.tag);
                      if (vc.video.uiReport != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: InkWell(
                            onTap: () {
                              ctrl.closeSettings();
                              vc.fetchFullDisclosure();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.fact_check_outlined,
                                    color: PT.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fact Check Report',
                                          style: TS.bold.copyWith(fontSize: 14),
                                        ),
                                        Text(
                                          'AI Verified Claims & Sources',
                                          style: TS.bodySm.copyWith(
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'VIEW REPORT',
                                    style: TS.badge.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (_) {}
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          const PlayerDivider(),
          ...[
            ('Genre', m.genre),
            ('Release Year', m.releaseYear),
            ('Duration', m.duration),
            ('Director', m.director),
            ('Cast', m.cast),
          ].map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      row.$1,
                      style: TS.bodySm.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(row.$2, style: TS.body.copyWith(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class PanelHeader extends StatelessWidget {
  const PanelHeader({
    required this.title, required this.onBack, required this.onClose, this.onContinue, super.key,
  });
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconBtn(icon: Icons.arrow_back_ios_new, onTap: onBack, size: 18)
          else
            const SizedBox(width: 8),
          Expanded(child: Text(title, style: TS.title)),
          if (onContinue != null) ...[
            TextButton(
              onPressed: onContinue,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: PT.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (onClose != null)
            IconBtn(icon: Icons.close_rounded, onTap: onClose, size: 20),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon, required this.title, required this.value, required this.onTap, super.key,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: PT.primary, size: 20),
              const SizedBox(width: 16),
              Text(title, style: TS.body.copyWith(fontWeight: FontWeight.w500)),
              const Spacer(),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: PT.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: PT.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(badge!, style: TS.badge.copyWith(fontSize: 11)),
                ),
                const SizedBox(width: 6),
              ],
              Text(value, style: TS.bodySm),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class ToggleTile extends StatelessWidget {
  const ToggleTile({
    required this.icon, required this.title, required this.value, required this.onChanged, super.key,
  });
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: PT.primary, size: 20),
          const SizedBox(width: 16),
          Text(title, style: TS.body.copyWith(fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: PT.primary,
            activeTrackColor: PT.primary.withValues(alpha: 0.4),
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.bgDivider,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class SelectTile extends StatelessWidget {
  const SelectTile({
    required this.label, required this.selected, super.key,
    this.sublabel,
    this.badge,
    this.dimmed = false,
    this.onTap,
    this.trailing,
  });
  final String label;
  final String? sublabel;
  final String? badge;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              if (badge != null) ...[
                Container(
                  width: 34,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected
                        ? PT.primary.withValues(alpha: 0.15)
                        : AppColors.textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: selected
                          ? PT.primary.withValues(alpha: 0.5)
                          : AppColors.textPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TS.badge.copyWith(
                        color: selected ? PT.primary : AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TS.body.copyWith(
                        color: dimmed
                            ? AppColors.textDisabled
                            : selected
                            ? PT.primary
                            : AppColors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        style: TS.bodySm.copyWith(
                          color: dimmed ? AppColors.bgDivider : AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected)
                const Icon(Icons.check_rounded, color: PT.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerDivider extends StatelessWidget {
  const PlayerDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(
    color: AppColors.textPrimary.withValues(alpha: 0.08),
    height: 12,
    indent: 20,
    endIndent: 20,
  );
}

class ConfigureLanguagesButton extends StatelessWidget {
  const ConfigureLanguagesButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                color: PT.primary,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferred Languages',
                      style: TS.bold.copyWith(fontSize: 14),
                    ),
                    Text(
                      'Set primary, secondary & known languages',
                      style: TS.bodySm.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileSettingsBottomSheet extends StatelessWidget {
  const MobileSettingsBottomSheet({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  static void show(BuildContext context, TowerPlayerController ctrl) {
    Get.bottomSheet(
      MobileSettingsBottomSheet(ctrl: ctrl),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 250),
      exitBottomSheetDuration: const Duration(milliseconds: 150),
    ).then((_) {
      // Reset state when closed
      ctrl.activePanel.value = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: const Color(0xFF1E1E1E), // Premium dark theme matching screenshot
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Obx(() {
              Widget content;
              switch (ctrl.activePanel.value) {
                case 'speed':
                  content = SpeedPanel(ctrl: ctrl);
                case 'quality':
                  content = QualityPanel(ctrl: ctrl);
                case 'subtitles':
                  content = SizedBox(
                    height: 450,
                    child: SubtitlesPanel(ctrl: ctrl),
                  );
                case 'language':
                  content = SizedBox(
                    height: 450,
                    child: LanguagePanel(ctrl: ctrl),
                  );
                case 'more':
                  content = MorePanel(ctrl: ctrl);
                case 'sleep_timer':
                  content = SleepTimerPanel(ctrl: ctrl);
                default:
                  content = MobileMainSettingsMenu(ctrl: ctrl);
              }

              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: content,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class MobileMainSettingsMenu extends StatelessWidget {
  const MobileMainSettingsMenu({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle at top center of bottom sheet
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.tune_rounded,
              title: 'Quality',
              value: ctrl.abr.isAutoMode.value 
                  ? 'Auto (${ctrl.currentQualityLabel})' 
                  : ctrl.currentQualityLabel,
              onTap: () => ctrl.activePanel.value = 'quality',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Playback speed',
              value: ctrl.playbackSpeed.value == 1.0
                  ? 'Normal'
                  : '${ctrl.playbackSpeed.value}x',
              onTap: () => ctrl.activePanel.value = 'speed',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.closed_caption_rounded,
              title: 'Captions',
              value: ctrl.subtitlesEnabled.value
                  ? ctrl.activeSubLang.value
                  : 'Off',
              onTap: () => ctrl.activePanel.value = 'subtitles',
            ),
          ),
          Obx(
            () => MobileSettingsTile(
              icon: Icons.settings_voice_rounded,
              title: 'Audio Track',
              value: ctrl.activeAudioLang.value,
              onTap: () => ctrl.activePanel.value = 'language',
            ),
          ),
          MobileSettingsTile(
            icon: Icons.settings_outlined,
            title: 'More',
            value: '',
            onTap: () => ctrl.activePanel.value = 'more',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class MobileSettingsTile extends StatelessWidget {
  const MobileSettingsTile({
    required this.icon, required this.title, required this.value, required this.onTap, super.key,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 18),
              Text(
                title,
                style: TS.body.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: TS.bodySm.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileToggleTile extends StatelessWidget {
  const MobileToggleTile({
    required this.icon, required this.title, required this.value, required this.onChanged, super.key,
  });
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 18),
              Text(
                title,
                style: TS.body.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.textPrimary,
                activeTrackColor: PT.primary,
                inactiveThumbColor: AppColors.textTertiary,
                inactiveTrackColor: AppColors.bgDivider,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MorePanel extends StatelessWidget {
  const MorePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'More',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        const PlayerDivider(),
        Obx(
          () => MobileToggleTile(
            icon: Icons.repeat_rounded,
            title: 'Loop video',
            value: ctrl.isLooping.value,
            onChanged: (v) => ctrl.toggleLoop(),
          ),
        ),
        Obx(
          () => MobileToggleTile(
            icon: Icons.music_note_rounded,
            title: 'Audio Only Mode',
            value: ctrl.isAudioOnly.value,
            onChanged: (v) => ctrl.toggleAudioOnly(),
          ),
        ),
        Obx(
          () => MobileToggleTile(
            icon: Icons.playlist_play_rounded,
            title: 'Autoplay Next',
            value: ctrl.isAutoplay.value,
            onChanged: (v) => ctrl.toggleAutoplay(),
          ),
        ),
        Obx(
          () => MobileToggleTile(
            icon: Icons.analytics_outlined,
            title: 'Stats for Nerds',
            value: ctrl.showStatsForNerds.value,
            onChanged: (v) => ctrl.showStatsForNerds.toggle(),
          ),
        ),
        Obx(
          () => MobileToggleTile(
            icon: Icons.view_sidebar_rounded,
            title: 'Fullscreen Action Bar',
            value: ctrl.showFullscreenActionsDock.value,
            onChanged: (v) => ctrl.showFullscreenActionsDock.toggle(),
          ),
        ),
        Obx(
          () => MobileToggleTile(
            icon: Icons.aspect_ratio_rounded,
            title: 'Zoom to Fill',
            value: ctrl.isZoomToFill.value,
            onChanged: (v) => ctrl.toggleZoomToFill(),
          ),
        ),
        Obx(
          () => MobileSettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Lock screen',
            value: ctrl.lockController.isLocked.value ? 'Locked' : 'Off',
            onTap: () {
              ctrl.closeSettings();
              ctrl.lockController.lock();
            },
          ),
        ),
        Obx(() {
          final isActive = ctrl.isSleepTimerActive.value;
          final isAtEnd = ctrl.isSleepTimerAtEndOfVideo.value;
          final rem = ctrl.sleepTimerRemainingSeconds.value;
          var valueText = 'Off';
          if (isActive) {
            if (isAtEnd) {
              valueText = 'End of video';
            } else {
              final mins = rem ~/ 60;
              final secs = rem % 60;
              valueText = '$mins:${secs.toString().padLeft(2, '0')} left';
            }
          }
          return MobileSettingsTile(
            icon: Icons.nights_stay_rounded,
            title: 'Sleep timer',
            value: valueText,
            onTap: () => ctrl.activePanel.value = 'sleep_timer',
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class SleepTimerPanel extends StatelessWidget {
  const SleepTimerPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final options = [
      ('Off', const Duration()),
      ('End of video', Duration(seconds: (ctrl.activePlayback.duration - ctrl.activePlayback.position).inSeconds)),
      ('10 minutes', const Duration(minutes: 10)),
      ('15 minutes', const Duration(minutes: 15)),
      ('20 minutes', const Duration(minutes: 20)),
      ('30 minutes', const Duration(minutes: 30)),
      ('45 minutes', const Duration(minutes: 45)),
      ('60 minutes', const Duration(minutes: 60)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Sleep timer',
          onBack: () => ctrl.activePanel.value = 'more',
          onClose: null,
        ),
        const PlayerDivider(),
        Obx(() {
          final isActive = ctrl.isSleepTimerActive.value;
          final isAtEnd = ctrl.isSleepTimerAtEndOfVideo.value;
          final rem = ctrl.sleepTimerRemainingSeconds.value;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive && !isAtEnd)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time remaining: ${rem ~/ 60}:${(rem % 60).toString().padLeft(2, '0')}',
                        style: TS.bodySm.copyWith(color: AppColors.brand),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          side: const BorderSide(color: AppColors.brand),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () => ctrl.extendSleepTimer(const Duration(minutes: 5)),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+5 min', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ...options.map((opt) {
                final label = opt.$1;
                final duration = opt.$2;

                var isSelected = false;
                if (label == 'Off') {
                  isSelected = !isActive;
                } else if (isActive) {
                  if (label == 'End of video') {
                    isSelected = isAtEnd;
                  } else if (!isAtEnd) {
                    final diff = (ctrl.sleepTimerRemainingSeconds.value - duration.inSeconds).abs();
                    isSelected = diff < 15;
                  }
                }

                return SelectTile(
                  label: label,
                  selected: isSelected,
                  onTap: () {
                    if (label == 'Off') {
                      ctrl.cancelSleepTimer();
                    } else {
                      ctrl.setSleepTimer(duration, isEndOfVideo: label == 'End of video');
                    }
                    ctrl.activePanel.value = 'more';
                  },
                );
              }),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
