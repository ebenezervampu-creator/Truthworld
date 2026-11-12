import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_segment_editor_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_waveform_timeline.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive Creator Dubbing Timeline Editor
/// Allows creators to fine-tune translated lines, switch ElevenLabs v4 emotion tags,
/// configure pronunciation glossaries, preview single lines, and remaster the full track.
class DubbingSegmentEditorPage extends StatelessWidget {
  final String videoId;
  final String languageCode;
  final String languageName;
  final bool isDarkMode;
  final Future<void> Function()? onRemastered;

  const DubbingSegmentEditorPage({
    required this.videoId,
    required this.languageCode,
    required this.languageName,
    this.isDarkMode = true,
    this.onRemastered,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tag = '${videoId}_$languageCode';
    final controller = Get.put(
      DubbingSegmentEditorController(
        videoId: videoId,
        languageCode: languageCode,
        languageName: languageName,
        onRemastered: onRemastered,
      ),
      tag: tag,
    );

    final bgColor = isDarkMode ? AppColors.bgPage : const Color(0xFFF6F7F9);
    final surfaceColor = isDarkMode ? AppColors.bgSurface : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop &&
            Get.isRegistered<DubbingSegmentEditorController>(tag: tag)) {
          Get.delete<DubbingSegmentEditorController>(tag: tag);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          foregroundColor: textColor,
          elevation: 0,
          title: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$languageName Dubbing Studio',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'v${controller.manifestVersion.value} • ${controller.segments.length} dialogue lines',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
              child: Obx(
                () => ElevatedButton.icon(
                  onPressed: controller.isRemastering.value ||
                          controller.isLoading.value ||
                          controller.segments.isEmpty
                      ? null
                      : controller.remasterAndPublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: controller.isRemastering.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.graphic_eq_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                  label: Text(
                    controller.hasPendingRemaster.value
                        ? 'Remaster & Publish*'
                        : 'Remaster & Publish',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: textColor),
            );
          }

          if (controller.errorMessage.value.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.multitrack_audio_rounded,
                      size: 44,
                      color: subTextColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: controller.loadManifest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DubbingWaveformTimeline(
                controller: controller,
                surfaceColor: surfaceColor,
                textColor: textColor,
                subTextColor: subTextColor,
                borderColor: borderColor,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),
              _GlossarySection(
                controller: controller,
                surfaceColor: surfaceColor,
                textColor: textColor,
                subTextColor: subTextColor,
                borderColor: borderColor,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),
              ...controller.segments.map(
                (seg) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SegmentCard(
                    controller: controller,
                    segment: seg,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    borderColor: borderColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _GlossarySection extends StatelessWidget {
  final DubbingSegmentEditorController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;
  final bool isDarkMode;

  const _GlossarySection({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spellcheck_rounded, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pronunciation Glossary & Brand Names',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Obx(
                () => ElevatedButton(
                  onPressed: controller.isSavingGlossary.value
                      ? null
                      : controller.saveGlossaryRules,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    controller.isSavingGlossary.value
                        ? 'Saving...'
                        : 'Save Glossary',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.glossaryTermController,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Word or brand (e.g. TruthWorld)',
                    hintStyle: TextStyle(color: subTextColor, fontSize: 12),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller.glossaryReplacementController,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Phonetic spelling (e.g. Trooth-Wurld)',
                    hintStyle: TextStyle(color: subTextColor, fontSize: 12),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: controller.addGlossaryRule,
                icon: Icon(Icons.add_circle_outline_rounded, color: textColor),
                tooltip: 'Add pronunciation rule',
              ),
            ],
          ),
          Obx(() {
            if (controller.glossary.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: controller.glossary.map((rule) {
                  return Chip(
                    backgroundColor:
                        isDarkMode ? AppColors.bgPage : Colors.grey.shade200,
                    label: Text(
                      '${rule.term} → ${rule.replacement}',
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                    deleteIconColor: textColor,
                    onDeleted: () => controller.removeGlossaryRule(rule.id),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final DubbingSegmentEditorController controller;
  final DubbingEditableSegmentModel segment;
  final Color surfaceColor;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;
  final bool isDarkMode;

  const _SegmentCard({
    required this.controller,
    required this.segment,
    required this.surfaceColor,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textController = controller.controllerForSegment(segment);
    final stability = (segment.stabilityOverride ?? 0.45).clamp(0.25, 0.70);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.bgPage : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${segment.index + 1} • ${controller.formatTimestamp(segment.startMs)} - ${controller.formatTimestamp(segment.endMs)}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                segment.speaker,
                style: TextStyle(color: subTextColor, fontSize: 12),
              ),
              const Spacer(),
              Obx(
                () => IconButton(
                  onPressed: () => controller.playSegmentPreview(segment),
                  icon: Icon(
                    controller.playingSegmentIndex.value == segment.index
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill_rounded,
                    color: textColor,
                  ),
                  tooltip: 'Preview dubbed line',
                ),
              ),
            ],
          ),
          if (segment.originalText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Original: ${segment.originalText}',
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: textController,
            maxLines: 2,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Translated & Spoken Line (ElevenLabs v4)',
              labelStyle: TextStyle(color: subTextColor, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              DropdownButton<String>(
                value: DubbingSegmentEditorController.supportedEmotionTags
                        .contains(segment.emotionTag)
                    ? segment.emotionTag
                    : '',
                dropdownColor: surfaceColor,
                style: TextStyle(color: textColor, fontSize: 12),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text('Emotion: Natural',
                        style: TextStyle(color: textColor)),
                  ),
                  ...DubbingSegmentEditorController.supportedEmotionTags.map(
                    (tag) => DropdownMenuItem(
                      value: tag,
                      child: Text('[$tag]', style: TextStyle(color: textColor)),
                    ),
                  ),
                ],
                onChanged: (val) =>
                    controller.setSegmentEmotionTag(segment.index, val),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expressiveness (Stability ${stability.toStringAsFixed(2)})',
                      style: TextStyle(color: subTextColor, fontSize: 11),
                    ),
                    Slider(
                      value: stability,
                      min: 0.25,
                      max: 0.70,
                      divisions: 9,
                      activeColor: textColor,
                      onChanged: (val) =>
                          controller.setSegmentStability(segment.index, val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final busy =
                    controller.regeneratingSegmentIndex.value == segment.index;
                return ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => controller.regenerateSegment(segment.index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          size: 15,
                          color: Colors.black,
                        ),
                  label: Text(
                    busy ? 'Synthesizing...' : 'Regenerate',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
