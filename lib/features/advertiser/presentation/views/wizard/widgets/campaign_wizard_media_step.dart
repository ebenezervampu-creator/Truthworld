import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_input_field.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_device_picker.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_media_slot.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_pickers.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Step 2: Creatives & Media configuration.
class CampaignWizardMediaStep extends StatelessWidget {
  final BuildContext context;
  final AdvertiserPortalController controller;
  final RxString adFormat;
  final TextEditingController advertiserController;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController ctaTextController;
  final TextEditingController ctaUrlController;
  final TextEditingController videoUrlController;
  final TextEditingController midrollVideoUrlController;
  final TextEditingController imageUrlController;
  final TextEditingController pinnedCommentController;
  final RxString selectedVideoTitle;
  final RxString selectedVideoId;
  final RxString pickedBumperFileName;
  final RxString pickedBumperMeta;
  final RxBool isBumperUploading;
  final RxDouble bumperUploadProgress;
  final RxString bumperUploadStatus;
  final RxString pickedMidrollFileName;
  final RxString pickedMidrollMeta;
  final RxBool isMidrollUploading;
  final RxDouble midrollUploadProgress;
  final RxString midrollUploadStatus;
  final RxString pickedBannerFileName;
  final RxString pickedBannerMeta;
  final RxBool isBannerUploading;
  final RxDouble bannerUploadProgress;
  final RxString bannerUploadStatus;

  const CampaignWizardMediaStep({
    required this.context,
    required this.controller,
    required this.adFormat,
    required this.advertiserController,
    required this.titleController,
    required this.descriptionController,
    required this.ctaTextController,
    required this.ctaUrlController,
    required this.videoUrlController,
    required this.midrollVideoUrlController,
    required this.imageUrlController,
    required this.pinnedCommentController,
    required this.selectedVideoTitle,
    required this.selectedVideoId,
    required this.pickedBumperFileName,
    required this.pickedBumperMeta,
    required this.isBumperUploading,
    required this.bumperUploadProgress,
    required this.bumperUploadStatus,
    required this.pickedMidrollFileName,
    required this.pickedMidrollMeta,
    required this.isMidrollUploading,
    required this.midrollUploadProgress,
    required this.midrollUploadStatus,
    required this.pickedBannerFileName,
    required this.pickedBannerMeta,
    required this.isBannerUploading,
    required this.bannerUploadProgress,
    required this.bannerUploadStatus,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSkippable = adFormat.value == 'skippable';
      final isSponsor = adFormat.value == 'video_sponsor';
      final isScroll = adFormat.value == 'scroll';
      final isHomepage = adFormat.value == 'homepage';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaign Details & Media Creatives',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          AdvertiserInputField(
            label: 'Brand / Advertiser Name',
            controller: advertiserController,
            hint: 'e.g. Acme Brand Corp',
          ),
          const SizedBox(height: 16),
          AdvertiserInputField(
            label: 'Campaign Headline Title',
            controller: titleController,
            hint: 'e.g. Master App Development in 30 Days',
          ),
          const SizedBox(height: 16),
          AdvertiserInputField(
            label: 'Description Subtext',
            controller: descriptionController,
            hint: 'e.g. Learn flutter, dart, firebase, and responsive UI from industry experts.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AdvertiserInputField(
                  label: 'CTA Button Text',
                  controller: ctaTextController,
                  hint: 'e.g. Learn More',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdvertiserInputField(
                  label: 'Destination Link Target',
                  controller: ctaUrlController,
                  hint: 'e.g. https://mywebsite.com',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Media Creative Attachments',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              if (isSponsor)
                TextButton.icon(
                  onPressed: () {
                    if (advertiserController.text.trim().isEmpty) {
                      advertiserController.text = 'Acme Brand Corp';
                    }
                    if (titleController.text.trim().isEmpty) {
                      titleController.text = 'Special Summer Tech Festival Deal';
                    }
                    if (descriptionController.text.trim().isEmpty) {
                      descriptionController.text =
                          'Get up to 50% off on flagship products and course passes!';
                    }
                    videoUrlController.text =
                        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
                    midrollVideoUrlController.text =
                        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
                    imageUrlController.text =
                        'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500';
                    pinnedCommentController.text =
                        'Welcome viewers! We are Acme Brand Corp. Feel free to reply here to ask us anything or check out our exclusive offer!';
                    pickedBumperFileName.value = 'Demo Bumper (Butterfly HD)';
                    pickedBumperMeta.value = '1.2 MB • 0:05';
                    pickedMidrollFileName.value = 'Demo Midroll (Bee HD)';
                    pickedMidrollMeta.value = '4.5 MB • 0:10';
                    pickedBannerFileName.value = 'Demo Banner (Tech)';
                    pickedBannerMeta.value = '150 KB • 1200x628';
                    AppSnackbar.show(
                      '4-in-1 Sponsor Requirements',
                      'Loaded all 4 creative requirements for demo setup.',
                    );
                  },
                  icon: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.black,
                    size: 16,
                  ),
                  label: const Text(
                    'Auto-Fill Requirements (Demo)',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Media Slot 1: Bumper or Skippable / Video Creative
          buildCampaignMediaUploadSlot(
            title: isSponsor
                ? '1. 5-Sec Pre-Roll Sponsor Bumper'
                : isSkippable
                ? '1. Skippable Video Creative'
                : isHomepage
                ? '1. Video Creative (Optional - Max 5 Mins)'
                : '1. Video Creative (Optional)',
            subtitle: isSponsor
                ? 'Short 5-sec video or audio bumper. (Max 500MB, <= 6s duration)'
                : isSkippable
                ? 'Main video ad creative. (MP4, MOV, WEBM, max 500MB, <= 5 mins duration)'
                : isHomepage
                ? 'Optional video creative for Homepage Ad cards (MP4, MOV, WEBM, max 500MB, <= 5 mins duration).'
                : 'Optional video creative (MP4, MOV, WEBM, max 500MB, <= 5 mins duration).',
            urlController: videoUrlController,
            fileNameNotifier: pickedBumperFileName,
            metaNotifier: pickedBumperMeta,
            isUploadingNotifier: isBumperUploading,
            uploadProgressNotifier: bumperUploadProgress,
            uploadStatusNotifier: bumperUploadStatus,
            mediaIcon: isSponsor ? Icons.audiotrack_rounded : Icons.movie_rounded,
            isRequired: isSponsor || isSkippable,
            onPickDevice: () => pickCampaignDeviceMediaFile(
              context: context,
              fileType: isSponsor ? FileType.custom : FileType.video,
              targetController: videoUrlController,
              pickedFileNameNotifier: pickedBumperFileName,
              isUploadingNotifier: isBumperUploading,
              uploadProgressNotifier: bumperUploadProgress,
              uploadStatusNotifier: bumperUploadStatus,
              pickedMetaNotifier: pickedBumperMeta,
              allowedExtensions: isSponsor
                  ? const ['mp4', 'mov', 'webm', 'mkv', 'avi', 'mp3', 'wav', 'm4a', 'aac', 'ogg']
                  : const ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v', '3gp'],
              maxDurationSeconds: isSponsor ? 6.0 : 300.0,
              durationLimitWarningText: isSponsor
                  ? 'Sponsor bumper media must be 5 seconds or less in duration.'
                  : 'Video ad creative must be 5 minutes (300 seconds) or less.',
            ),
            onPickPreset: () {
              showCampaignVideosPicker(
                context,
                controller,
                onSelected: (video) {
                  videoUrlController.text = video['videoUrl'] ?? '';
                  pickedBumperFileName.value = video['title'] ?? '';
                  pickedBumperMeta.value = 'Channel Preset';
                  selectedVideoTitle.value = video['title'] ?? '';
                  selectedVideoId.value = video['id'] ?? '';
                },
              );
            },
          ),

          // Media Slot 2: Mid-roll Video (for Video Sponsor Ads)
          if (isSponsor) ...[
            buildCampaignMediaUploadSlot(
              title: '2. 7-Minute Skippable Mid-roll Video',
              subtitle: 'Full mid-roll video ad. (MP4, MOV, WEBM, max 500MB, <= 7.5 mins duration)',
              urlController: midrollVideoUrlController,
              fileNameNotifier: pickedMidrollFileName,
              metaNotifier: pickedMidrollMeta,
              isUploadingNotifier: isMidrollUploading,
              uploadProgressNotifier: midrollUploadProgress,
              uploadStatusNotifier: midrollUploadStatus,
              mediaIcon: Icons.video_collection_rounded,
              isRequired: true,
              onPickDevice: () => pickCampaignDeviceMediaFile(
                context: context,
                fileType: FileType.video,
                targetController: midrollVideoUrlController,
                pickedFileNameNotifier: pickedMidrollFileName,
                isUploadingNotifier: isMidrollUploading,
                uploadProgressNotifier: midrollUploadProgress,
                uploadStatusNotifier: midrollUploadStatus,
                pickedMetaNotifier: pickedMidrollMeta,
                allowedExtensions: const ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'],
                maxDurationSeconds: 450.0,
                durationLimitWarningText:
                    'Mid-roll video ads must be 7.5 minutes (450 seconds) or less.',
              ),
              onPickPreset: () {
                showCampaignVideosPicker(
                  context,
                  controller,
                  onSelected: (video) {
                    midrollVideoUrlController.text = video['videoUrl'] ?? '';
                    pickedMidrollFileName.value = video['title'] ?? '';
                    pickedMidrollMeta.value = 'Channel Preset';
                  },
                );
              },
            ),
          ],

          // Media Slot 3: Banner Image
          if (!isSkippable || isSponsor) ...[
            buildCampaignMediaUploadSlot(
              title: isSponsor
                  ? '3. Sponsor Brand Banner Image'
                  : isScroll
                  ? '2. Image Banner Creative'
                  : isHomepage
                  ? '2. Image Banner Creative'
                  : '2. Image Banner Creative (Optional)',
              subtitle: isSponsor
                  ? 'Brand banner displayed in recommended videos feed (JPG, PNG, WEBP, max 15MB).'
                  : isScroll
                  ? 'Image creative required for Scroll Feed ad placements (JPG, PNG, WEBP, max 15MB).'
                  : isHomepage
                  ? 'Image creative required for Homepage ad cards (JPG, PNG, WEBP, max 15MB).'
                  : 'Banner image creative (JPG, PNG, WEBP, max 15MB).',
              urlController: imageUrlController,
              fileNameNotifier: pickedBannerFileName,
              metaNotifier: pickedBannerMeta,
              isUploadingNotifier: isBannerUploading,
              uploadProgressNotifier: bannerUploadProgress,
              uploadStatusNotifier: bannerUploadStatus,
              mediaIcon: Icons.image_rounded,
              isRequired: isSponsor || isScroll || isHomepage,
              onPickDevice: () => pickCampaignDeviceMediaFile(
                context: context,
                fileType: FileType.image,
                targetController: imageUrlController,
                pickedFileNameNotifier: pickedBannerFileName,
                isUploadingNotifier: isBannerUploading,
                uploadProgressNotifier: bannerUploadProgress,
                uploadStatusNotifier: bannerUploadStatus,
                pickedMetaNotifier: pickedBannerMeta,
                allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
              ),
              onPickPreset: () {
                showCampaignImagePicker(
                  context,
                  onSelectedUrl: (url) {
                    imageUrlController.text = url;
                    pickedBannerFileName.value = 'Preset Banner Sample';
                    pickedBannerMeta.value = 'Sample Preset';
                  },
                );
              },
            ),
          ],

          // Sponsor Interactive Pinned Comment
          if (isSponsor) ...[
            const Text(
              '4. Sponsor Interactive Pinned Comment Text (Viewers interact below video) [Required]',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            AdvertiserInputField(
              label: '',
              controller: pinnedCommentController,
              hint: 'e.g. Welcome viewers! Ask us anything or check out our exclusive discount here.',
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    });
  }
}
