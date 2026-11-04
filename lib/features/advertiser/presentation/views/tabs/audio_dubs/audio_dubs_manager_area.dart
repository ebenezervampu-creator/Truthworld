import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audio_dubs/audio_dubs_track_item.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audio_dubs/request_audio_dub_dialog.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audio_dubs/upload_audio_track_dialog.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/pipeline_progress_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Main editor area for managing, translating, and uploading audio tracks for a selected ad.
class AudioDubsManagerArea extends StatelessWidget {
  const AudioDubsManagerArea({required this.controller, super.key});
  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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
        color: AppColors.appBarSurface,
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
                          : () => UploadAudioTrackDialog.show(context, controller),
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
                        side: const BorderSide(color: AppColors.bgElevated),
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
                          : () => RequestAudioDubDialog.show(context, controller),
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
            const Divider(color: AppColors.bgSurface, height: 32),
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
                    const AudioDubsTrackItem(
                      langName: 'English (Original)',
                      desc: 'Integrated source stream',
                      status: 'active',
                      isOriginal: true,
                    ),
                    for (final entry in tracks.entries)
                      AudioDubsTrackItem(
                        langName: controller.getLanguageName(entry.key),
                        desc: entry.value,
                        status: 'active',
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
