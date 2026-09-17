import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/pipeline_progress_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdvertiserAudioDubsTab extends StatelessWidget {
  const AdvertiserAudioDubsTab({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return _buildAudioDubsTab(context, controller);
  }

  Widget _buildAudioDubsTab(
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
          final listWidget = _buildAudioDubsCampaignsSidebar(
            controller,
            skippableCampaigns,
          );
          final managerWidget = _buildAudioDubsManagerArea(controller);

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: listWidget),
                const VerticalDivider(color: Color(0xFF27272A), width: 1),
                Expanded(child: managerWidget),
              ],
            );
          } else {
            return controller.selectedAdForAudio.value == null
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
                                controller.selectedAdForAudio.value = null;
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
                      Expanded(child: managerWidget),
                    ],
                  );
          }
        },
      );
    });
  }

  Widget _buildAudioDubsCampaignsSidebar(
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
                    'Select Video Ad to Dub',
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
                        'No video campaigns available. Audio dubs can only be requested on Skippable Video ads.',
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
                          controller.selectedAdForAudio.value?.id == ad.id;
                      final dubCount = (ad.audioTracks ?? {}).length + 1;

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
                            controller.selectedAdForAudio.value = ad;
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
                                Icons.music_note_rounded,
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
                            '$dubCount Audio track${dubCount == 1 ? "" : "s"} available',
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

  Widget _buildAudioDubsManagerArea(AdvertiserPortalController controller) {
    if (controller.selectedAdForAudio.value == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Select a video campaign from the list to manage audio voiceovers.',
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

    final ad = controller.selectedAdForAudio.value!;
    final tracks = ad.audioTracks ?? {};

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
                      'AI voice cloning and audio dubbing configuration board',
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
                    onPressed: (controller.isTranslatingAudio.value ||
                            controller.isUploadingAudioTrack.value)
                        ? null
                        : () => _showUploadAudioTrackDialog(controller),
                    icon: controller.isUploadingAudioTrack.value
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
                      'Upload Audio Track',
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
                    onPressed: (controller.isTranslatingAudio.value ||
                            controller.isUploadingAudioTrack.value)
                        ? null
                        : () => _showRequestAudioDubDialog(controller),
                    icon: const Icon(Icons.translate_rounded, color: Colors.black, size: 16),
                    label: const Text(
                      'Request Voice Dub',
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
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 32),
          if (controller.isTranslatingAudio.value)
            PipelineProgressCard(
              status: controller.audioStatusText.value,
              progress: controller.audioProgress.value,
            )
          else if (controller.isUploadingAudioTrack.value)
            PipelineProgressCard(
              status: 'Uploading direct audio track from device...',
              progress: controller.audioUploadProgress.value,
            )
          else ...[
            const Text(
              'Configured Voiceover Layers',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildAudioTrackItem(
                    controller,
                    'English (Original)',
                    'Integrated source stream',
                    'active',
                    isOriginal: true,
                  ),
                  for (final entry in tracks.entries)
                    _buildAudioTrackItem(
                      controller,
                      controller.getLanguageName(entry.key),
                      entry.value,
                      'active',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioTrackItem(
    AdvertiserPortalController controller,
    String langName,
    String desc,
    String status, {
    bool isOriginal = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF27272A),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF27272A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langName,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
            ),
            child: Text(
              isOriginal ? 'ORIGINAL' : 'AI CLONED',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestAudioDubDialog(AdvertiserPortalController controller) {
    final selectedLang = 'hi'.obs;
    final selectedVoice = 'natural'.obs;

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Request AI Voice Dubbing',
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
                'Select target dub language and AI voice clone parameters.',
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
                      for (final lang in controller.supportedAudioLanguages)
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
              const SizedBox(height: 16),
              const Text(
                'Voice Style',
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
                    value: selectedVoice.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'natural',
                        child: Text(
                          'Natural Tone Voice Clone',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'studio_male',
                        child: Text(
                          'Studio Narration (Male)',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'studio_female',
                        child: Text(
                          'Studio Narration (Female)',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedVoice.value = val;
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
                controller.requestAdAudioDub(
                  selectedLang.value,
                  voiceStyle: selectedVoice.value,
                );
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
                'Start Dubbing Process',
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

  void _showUploadAudioTrackDialog(AdvertiserPortalController controller) {
    final selectedLang = 'hi'.obs;
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
            'Upload Custom Audio Track',
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
                'Upload custom recorded audio (.mp3, .wav, .m4a, .aac) from your device for this ad. Please select the language first.',
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
                      for (final lang in controller.supportedAudioLanguages)
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
              const SizedBox(height: 16),
              const Text(
                'Audio File (.mp3, .wav, .m4a, .aac)',
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
                    allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
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
                              ? '${selectedFile.value!.name} (${(selectedFile.value!.size / (1024 * 1024)).toStringAsFixed(2)} MB)'
                              : 'Choose audio file from device...',
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
              onPressed: selectedFile.value == null || controller.isUploadingAudioTrack.value
                  ? null
                  : () async {
                      Get.back();
                      await controller.uploadDirectAudioTrack(
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
                controller.isUploadingAudioTrack.value
                    ? 'Uploading...'
                    : 'Upload & Save',
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
