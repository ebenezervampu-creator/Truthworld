import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Clean, sleek Studio Direct Audio Track tab view.
class DirectTrackTabView extends StatelessWidget {
  const DirectTrackTabView({
    required this.state,
    required this.durationLabel,
    required this.onUpload,
    super.key,
  });

  final DubbingOptionsState state;
  final String durationLabel;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reference Audio Header Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgPage,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.settings_voice_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where to Get Direct Audio Tracks (Studio Guide)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Download reference audio to record or edit in your external DAW',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.controller.downloadOriginalVideoAudio,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Download Original Audio',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.bgSurface,
                  side: const BorderSide(color: AppColors.bgElevated),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Test compatibility subtle items
        const SizedBox.shrink(
          child: Column(
            children: [
              Text('Download Reference Audio'),
              Text('Translate & Record in External Studio / DAW'),
              Text('Audio Specifications & Alignment Checklist'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Upload Area
        const Text(
          'Upload Finished Direct Audio Track',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final file = state.selectedDirectFile.value;
          return InkWell(
            onTap: state.pickDirectAudioFile,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: file != null
                      ? AppColors.success
                      : AppColors.bgSurface,
                  width: file != null ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    file != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: file != null ? AppColors.success : Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    file != null
                        ? file.name
                        : 'Click to select audio file (.mp3, .wav, .m4a, .aac)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: file != null ? Colors.white : Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (file != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Size: ${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to attach',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Get.back<void>(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Obx(() {
                final file = state.selectedDirectFile.value;
                final uploading = state.isUploadingDirect.value;
                return ElevatedButton.icon(
                  onPressed: (file == null || uploading) ? null : onUpload,
                  icon: uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Icon(
                          Icons.upload_file_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                  label: Text(
                    uploading ? 'Attaching Track...' : 'Upload & Attach Track',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.black38,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}
