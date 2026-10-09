import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheets and quality dialogs for video playback speed, quality,
/// loop toggles, and offline download settings.
class VideoPlayerSettingsSheet {
  static void showSettings({
    required BuildContext context,
    required VideoController controller,
  }) {
    Get.bottomSheet(
      Material(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Player Settings',
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _settingsTile(
                Icons.speed_rounded,
                'Playback Speed',
                '${controller.videoPlayerController?.value.playbackSpeed ?? 1.0}x',
                () {},
              ),
              _settingsTile(Icons.high_quality_rounded, 'Quality', 'Auto', () {}),
              _settingsTile(
                Icons.loop_rounded,
                'Loop Video',
                (controller.videoPlayerController?.value.isLooping ?? false)
                    ? 'On'
                    : 'Off',
                () {},
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  static Widget _settingsTile(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w500),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  static void showDownloadQualityDialog({
    required BuildContext context,
    required VideoController controller,
    required bool isUserSignedIn,
    required VoidCallback onSignInPrompt,
  }) {
    if (!isUserSignedIn) return onSignInPrompt();

    final downloadsCtrl = Get.isRegistered<DownloadsController>()
        ? Get.find<DownloadsController>()
        : Get.put(DownloadsController());

    downloadsCtrl.showDownloadQualityDialog(
      context,
      controller.video,
      onResolutionSelected: (res) => controller.saveVideoOffline(res),
      onAudioSelected: () => controller.saveAudioOffline(),
    );
  }


}
