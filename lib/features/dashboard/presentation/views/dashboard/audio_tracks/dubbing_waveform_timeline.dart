import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_segment_editor_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Pure-Flutter DAW multi-track waveform timeline & M&E / Dialogue stem mixer.
///
/// Zero `setState` (GetX `Obx` only) and high-contrast compliant across light/dark
/// TruthWorld studio themes. All timing and gain faders persist to Firestore and
/// FFmpeg remastering via [DubbingSegmentEditorController].
class DubbingWaveformTimeline extends StatelessWidget {
  final DubbingSegmentEditorController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;
  final bool isDarkMode;

  const DubbingWaveformTimeline({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
    required this.isDarkMode,
    super.key,
  });

  String _formatDb(double linearGain) {
    if (linearGain <= 0.01) return '-∞ dB';
    final db = 20.0 * math.log(linearGain) / math.ln10;
    final prefix = db > 0.05 ? '+' : '';
    return '$prefix${db.toStringAsFixed(1)} dB';
  }

  String _formatMsTime(int ms) {
    final safeMs = ms < 0 ? 0 : ms;
    final totalSec = safeMs ~/ 1000;
    final remMs = (safeMs % 1000) ~/ 10;
    final mins = (totalSec ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs.${remMs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Obx(() {
        final segList = controller.segments.toList();
        final durationMs = controller.totalDurationMs.value > 0
            ? controller.totalDurationMs.value
            : (segList.isNotEmpty
                ? segList.map((s) => s.endMs).reduce(math.max)
                : 10000);
        final selectedIdx = controller.selectedSegmentIndex.value;
        final selectedSeg =
            segList.firstWhereOrNull((s) => s.index == selectedIdx);
        final zoom = controller.timelineZoom.value;
        final mneGain = controller.mneGain.value;
        final dialogueGain = controller.dialogueGain.value;
        final hasMne = controller.hasMneStem.value;
        final hasPendingTimings = controller.hasPendingTimingSave.value;
        final isSavingTimings = controller.isSavingTimings.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Zoom controls
            Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  size: 18,
                  color: isDarkMode ? AppColors.textLink : Colors.black87,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DAW Multi-Track Timeline & Stem Mixer',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  controller.formatTimestamp(durationMs),
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                _ZoomSelector(
                  currentZoom: zoom,
                  onSelect: controller.setTimelineZoom,
                  isDarkMode: isDarkMode,
                  borderColor: borderColor,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Legend row
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _TrackLegendBadge(
                  color: AppColors.success,
                  label: hasMne
                      ? 'M&E Music / Foley (Ducking)'
                      : 'M&E Stem Unavailable',
                  textColor: subTextColor,
                ),
                _TrackLegendBadge(
                  color: AppColors.textLink,
                  label: 'Dubbed Dialogue (${segList.length} segments)',
                  textColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Multi-track canvas
            LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = constraints.maxWidth.clamp(240.0, 2400.0);
                final canvasWidth = viewportWidth * zoom;
                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.bgPage
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (durationMs <= 0 || segList.isEmpty) return;
                        final tapMs =
                            ((details.localPosition.dx / canvasWidth) *
                                    durationMs)
                                .round();
                        DubbingEditableSegmentModel? hit;
                        for (final seg in segList) {
                          if (tapMs >= seg.startMs - 80 &&
                              tapMs <= seg.endMs + 80) {
                            hit = seg;
                            break;
                          }
                        }
                        if (hit != null) {
                          controller.selectSegment(hit.index);
                        }
                      },
                      onHorizontalDragUpdate: (details) {
                        if (selectedSeg == null || durationMs <= 0) return;
                        final deltaMs =
                            ((details.delta.dx / canvasWidth) * durationMs)
                                .round();
                        if (deltaMs == 0) return;
                        final span = selectedSeg.endMs - selectedSeg.startMs;
                        final nextStart = selectedSeg.startMs + deltaMs;
                        controller.updateSegmentTiming(
                          selectedSeg.index,
                          nextStart,
                          nextStart + span,
                        );
                      },
                      child: SizedBox(
                        width: canvasWidth,
                        height: 122,
                        child: CustomPaint(
                          painter: _DawMultiTrackPainter(
                            segments: segList,
                            totalDurationMs: durationMs,
                            selectedSegmentIndex: selectedIdx,
                            mneGain: mneGain,
                            dialogueGain: dialogueGain,
                            hasMneStem: hasMne,
                            isDarkMode: isDarkMode,
                            rulerTextColor: subTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Selected clip precision timing editor bar
            if (selectedSeg != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.bgInput
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textLink.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '#${selectedSeg.index + 1} • ${selectedSeg.speaker}',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_formatMsTime(selectedSeg.startMs)} → ${_formatMsTime(selectedSeg.endMs)} (${selectedSeg.endMs - selectedSeg.startMs}ms)',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasPendingTimings)
                          ElevatedButton.icon(
                            onPressed: isSavingTimings
                                ? null
                                : controller.saveSegmentTimings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 30),
                            ),
                            icon: isSavingTimings
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined,
                                    size: 14, color: Colors.black),
                            label: const Text(
                              'Save Timing',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TimingNudgeGroup(
                          label: 'Start',
                          onMinus: () => controller.updateSegmentTiming(
                            selectedSeg.index,
                            selectedSeg.startMs - 50,
                            selectedSeg.endMs,
                          ),
                          onPlus: () => controller.updateSegmentTiming(
                            selectedSeg.index,
                            selectedSeg.startMs + 50,
                            selectedSeg.endMs,
                          ),
                          textColor: textColor,
                          subTextColor: subTextColor,
                          borderColor: borderColor,
                        ),
                        _TimingNudgeGroup(
                          label: 'End',
                          onMinus: () => controller.updateSegmentTiming(
                            selectedSeg.index,
                            selectedSeg.startMs,
                            selectedSeg.endMs - 50,
                          ),
                          onPlus: () => controller.updateSegmentTiming(
                            selectedSeg.index,
                            selectedSeg.startMs,
                            selectedSeg.endMs + 50,
                          ),
                          textColor: textColor,
                          subTextColor: subTextColor,
                          borderColor: borderColor,
                        ),
                        if (selectedSeg.voiceQuality != null)
                          _TelemetryChip(
                            label: 'Voice: ${selectedSeg.voiceQuality}',
                            subTextColor: subTextColor,
                            borderColor: borderColor,
                          ),
                        if (selectedSeg.syllableBudgetCompliance != null)
                          _TelemetryChip(
                            label:
                                'Syllable Fit: ${(selectedSeg.syllableBudgetCompliance! * 100).round()}%',
                            subTextColor: subTextColor,
                            borderColor: borderColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // M&E & Dialogue Stem Fader Mixer
            Row(
              children: [
                Expanded(
                  child: _StemFaderControl(
                    title: 'M&E Music Stem',
                    gain: mneGain,
                    dbLabel: _formatDb(mneGain),
                    min: 0.0,
                    max: 2.0,
                    accentColor: AppColors.success,
                    enabled: hasMne,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    onChanged: controller.setMneGain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StemFaderControl(
                    title: 'Dialogue Stem',
                    gain: dialogueGain,
                    dbLabel: _formatDb(dialogueGain),
                    min: 0.2,
                    max: 2.0,
                    accentColor: AppColors.textLink,
                    enabled: true,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    onChanged: controller.setDialogueGain,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _ZoomSelector extends StatelessWidget {
  final double currentZoom;
  final ValueChanged<double> onSelect;
  final bool isDarkMode;
  final Color borderColor;

  const _ZoomSelector({
    required this.currentZoom,
    required this.onSelect,
    required this.isDarkMode,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    const levels = [1.0, 2.0, 4.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: levels.map((z) {
        final selected = (currentZoom - z).abs() < 0.05;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: InkWell(
            onTap: () => onSelect(z),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brand
                    : (isDarkMode ? AppColors.bgInput : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? AppColors.brand : borderColor,
                ),
              ),
              child: Text(
                '${z.toInt()}x',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.black
                      : (isDarkMode ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TrackLegendBadge extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _TrackLegendBadge({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: textColor, fontSize: 11),
        ),
      ],
    );
  }
}

class _TimingNudgeGroup extends StatelessWidget {
  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;

  const _TimingNudgeGroup({
    required this.label,
    required this.onMinus,
    required this.onPlus,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: subTextColor, fontSize: 11),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onMinus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                '-50ms',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Text('|', style: TextStyle(color: borderColor, fontSize: 11)),
          InkWell(
            onTap: onPlus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                '+50ms',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  final String label;
  final Color subTextColor;
  final Color borderColor;

  const _TelemetryChip({
    required this.label,
    required this.subTextColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(color: subTextColor, fontSize: 11),
      ),
    );
  }
}

class _StemFaderControl extends StatelessWidget {
  final String title;
  final double gain;
  final String dbLabel;
  final double min;
  final double max;
  final Color accentColor;
  final bool enabled;
  final Color textColor;
  final Color subTextColor;
  final ValueChanged<double> onChanged;

  const _StemFaderControl({
    required this.title,
    required this.gain,
    required this.dbLabel,
    required this.min,
    required this.max,
    required this.accentColor,
    required this.enabled,
    required this.textColor,
    required this.subTextColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: enabled ? textColor : subTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(gain * 100).round()}% ($dbLabel)',
              style: TextStyle(
                color: subTextColor,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            thumbColor: accentColor,
            inactiveTrackColor: accentColor.withValues(alpha: 0.25),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: gain.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 20).round(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}

class _DawMultiTrackPainter extends CustomPainter {
  final List<DubbingEditableSegmentModel> segments;
  final int totalDurationMs;
  final int? selectedSegmentIndex;
  final double mneGain;
  final double dialogueGain;
  final bool hasMneStem;
  final bool isDarkMode;
  final Color rulerTextColor;

  const _DawMultiTrackPainter({
    required this.segments,
    required this.totalDurationMs,
    required this.selectedSegmentIndex,
    required this.mneGain,
    required this.dialogueGain,
    required this.hasMneStem,
    required this.isDarkMode,
    required this.rulerTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final safeDuration = math.max(1, totalDurationMs);
    final gridPaint = Paint()
      ..color = (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1;

    // 1. Time ruler header (top 22px)
    const rulerHeight = 22.0;
    canvas.drawLine(
      const Offset(0, rulerHeight),
      Offset(size.width, rulerHeight),
      gridPaint,
    );

    final tickCount = math.max(4, (size.width / 120).floor());
    for (var i = 0; i <= tickCount; i++) {
      final x = (size.width / tickCount) * i;
      canvas.drawLine(
        Offset(x, rulerHeight - 6),
        Offset(x, size.height),
        gridPaint,
      );
      if (i < tickCount) {
        final ms = ((i / tickCount) * safeDuration).round();
        final sec = ms ~/ 1000;
        final label =
            '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(color: rulerTextColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 4, 4));
      }
    }

    // 2. Lane divider between Dialogue Track (24..72) & M&E Track (76..118)
    const dialogueTop = 26.0;
    const dialogueHeight = 44.0;
    const mneTop = 76.0;
    const mneHeight = 40.0;

    canvas.drawLine(
      const Offset(0, mneTop - 3),
      Offset(size.width, mneTop - 3),
      gridPaint,
    );

    // 3. M&E Sidechain-Ducked Envelope Track (green lane derived from real dialogue segment timings)
    if (hasMneStem) {
      final mneFillPaint = Paint()
        ..color = AppColors.success
            .withValues(alpha: (0.28 * mneGain.clamp(0.2, 1.5)).clamp(0.12, 0.72));
      final mneStrokePaint = Paint()
        ..color = AppColors.success.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      const sampleCols = 140;
      final path = Path()..moveTo(0, mneTop + mneHeight);
      final topPath = Path();
      const centerY = mneTop + mneHeight * 0.5;

      for (var i = 0; i <= sampleCols; i++) {
        final ratio = i / sampleCols;
        final tMs = (ratio * safeDuration).round();
        final x = ratio * size.width;
        final isUnderDialogue = segments.any(
          (s) => tMs >= s.startMs && tMs <= s.endMs,
        );
        // Sidechain compression ducks M&E level during dialogue windows
        final duckFactor = isUnderDialogue ? 0.36 : 0.82;
        final ripple = 0.85 + 0.15 * math.sin(i * 0.55);
        final amp =
            (mneHeight * 0.42) * duckFactor * ripple * mneGain.clamp(0.0, 1.4);
        final yTop = (centerY - amp).clamp(mneTop + 2, mneTop + mneHeight - 2);
        if (i == 0) {
          topPath.moveTo(x, yTop);
        } else {
          topPath.lineTo(x, yTop);
        }
        path.lineTo(x, yTop);
      }
      path.lineTo(size.width, mneTop + mneHeight);
      path.close();
      canvas.drawPath(path, mneFillPaint);
      canvas.drawPath(topPath, mneStrokePaint);
    }

    // 4. Dubbed Dialogue Segment Clips & Real Energy Envelope Bars
    for (final seg in segments) {
      final left = (seg.startMs / safeDuration) * size.width;
      final right = (seg.endMs / safeDuration) * size.width;
      final clipWidth = math.max(8.0, right - left);
      final isSelected = seg.index == selectedSegmentIndex;

      final clipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, dialogueTop, clipWidth, dialogueHeight),
        const Radius.circular(6),
      );

      final clipFill = Paint()
        ..color = isSelected
            ? AppColors.textLink.withValues(alpha: 0.38)
            : AppColors.textLink.withValues(alpha: 0.22);
      final clipBorder = Paint()
        ..color = isSelected ? Colors.white : AppColors.textLink
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.8 : 1.0;

      canvas.drawRRect(clipRect, clipFill);
      canvas.drawRRect(clipRect, clipBorder);

      // Compute normalized amplitude from real FFmpeg measured segment RMS energyDb (-45dB..0dB)
      final energyDb = seg.energyDb ?? -18.0;
      final normalizedEnergy =
          (((energyDb + 45.0) / 45.0).clamp(0.22, 1.0)) *
              dialogueGain.clamp(0.2, 1.6);

      final barCount = math.max(2, (clipWidth / 5).floor()).clamp(2, 32);
      final barSpacing = clipWidth / barCount;
      final barPaint = Paint()
        ..color = isSelected ? Colors.white : AppColors.textLink
        ..strokeWidth = math.min(2.6, barSpacing * 0.6)
        ..strokeCap = StrokeCap.round;

      const midY = dialogueTop + dialogueHeight * 0.5;
      for (var b = 0; b < barCount; b++) {
        final bx = left + barSpacing * (b + 0.5);
        final phase = (b + 1) / (barCount + 1);
        final envelope = math.sin(phase * math.pi);
        final halfBar = (dialogueHeight * 0.36 * normalizedEnergy * envelope)
            .clamp(3.0, dialogueHeight * 0.44);
        canvas.drawLine(
          Offset(bx, midY - halfBar),
          Offset(bx, midY + halfBar),
          barPaint,
        );
      }

      if (isSelected) {
        final handlePaint = Paint()..color = Colors.white;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, dialogueTop + 6, 4, dialogueHeight - 12),
            const Radius.circular(2),
          ),
          handlePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
                left + clipWidth - 4, dialogueTop + 6, 4, dialogueHeight - 12),
            const Radius.circular(2),
          ),
          handlePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DawMultiTrackPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.totalDurationMs != totalDurationMs ||
        oldDelegate.selectedSegmentIndex != selectedSegmentIndex ||
        oldDelegate.mneGain != mneGain ||
        oldDelegate.dialogueGain != dialogueGain ||
        oldDelegate.hasMneStem != hasMneStem ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
