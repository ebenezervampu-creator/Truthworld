import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesHeaderBar extends StatelessWidget {
  const SubtitlesHeaderBar({
    this.onBack,
    super.key,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    const primaryText = AppColors.textPrimary;
    const secondaryText = AppColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: primaryText,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().sideNavSelectedIndex.value =
                  HomeController.indexLibrary;
            } else {
              Get.back();
            }
          },
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subtitles & Transcripts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Add and manage subtitles and transcripts for your video. You can create subtitles manually, auto-generate with AI, or upload a file.',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
