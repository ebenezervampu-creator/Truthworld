import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/pipeline_progress_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdvertiserSubtitlesTab extends StatelessWidget {
  const AdvertiserSubtitlesTab({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return _buildSubtitlesTab(context, controller);
  }

   Widget _buildSubtitlesTab(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Obx(() {
      final skippableCampaigns = AdService.to.customCampaigns
          .where((ad) =>
              ad.userId == AuthService.to.uid &&
              (ad.isSkippableAd ||
                  (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) ||
                  (ad.midrollVideoUrl != null &&
                      ad.midrollVideoUrl!.isNotEmpty) ||
                  (ad.resolutions != null && ad.resolutions!.isNotEmpty)))
          .toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 800;
          final listWidget = _buildSubtitlesCampaignsSidebar(
            controller,
            skippableCampaigns,
          );
          final editorWidget = _buildSubtitlesEditorArea(controller);

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: listWidget),
                const VerticalDivider(color: Color(0xFF27272A), width: 1),
                Expanded(child: editorWidget),
              ],
            );
          } else {
            return controller.selectedAdForSubtitles.value == null
                ? listWidget
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFF161618),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                controller.selectedAdForSubtitles.value = null;
                              },
                            ),
                            const Text(
                              'Back to Ads List',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: editorWidget),
                    ],
                  );
          }
        },
      );
    });
  }

  Widget _buildSubtitlesCampaignsSidebar(
    AdvertiserPortalController controller,
    List<AdItem> campaigns,
  ) {
    return ColoredBox(
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Video Ad to Translate',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: Obx(
                () => OutlinedButton.icon(
                  onPressed: controller.isGeneratingAllVideoAdsAI.value
                      ? null
                      : () => controller.generateAllVideoAdsAI(),
                  icon: controller.isGeneratingAllVideoAdsAI.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                  label: Text(
                    controller.isGeneratingAllVideoAdsAI.value
                        ? 'Queueing Batch AI...'
                        : 'Generate AI for All Video Ads',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF27272A), height: 1),
          Expanded(
            child: campaigns.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No video campaigns available. Subtitles can only be added to Skippable Video ads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: campaigns.length,
                    itemBuilder: (context, index) {
                      final ad = campaigns[index];
                      final isSelected =
                          controller.selectedAdForSubtitles.value?.id == ad.id;
                      final langCount = (ad.subtitles ?? {}).length;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brand.withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: const Border(
                            bottom: BorderSide(
                              color: Color(0xFF27272A),
                            ),
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            controller.selectedAdForSubtitles.value = ad;
                            controller.selectedLanguageForSubtitles.value =
                                'en';
                            controller.loadCuesForAd(ad, 'en');
                          },
                          leading: Container(
                            width: 50,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: ad.gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '$langCount Language track${langCount == 1 ? "" : "s"}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesEditorArea(AdvertiserPortalController controller) {
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
      color: const Color(0xFF161618),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
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
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.isUploadingSubtitles.value
                        ? null
                        : () => _showUploadSubtitlesDialog(controller),
                    icon: controller.isUploadingSubtitles.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded, color: Colors.white, size: 16),
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
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: controller.isSavingSubtitles.value
                        ? null
                        : () => controller.saveSubtitlesForAd(),
                    icon: controller.isSavingSubtitles.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.black),
                            ),
                          )
                        : const Icon(Icons.save_rounded, color: Colors.black, size: 16),
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
              ),
            ],
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
                              selected:
                                  controller
                                      .selectedLanguageForSubtitles
                                      .value ==
                                  lang['code'],
                              onSelected: (_) {
                                controller.selectedLanguageForSubtitles.value =
                                    lang['code']!;
                                controller.loadCuesForAd(ad, lang['code']!);
                              },
                              selectedColor: AppColors.brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: controller.selectedLanguageForSubtitles.value == lang['code']
                                      ? AppColors.brand
                                      : const Color(0xFF27272A),
                                ),
                              ),
                              labelStyle: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color:
                                    controller
                                            .selectedLanguageForSubtitles
                                            .value ==
                                        lang['code']
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: const Color(0xFF18181B),
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
                onPressed: () => _showAddSubtitlesTrackDialog(controller),
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 32),
          if (controller.isTranslatingSubtitles.value)
            _buildPipelineProgressCard(
              controller.subtitleStatusText.value,
              controller.subtitleProgress.value,
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
                                'id': DateTime.now().millisecondsSinceEpoch
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
                        return _buildSubtitleCueRow(controller, index, cue);
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    final lastEnd = controller.currentSubtitleCues.isNotEmpty
                        ? controller.currentSubtitleCues.last['endTime']!
                        : '00:00:00.000';
                    controller.currentSubtitleCues.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'startTime': lastEnd,
                      'endTime': '00:00:20.000',
                      'text': 'New segment...',
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
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
                    side: const BorderSide(color: Color(0xFF27272A)),
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
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
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
                    side: const BorderSide(color: Color(0xFF27272A)),
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
  }

  Widget _buildSubtitleCueRow(
    AdvertiserPortalController controller,
    int index,
    Map<String, String> cue,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Column(
              children: [
                _buildTimeInputField('Start Time', cue['startTime']!, (val) {
                  controller.currentSubtitleCues[index]['startTime'] = val;
                  controller.currentSubtitleCues.refresh();
                }),
                const SizedBox(height: 8),
                _buildTimeInputField('End Time', cue['endTime']!, (val) {
                  controller.currentSubtitleCues[index]['endTime'] = val;
                  controller.currentSubtitleCues.refresh();
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              inputFormatters: const [TruthworldTextInputFormatters.profanityFilter],
              controller: TextEditingController(text: cue['text'])
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: cue['text']!.length),
                ),
              onChanged: (val) {
                controller.currentSubtitleCues[index]['text'] = val;
                controller.currentSubtitleCues.refresh();
              },
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 13,
              ),
              maxLines: 2,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter cue subtitles text...',
                hintStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              controller.currentSubtitleCues.removeAt(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInputField(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                fillColor: const Color(0xFF18181B),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineProgressCard(String status, double progress) {
    return PipelineProgressCard(status: status, progress: progress);
  }

  void _showAddSubtitlesTrackDialog(AdvertiserPortalController controller) {
    final selectedLang = 'hi'.obs;

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Add Subtitles Track',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Translate your video campaign into another language using AI voice translation.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedLanguages)
                        if (lang['code'] != 'en')
                          DropdownMenuItem(
                            value: lang['code'],
                            child: Text(
                              lang['name']!,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedLang.value = val;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                controller.requestAdSubtitles(selectedLang.value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start AI Translation',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadSubtitlesDialog(AdvertiserPortalController controller) {
    final selectedLang = (controller.selectedLanguageForSubtitles.value.isNotEmpty
            ? controller.selectedLanguageForSubtitles.value
            : 'en')
        .obs;
    final selectedFile = Rxn<PlatformFile>();

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Upload Custom Subtitles',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Directly upload subtitle files (.vtt, .srt, .txt) from your device for this ad. Please select the target language first.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Target Language',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedLanguages)
                        DropdownMenuItem(
                          value: lang['code'],
                          child: Text(
                            lang['name']!,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedLang.value = val;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Subtitle File (.vtt, .srt, .txt)',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['vtt', 'srt', 'txt'],
                    withData: true,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    selectedFile.value = result.files.first;
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedFile.value != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFF27272A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedFile.value != null
                            ? Icons.check_circle_outline_rounded
                            : Icons.file_upload_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedFile.value != null
                              ? '${selectedFile.value!.name} (${(selectedFile.value!.size / 1024).toStringAsFixed(1)} KB)'
                              : 'Choose file from device...',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: selectedFile.value != null
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedFile.value == null || controller.isUploadingSubtitles.value
                  ? null
                  : () async {
                      Get.back();
                      await controller.uploadDirectSubtitles(
                        langCode: selectedLang.value,
                        file: selectedFile.value!,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF27272A),
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                controller.isUploadingSubtitles.value
                    ? 'Importing...'
                    : 'Import & Save',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
