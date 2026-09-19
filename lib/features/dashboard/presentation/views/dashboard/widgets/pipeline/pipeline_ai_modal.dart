import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Full-width trigger button to open the On-Demand AI Features modal.
class PipelineGenerateAIButton extends StatelessWidget {
  const PipelineGenerateAIButton({
    required this.video,
    super.key,
  });

  final Video video;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 18,
          color: Colors.white,
        ),
        label: Text(
          'Generate / Add AI Features (Telugu, Hindi, Dubbing, Factcheck...)',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.brand,
          ),
        ),
        onPressed: () {
          showGenerateAIFeaturesQuickModal(context, video, controller);
        },
      ),
    );
  }
}

/// Displays quick configuration dialog to trigger AI pipeline operations.
void showGenerateAIFeaturesQuickModal(
  BuildContext context,
  Video video,
  VideoManagementController controller,
) {
  final selectedLangs = <String>{'te', 'hi'}.obs;
  final selectedFeatures = <String>{
    'subtitles',
    'dubbing',
    'factcheck',
    'summary',
    'chapters',
  }.obs;
  final isAccuracyMode = true.obs;

  final availableLangs = [
    {'code': 'te', 'name': 'Telugu (తెలుగు)'},
    {'code': 'hi', 'name': 'Hindi (हिन्दी)'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
    {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
    {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
    {'code': 'es', 'name': 'Spanish'},
  ];

  Get.dialog<void>(
    Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'On-Demand AI Features',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: Get.back<void>,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target Languages',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableLangs.map((lang) {
                      final code = lang['code']!;
                      final name = lang['name']!;
                      final isSelected = selectedLangs.contains(code);
                      return FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        selectedColor: AppColors.brand.withValues(alpha: 0.2),
                        checkmarkColor: Colors.white,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.brand
                              : AppColors.textPrimary,
                        ),
                        onSelected: (val) {
                          if (val) {
                            selectedLangs.add(code);
                          } else if (selectedLangs.length > 1) {
                            selectedLangs.remove(code);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI Features',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: selectedFeatures.contains('subtitles'),
                    activeColor: AppColors.brand,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Subtitles (SRT/VTT)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Generate captions in target languages',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (val) => (val ?? false)
                        ? selectedFeatures.add('subtitles')
                        : selectedFeatures.remove('subtitles'),
                  ),
                  CheckboxListTile(
                    value: selectedFeatures.contains('dubbing'),
                    activeColor: AppColors.brand,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Audio Dubbing Tracks',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Generate voice audio in Telugu, Hindi, etc.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (val) => (val ?? false)
                        ? selectedFeatures.add('dubbing')
                        : selectedFeatures.remove('dubbing'),
                  ),
                  CheckboxListTile(
                    value: selectedFeatures.contains('factcheck'),
                    activeColor: AppColors.brand,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fact-Checking Report',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Extract claims and truth score',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (val) => (val ?? false)
                        ? selectedFeatures.add('factcheck')
                        : selectedFeatures.remove('factcheck'),
                  ),
                  CheckboxListTile(
                    value: selectedFeatures.contains('summary'),
                    activeColor: AppColors.brand,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'AI Video Summary',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Generate smart video summary',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (val) => (val ?? false)
                        ? selectedFeatures.add('summary')
                        : selectedFeatures.remove('summary'),
                  ),
                  CheckboxListTile(
                    value: selectedFeatures.contains('chapters'),
                    activeColor: AppColors.brand,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Auto-Chapters',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Generate timestamped section breaks',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (val) => (val ?? false)
                        ? selectedFeatures.add('chapters')
                        : selectedFeatures.remove('chapters'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: Get.back<void>,
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.buttonText.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                        label: Text(
                          'Generate AI Features',
                          style: AppTextStyles.buttonText.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: selectedFeatures.isEmpty
                            ? null
                            : () {
                                Get.back<void>();
                                controller.triggerAIFeatures(
                                  videoId: video.id,
                                  features: selectedFeatures.toList(),
                                  targetLanguages: selectedLangs.toList(),
                                  priorityMode: isAccuracyMode.value
                                      ? 'accuracy'
                                      : 'speed',
                                  autoChapters: selectedFeatures.contains(
                                    'chapters',
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
