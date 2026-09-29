import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for requesting automated AI voiceover dubbing for an ad.
class RequestAudioDubDialog extends StatelessWidget {
  const RequestAudioDubDialog({required this.controller, super.key});
  final AdvertiserPortalController controller;

  static void show(BuildContext context, AdvertiserPortalController controller) {
    Get.dialog(RequestAudioDubDialog(controller: controller));
  }

  @override
  Widget build(BuildContext context) {
    final selectedLang = 'hi'.obs;
    final selectedVoice = 'natural'.obs;

    return Obx(
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
    );
  }
}
