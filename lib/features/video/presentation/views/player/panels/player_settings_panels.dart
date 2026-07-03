import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'language_requests.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/language_preferences_dialog.dart';

class SettingsPanel extends StatelessWidget {
  final TowerPlayerController ctrl;
  const SettingsPanel({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ctrl.closeSettings,
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
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
                        color: Colors.black.withValues(alpha: 0.7),
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
  final TowerPlayerController ctrl;
  const MainSettingsMenu({super.key, required this.ctrl});

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
              icon: Icons.speed_rounded,
              title: 'Playback Speed',
              value: ctrl.playbackSpeed.value == 1.0
                  ? 'Normal'
                  : '${ctrl.playbackSpeed.value}×',
              onTap: () => ctrl.activePanel.value = 'speed',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.high_quality_rounded,
              title: 'Quality',
              value: ctrl.currentQualityLabel,
              badge: ctrl.abr.isAutoMode.value ? 'AUTO' : null,
              onTap: () => ctrl.activePanel.value = 'quality',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.subtitles_rounded,
              title: 'Subtitles / CC',
              value: ctrl.subtitlesEnabled.value
                  ? ctrl.activeSubLang.value
                  : 'Off',
              onTap: () => ctrl.activePanel.value = 'subtitles',
            ),
          ),
          Obx(
            () => SettingsTile(
              icon: Icons.language_rounded,
              title: 'Audio Language',
              value: ctrl.activeAudioLang.value,
              onTap: () => ctrl.activePanel.value = 'language',
            ),
          ),
          Obx(
            () => ctrl.chapters.isNotEmpty
                ? SettingsTile(
                    icon: Icons.bookmarks_rounded,
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
              icon: Icons.loop_rounded,
              title: 'Loop',
              value: ctrl.isLooping.value,
              onChanged: (_) => ctrl.toggleLoop(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Autoplay Next',
              value: ctrl.isAutoplay.value,
              onChanged: (_) => ctrl.toggleAutoplay(),
            ),
          ),
          Obx(
            () => ToggleTile(
              icon: Icons.audiotrack_rounded,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Chapters panel ─────────────────────────────────────────────────────────────
class ChaptersPanel extends StatelessWidget {
  final TowerPlayerController ctrl;
  const ChaptersPanel({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
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
              return Obx(
                () => SelectTile(
                  label: ch.title,
                  sublabel: ch.formattedStartTime,
                  selected: ctrl.currentChapter.value == ch,
                  onTap: () {
                    ctrl.seekTo(ch.startTime);
                    ctrl.closeSettings();
                  },
                ),
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
  final TowerPlayerController ctrl;
  const SpeedPanel({super.key, required this.ctrl});
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
  final TowerPlayerController ctrl;
  const QualityPanel({super.key, required this.ctrl});

  String _bwLabel(double k) => k > 1000
      ? '${(k / 1000).toStringAsFixed(1)} Mbps'
      : '${k.toStringAsFixed(0)} kbps';

  Color _qColor(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return Colors.greenAccent;
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
      List<VideoResolutionV2> avail = [];
      bool none = false;
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.videocam_off_rounded, size: 48, color: PT.primary),
                  const SizedBox(height: 16),
                  Text('Video Not Available', style: TS.title),
                  const SizedBox(height: 8),
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
                Icon(Icons.speed_rounded, color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Text('Network: ', style: TS.bodySm),
                Text(
                  _bwLabel(ctrl.abr.measuredBandwidthKbps.value),
                  style: TS.bodySm.copyWith(
                    color: _qColor(ctrl.abr.networkQuality.value),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text('Buffer: ', style: TS.bodySm),
                Text(
                  '${ctrl.abr.bufferHealthSeconds.value.toStringAsFixed(1)}s',
                  style: TS.bodySm.copyWith(
                    color: ctrl.abr.bufferHealthSeconds.value < 3
                        ? PT.primary
                        : Colors.greenAccent,
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
                          color: Colors.amber,
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
  final TowerPlayerController ctrl;
  const SubtitlesPanel({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
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
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: Colors.white12,
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
          flex: 1,
          child: LanguageRequestsList(type: 'subtitle', tag: ctrl.tag),
        ),
        const PlayerDivider(),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Obx(() {
              if (ctrl.subtitleTracks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
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
  final TowerPlayerController ctrl;
  const LanguagePanel({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
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
                return Padding(
                  padding: const EdgeInsets.all(24),
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
  final TowerPlayerController ctrl;
  const RatingPanel({super.key, required this.ctrl});

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
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
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
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
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
  final String title;
  final VoidCallback? onBack, onClose;
  const PanelHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconBtn(icon: Icons.arrow_back_ios_new, onTap: onBack!, size: 18)
          else
            const SizedBox(width: 8),
          Expanded(child: Text(title, style: TS.title)),
          if (onClose != null)
            IconBtn(icon: Icons.close_rounded, onTap: onClose!, size: 20),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final String? badge;
  final VoidCallback onTap;
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.badge,
  });

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
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const ToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

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
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class SelectTile extends StatelessWidget {
  final String label;
  final String? sublabel, badge;
  final bool selected, dimmed;
  final VoidCallback? onTap;
  final Widget? trailing;
  const SelectTile({
    super.key,
    required this.label,
    required this.selected,
    this.sublabel,
    this.badge,
    this.dimmed = false,
    this.onTap,
    this.trailing,
  });

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
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: selected
                          ? PT.primary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TS.badge.copyWith(
                        color: selected ? PT.primary : Colors.white38,
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
                            ? Colors.white24
                            : selected
                            ? PT.primary
                            : Colors.white,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        style: TS.bodySm.copyWith(
                          color: dimmed ? Colors.white12 : Colors.white38,
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
    color: Colors.white.withValues(alpha: 0.08),
    height: 12,
    indent: 20,
    endIndent: 20,
  );
}

class ConfigureLanguagesButton extends StatelessWidget {
  final VoidCallback onTap;
  const ConfigureLanguagesButton({super.key, required this.onTap});

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
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
