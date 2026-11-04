import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/subtitles/advertiser_subtitle_cue_row.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/subtitles/advertiser_subtitles_dialogs.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/pipeline_progress_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Main editor area managing tracks, cues, and translation pipeline for the selected ad.
class AdvertiserSubtitlesEditor extends StatelessWidget {
  const AdvertiserSubtitlesEditor({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.selectedAdForSubtitles.value == null) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.subtitles_outlined,
                size: 64,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Select a video campaign from the list to begin editing subtitles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      final ad = controller.selectedAdForSubtitles.value!;
      final subs = ad.subtitles ?? {};

      return Container(
        color: AppColors.appBarSurface,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;
                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage language subtitles track and cue timings',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.isUploadingSubtitles.value
                          ? null
                          : () => showUploadSubtitlesDialog(controller),
                      icon: controller.isUploadingSubtitles.value
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.upload_file_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                      label: const Text(
                        'Upload Subtitles',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.bgElevated),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: controller.isSavingSubtitles.value
                          ? null
                          : controller.saveSubtitlesForAd,
                      icon: controller.isSavingSubtitles.value
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.black),
                              ),
                            )
                          : const Icon(
                              Icons.save_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                      label: Text(
                        controller.isSavingSubtitles.value
                            ? 'Saving...'
                            : 'Save Track',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleSection),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Tracks:',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final lang in controller.supportedLanguages)
                          if (subs.containsKey(lang['code']) ||
                              lang['code'] == 'en')
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(lang['name']!),
                                selected: controller
                                        .selectedLanguageForSubtitles.value ==
                                    lang['code'],
                                onSelected: (_) {
                                  controller.selectedLanguageForSubtitles
                                      .value = lang['code']!;
                                  controller.loadCuesForAd(ad, lang['code']!);
                                },
                                selectedColor: AppColors.brand,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: controller
                                                .selectedLanguageForSubtitles
                                                .value ==
                                            lang['code']
                                        ? AppColors.brand
                                        : AppColors.bgSurface,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: controller
                                              .selectedLanguageForSubtitles
                                              .value ==
                                          lang['code']
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                backgroundColor: AppColors.bgPage,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Add translated subtitles track',
                  onPressed: () => showAddSubtitlesTrackDialog(controller),
                ),
              ],
            ),
            const Divider(color: AppColors.bgSurface, height: 32),
            if (controller.isTranslatingSubtitles.value)
              PipelineProgressCard(
                status: controller.subtitleStatusText.value,
                progress: controller.subtitleProgress.value,
              )
            else ...[
              Expanded(
                child: controller.currentSubtitleCues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.notes_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No subtitle cues defined.',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                controller.currentSubtitleCues.add({
                                  'id': DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  'startTime': '00:00:01.000',
                                  'endTime': '00:00:05.000',
                                  'text': 'Enter subtitle text...',
                                });
                              },
                              icon: const Icon(
                                Icons.add,
                                color: Colors.black,
                                size: 16,
                              ),
                              label: const Text(
                                'Add Cue',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: controller.currentSubtitleCues.length,
                        itemBuilder: (context, index) {
                          final cue = controller.currentSubtitleCues[index];
                          return AdvertiserSubtitleCueRow(
                            controller: controller,
                            index: index,
                            cue: cue,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final lastEnd =
                          controller.currentSubtitleCues.isNotEmpty
                              ? controller
                                  .currentSubtitleCues.last['endTime']!
                              : '00:00:00.000';
                      controller.currentSubtitleCues.add({
                        'id':
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        'startTime': lastEnd,
                        'endTime': '00:00:20.000',
                        'text': 'New segment...',
                      });
                    },
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Add Cue Segment',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.bgSurface),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final vtt = controller.exportCuesToVtt();
                      Clipboard.setData(ClipboardData(text: vtt));
                      AppSnackbar.show(
                        'Exported',
                        'WebVTT subtitle track copied to clipboard successfully!',
                        backgroundColor: AppColors.success,
                        colorText: AppColors.textPrimary,
                      );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Copy WebVTT',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.bgSurface),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
