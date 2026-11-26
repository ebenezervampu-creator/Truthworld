import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Pro-audio multi-track DAW waveform monitor & timeline player inspired by
/// ElevenLabs Dubbing Studio.
///
/// Built with TruthWorld Dark Theme and GetX reactive state (Zero `setState` Policy).
class DubbingWaveformPlayer extends StatelessWidget {
  final String title;
  final int durationSeconds;
  final VoidCallback? onPlayToggle;
  final ValueChanged<double>? onSeekPercent;
  final ValueChanged<double>? onSpeedChanged;
  final RxBool? externalIsPlaying;
  final RxInt? externalPositionMs;
  final RxInt? externalDurationMs;
  final RxDouble? externalSpeed;

  DubbingWaveformPlayer({
    required this.title,
    required this.durationSeconds,
    super.key,
    this.onPlayToggle,
    this.onSeekPercent,
    this.onSpeedChanged,
    this.externalIsPlaying,
    this.externalPositionMs,
    this.externalDurationMs,
    this.externalSpeed,
  });

  final RxBool _localPlaying = false.obs;
  final RxDouble _localPositionPercent = 0.0.obs;
  final RxDouble _localSpeed = 1.0.obs;
  final RxBool _muteVocals = false.obs;
  final RxBool _muteBgm = false.obs;

  static const Color _panelBg = Color(0xFF111114);
  static const Color _laneBg = Color(0xFF0A0A0D);

  @override
  Widget build(BuildContext context) {
    final safeDuration = durationSeconds > 0 ? durationSeconds : 60;

    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Transport & Track Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Left: Play Button + Track Title + Timecode
                Obx(() {
                  final playing = externalIsPlaying?.value ?? _localPlaying.value;
                  final totalMs = (externalDurationMs?.value ?? 0) > 0
                      ? externalDurationMs!.value
                      : safeDuration * 1000;
                  final posMs = externalPositionMs != null
                      ? externalPositionMs!.value
                      : (totalMs * _localPositionPercent.value).toInt();
                  final timecode = '${_fmt(posMs ~/ 1000)} / ${_fmt(totalMs ~/ 1000)}';

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (externalIsPlaying == null) {
                            _localPlaying.value = !_localPlaying.value;
                          }
                          onPlayToggle?.call();
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timecode,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                // Right: Quiet Ghost Stem Toggles & Speed
                Obx(() {
                  final vocalsActive = !_muteVocals.value;
                  final bgmActive = !_muteBgm.value;
                  final speedVal = externalSpeed?.value ?? _localSpeed.value;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStemToggle(
                        label: 'Vocals',
                        icon: vocalsActive ? Icons.mic_none_rounded : Icons.mic_off_rounded,
                        isActive: vocalsActive,
                        onTap: () => _muteVocals.value = !_muteVocals.value,
                      ),
                      const SizedBox(width: 6),
                      _buildStemToggle(
                        label: 'BGM / SFX',
                        icon: bgmActive ? Icons.music_note_rounded : Icons.music_off_rounded,
                        isActive: bgmActive,
                        onTap: () => _muteBgm.value = !_muteBgm.value,
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          final next = speedVal == 1.0 ? 1.25 : (speedVal == 1.25 ? 1.5 : 1.0);
                          _localSpeed.value = next;
                          onSpeedChanged?.call(next);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1F),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Text(
                            '${speedVal}x',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),

          // Time Ruler
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF0D0D10),
            child: Obx(() {
              final totalMs = (externalDurationMs?.value ?? 0) > 0
                  ? externalDurationMs!.value
                  : safeDuration * 1000;
              final sec = totalMs ~/ 1000;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(0), style: _rulerStyle),
                  Text(_fmt(sec ~/ 4), style: _rulerStyle),
                  Text(_fmt(sec ~/ 2), style: _rulerStyle),
                  Text(_fmt((sec * 3) ~/ 4), style: _rulerStyle),
                  Text(_fmt(sec), style: _rulerStyle),
                ],
              );
            }),
          ),

          // Multi-Track Waveform Lanes
          Container(
            color: _laneBg,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                _buildTrackLane(
                  tag: 'VOX',
                  tagColor: AppColors.textLink,
                  height: 52,
                  barCount: 96,
                  activeColor: AppColors.textLink,
                  secondaryColor: Colors.white.withValues(alpha: 0.85),
                  safeDuration: safeDuration,
                ),
                const SizedBox(height: 6),
                _buildTrackLane(
                  tag: 'BGM',
                  tagColor: AppColors.textTertiary,
                  height: 26,
                  barCount: 96,
                  activeColor: Colors.white.withValues(alpha: 0.35),
                  secondaryColor: Colors.white.withValues(alpha: 0.25),
                  safeDuration: safeDuration,
                  isBgm: true,
                ),
              ],
            ),
          ),

          // Subtle Footer Specs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MASTER BUS • 48kHz / 24-BIT PCM',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                  ),
                ),
                Text(
                  'Click waveform to scrub',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackLane({
    required String tag,
    required Color tagColor,
    required double height,
    required int barCount,
    required Color activeColor,
    required Color secondaryColor,
    required int safeDuration,
    bool isBgm = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            tag,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: tagColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF121216),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Obx(() {
              final totalMs = (externalDurationMs?.value ?? 0) > 0
                  ? externalDurationMs!.value
                  : safeDuration * 1000;
              final pos = externalPositionMs != null && totalMs > 0
                  ? (externalPositionMs!.value / totalMs).clamp(0.0, 1.0)
                  : _localPositionPercent.value;
              final muted = isBgm ? _muteBgm.value : _muteVocals.value;

              return Row(
                children: List.generate(barCount, (index) {
                  final barRatio = index / barCount;
                  final isPassed = barRatio <= pos;
                  final seed = isBgm ? ((index * 5 + 2) % 9) / 9.0 : ((index * 11 + 3) % 13) / 13.0;
                  final heightFactor = (0.14 + (0.82 * seed)).clamp(0.14, 0.96);

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        _localPositionPercent.value = barRatio;
                        onSeekPercent?.call(barRatio);
                      },
                      child: Center(
                        child: Container(
                          width: 1.8,
                          height: (height - 8) * heightFactor,
                          decoration: BoxDecoration(
                            color: muted
                                ? Colors.white.withValues(alpha: 0.06)
                                : (isPassed
                                    ? (index % 5 == 0 ? secondaryColor : activeColor)
                                    : Colors.white.withValues(alpha: 0.12)),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStemToggle({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF232329) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static const TextStyle _rulerStyle = TextStyle(
    fontFamily: TWTypography.uiFamily,
    color: AppColors.textTertiary,
    fontSize: 9.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
