import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive dialog and bottom sheet for clipping moments from videos with
/// responsive range sliders, precision micro-steppers, duration presets, playhead anchoring,
/// live in-dialog segment preview, and direct creation.
class VideoClipDialog {
  static void show({
    required BuildContext context,
    required VideoController controller,
    required VoidCallback onSignInPrompt,
  }) {
    if (!AuthService.to.isAuthenticated.value) {
      onSignInPrompt();
      return;
    }

    final clipController = Get.put(ClipController(video: controller.video));

    // Check creator permission and content safety restrictions
    final restriction = clipController.getClippingRestrictionReason();
    if (restriction != null) {
      Get.delete<ClipController>();
      AppSnackbar.info(
        restriction,
        title: 'Clipping Notice',
      );
      return;
    }

    // Attempt to get video duration and current position for slider
    final totalDuration =
        controller.videoPlayerController?.value.duration.inSeconds.toDouble() ??
        (controller.video.durationSeconds > 0
            ? controller.video.durationSeconds.toDouble()
            : 300.0);

    if (totalDuration < 15.0) {
      Get.delete<ClipController>();
      AppSnackbar.info(
        'This video is too short to create clips from (minimum 15 seconds required).',
        title: 'Clipping Unavailable',
      );
      return;
    }

    final currentPos =
        controller.videoPlayerController?.value.position.inSeconds.toDouble() ??
        0.0;

    clipController.initialize(
      totalDur: totalDuration,
      currentPos: currentPos,
      videoCtrl: controller,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth >= 600;

    if (isDesktopOrTablet) {
      Get.dialog<void>(
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 560,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white12,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: _VideoClipDialogBody(
                    clipController: clipController,
                    videoController: controller,
                    isDesktop: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        barrierColor: Colors.black.withValues(alpha: 0.8),
      ).whenComplete(() {
        if (Get.isRegistered<ClipController>()) {
          Get.delete<ClipController>();
        }
      });
    } else {
      Get.bottomSheet<void>(
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: _VideoClipDialogBody(
              clipController: clipController,
              videoController: controller,
              isDesktop: false,
            ),
          ),
        ),
        barrierColor: Colors.black.withValues(alpha: 0.75),
        isScrollControlled: true,
      ).whenComplete(() {
        if (Get.isRegistered<ClipController>()) {
          Get.delete<ClipController>();
        }
      });
    }
  }
}

class _VideoClipDialogBody extends StatelessWidget {
  const _VideoClipDialogBody({
    required this.clipController,
    required this.videoController,
    required this.isDesktop,
  });

  final ClipController clipController;
  final VideoController videoController;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.content_cut_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create Clip',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: Get.back,
              tooltip: 'Close',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Title Input
        TextField(
          onChanged: clipController.onTitleChanged,
          maxLength: 100,
          inputFormatters: TruthworldTextInputFormatters.withLimit(100),
          style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Add a title (3-100 characters)...',
            hintStyle: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 14),
            counterStyle: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 11),
            filled: true,
            fillColor: AppColors.bgPage.withValues(alpha: 0.8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        Obx(() {
          if (clipController.titleError.value.isEmpty) {
            return const SizedBox(height: 6);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    clipController.titleError.value,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Segment Selection Section
        _SegmentHeader(clipController: clipController),
        const SizedBox(height: 10),

        // Duration Presets & Quick Select Bar
        _DurationPresetChips(clipController: clipController),
        const SizedBox(height: 12),

        // Interactive Timeline Scrubber Bar
        _TimelineSlider(clipController: clipController),
        const SizedBox(height: 14),

        // Precision Steppers & Playhead Anchors
        _SegmentSteppersSection(clipController: clipController),
        const SizedBox(height: 12),

        // Preview & Window Shifter Controls Bar
        _PreviewAndShiftToolbar(clipController: clipController),
        const SizedBox(height: 24),

        // Action Buttons (Save Clip / Share Clip)
        _ActionButtons(clipController: clipController),
      ],
    );
  }
}

class _SegmentHeader extends StatelessWidget {
  const _SegmentHeader({required this.clipController});
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'SELECT SEGMENT',
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Obx(() {
          final duration =
              clipController.endSeconds.value - clipController.startSeconds.value;
          final isOutOfRange = duration < clipController.minDuration ||
              duration > clipController.maxDuration;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isOutOfRange
                  ? AppColors.error.withValues(alpha: 0.2)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isOutOfRange ? AppColors.error : Colors.white24,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: isOutOfRange ? AppColors.error : Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  '${duration.toStringAsFixed(1)}s',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isOutOfRange ? AppColors.error : Colors.white,
                  ),
                ),
                Text(
                  ' (5s-30s)',
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DurationPresetChips extends StatelessWidget {
  const _DurationPresetChips({required this.clipController});
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    final presets = [5.0, 10.0, 15.0, 30.0];

    return Obx(() {
      final currentSpan =
          (clipController.endSeconds.value - clipController.startSeconds.value)
              .roundToDouble();

      return Row(
        children: [
          Text(
            'Quick Length:',
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: presets.map((seconds) {
                final isSelected = (currentSpan - seconds).abs() < 0.6;
                return InkWell(
                  onTap: () => clipController.setDurationPreset(seconds),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '${seconds.toInt()}s',
                      style: GoogleFonts.roboto(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }
}

class _TimelineSlider extends StatelessWidget {
  const _TimelineSlider({required this.clipController});
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = clipController.totalDuration.value > 0
          ? clipController.totalDuration.value
          : 300.0;
      final start = clipController.startSeconds.value.clamp(0.0, total);
      final end = clipController.endSeconds.value.clamp(start, total);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.brand,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: AppColors.brand.withValues(alpha: 0.2),
                trackHeight: 6.0,
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  elevation: 4,
                ),
                rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
              ),
              child: RangeSlider(
                values: RangeValues(start, end),
                max: total,
                labels: RangeLabels(
                  FormatUtils.formatDuration(Duration(seconds: start.toInt())),
                  FormatUtils.formatDuration(Duration(seconds: end.toInt())),
                ),
                onChanged: (values) {
                  var s = values.start;
                  var e = values.end;
                  final span = e - s;
                  if (span < clipController.minDuration) {
                    if ((s - clipController.startSeconds.value).abs() >
                        (e - clipController.endSeconds.value).abs()) {
                      s = (e - clipController.minDuration).clamp(0.0, total);
                    } else {
                      e = (s + clipController.minDuration).clamp(0.0, total);
                    }
                  }
                  if (e - s > clipController.maxDuration) {
                    if ((s - clipController.startSeconds.value).abs() >
                        (e - clipController.endSeconds.value).abs()) {
                      e = (s + clipController.maxDuration).clamp(0.0, total);
                    } else {
                      s = (e - clipController.maxDuration).clamp(0.0, total);
                    }
                  }
                  clipController.updateStart(s);
                  clipController.updateEnd(e);
                  clipController.videoControllerRef?.videoPlayerController
                      ?.seekTo(Duration(seconds: s.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    FormatUtils.formatDuration(Duration(seconds: start.toInt())),
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(end - start).toStringAsFixed(1)}s',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    FormatUtils.formatDuration(Duration(seconds: end.toInt())),
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SegmentSteppersSection extends StatelessWidget {
  const _SegmentSteppersSection({required this.clipController});
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;

        final startCard = _TimeAdjustCard(
          label: 'START TIME',
          isStart: true,
          clipController: clipController,
        );

        final endCard = _TimeAdjustCard(
          label: 'END TIME',
          isStart: false,
          clipController: clipController,
        );

        if (isNarrow) {
          return Column(
            children: [
              startCard,
              const SizedBox(height: 8),
              endCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: startCard),
            const SizedBox(width: 8),
            Expanded(child: endCard),
          ],
        );
      },
    );
  }
}

class _TimeAdjustCard extends StatelessWidget {
  const _TimeAdjustCard({
    required this.label,
    required this.isStart,
    required this.clipController,
  });

  final String label;
  final bool isStart;
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Obx(() {
            final seconds = isStart
                ? clipController.startSeconds.value
                : clipController.endSeconds.value;
            return Text(
              FormatUtils.formatDuration(Duration(seconds: seconds.toInt())),
              style: GoogleFonts.robotoMono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }),
          const SizedBox(height: 6),
          // Stepper +/- 1s buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                label: '-1s',
                onTap: () {
                  if (isStart) {
                    clipController.stepStart(-1.0);
                  } else {
                    clipController.stepEnd(-1.0);
                  }
                },
              ),
              const SizedBox(width: 6),
              _StepButton(
                label: '+1s',
                onTap: () {
                  if (isStart) {
                    clipController.stepStart(1.0);
                  } else {
                    clipController.stepEnd(1.0);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Set to current playhead button
          InkWell(
            onTap: isStart
                ? clipController.setStartToPlayhead
                : clipController.setEndToPlayhead,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Use Current',
                      style: GoogleFonts.roboto(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PreviewAndShiftToolbar extends StatelessWidget {
  const _PreviewAndShiftToolbar({required this.clipController});
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          // Preview button
          Obx(() {
            final isPlaying = clipController.isPreviewPlaying.value;
            return InkWell(
              onTap: clipController.togglePreview,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPlaying ? AppColors.brand : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPlaying ? AppColors.brand : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 15,
                      color: isPlaying ? Colors.black : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPlaying ? 'Pause' : 'Preview Clip',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPlaying ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Window Shift Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Shift: ',
                style: GoogleFonts.roboto(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: () => clipController.shiftSegment(-5.0),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fast_rewind_rounded,
                          size: 12, color: Colors.white),
                      Text(
                        ' 5s',
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => clipController.shiftSegment(5.0),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '5s ',
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.fast_forward_rounded,
                          size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.clipController});
  final ClipController clipController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSaving = clipController.isSaving.value;
      return Column(
        children: [
          Row(
            children: [
              // Save Clip
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : clipController.saveClip,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.bookmark_add_rounded,
                            color: Colors.black,
                            size: 19,
                          ),
                    label: Text(
                      'Save Clip',
                      style: GoogleFonts.roboto(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Share Clip
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        clipController.shareClipWithWatermark(context),
                    icon: const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    label: Text(
                      'Share Clip',
                      style: GoogleFonts.roboto(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.bgSurface.withValues(alpha: 0.85),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: AppColors.brand.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: Get.back,
              child: Text(
                'Cancel',
                style: GoogleFonts.roboto(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
