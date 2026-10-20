import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/edit_video_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/controllers/edit_video_controller.dart';

class EditVideoScreen extends StatelessWidget {
  const EditVideoScreen({required this.video, super.key});
  final Video video;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditVideoController>(
      init: EditVideoController(video: video),
      tag: video.id,
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.bgPage,
          appBar: AppBar(
            title: Text(
              'Edit Video',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: TWTypography.brandFamily,
              ),
            ),
            backgroundColor: AppColors.bgPage,
            elevation: 0,
            shape: const Border(
              bottom: BorderSide(color: AppColors.bgDivider),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Get.back<void>(),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: controller.save,
                  icon: const Icon(Icons.save, size: 18, color: Colors.black),
                  label: Text('Save', style: AppTextStyles.buttonText.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Thumbnail & Context Header with Hero flight
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'video-thumb-${video.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 110,
                              height: 62,
                              child: video.thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: video.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => const ColoredBox(
                                        color: AppColors.bgInput,
                                        child: Icon(
                                          Icons.movie_outlined,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    )
                                  : const ColoredBox(
                                      color: AppColors.bgInput,
                                      child: Icon(
                                        Icons.movie_outlined,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Duration: ${video.duration} • ${video.views} views • Visibility: ${video.visibility.capitalizeFirst}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTextField(
                    controller: controller.titleController,
                    label: 'Title',
                    maxLength: 100,
                    validator: ContentValidator.formValidator('Title', maxLength: 100),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: controller.descriptionController,
                    label: 'Description',
                    maxLines: 5,
                    maxLength: 5000,
                    validator: ContentValidator.formValidator('Description', required: false, maxLength: 5000),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: controller.tagsController,
                    label: 'Tags (comma separated, max 5)',
                    maxLength: 200,
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        if (val.length > 200) {
                          return 'Tags cannot exceed 200 characters';
                        }
                        final tagList = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        if (tagList.length > 5) {
                          return 'Maximum 5 tags allowed';
                        }
                        for (final tag in tagList) {
                          final res = ContentValidator.validate(tag, maxLength: 50, fieldName: 'Tag');
                          if (!res.isValid) return res.message;
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(controller),
                  const SizedBox(height: 20),
                  _buildSwitchField(controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: maxLength != null
          ? (context, {required currentLength, required isFocused, maxLength}) => null
          : null,
      inputFormatters: maxLength != null
          ? TruthworldTextInputFormatters.withLimit(maxLength)
          : [...TruthworldTextInputFormatters.standard],
      validator: validator,
      style: AppTextStyles.inputText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.inputHint,
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdownField(EditVideoController controller) {
    final options = [
      {'value': 'public', 'label': 'Public (Everyone can watch)'},
      {'value': 'private', 'label': 'Private (Only you can watch)'},
      {'value': 'members_only', 'label': 'Members Only (Channel members)'},
      {'value': 'subscribers_only', 'label': 'Subscribers Only (Subscribers)'},
      {'value': 'unlisted', 'label': 'Unlisted (Anyone with link)'},
    ];

    return Obx(
      () {
        var current = controller.selectedVisibility.value.toLowerCase().replaceAll(' ', '_');
        if (current == 'members') current = 'members_only';
        if (current == 'subscribers') current = 'subscribers_only';
        if (!options.any((o) => o['value'] == current)) {
          current = 'public';
        }

        return DropdownButtonFormField<String>(
          initialValue: current,
          onChanged: (value) {
            if (value != null) {
              controller.selectedVisibility.value = value;
            }
          },
          items: options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt['value'],
                  child: Text(
                    opt['label']!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            labelText: 'Visibility & Access',
            labelStyle: AppTextStyles.inputHint,
            filled: true,
            fillColor: AppColors.bgInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
          ),
          dropdownColor: AppColors.bgSurface,
          style: AppTextStyles.inputText,
        );
      },
    );
  }

  Widget _buildSwitchField(EditVideoController controller) {
    return Column(
      children: [
        Obx(
          () => SwitchListTile(
            title: Text(
              'Is this video "Made for Kids"?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: controller.isKidFriendly.value,
            onChanged: (value) {
              controller.isKidFriendly.value = value;
            },
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.bgDivider),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Show Like Count',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Show how many viewers like this video',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            value: controller.showLikeCount.value,
            onChanged: (value) {
              controller.showLikeCount.value = value;
            },
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.bgDivider),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Show Dislike Count',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Show how many viewers dislike this video',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            value: controller.showDislikeCount.value,
            onChanged: (value) {
              controller.showDislikeCount.value = value;
            },
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.bgDivider),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Allow automatic chapters',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'When eligible and available. Adding description timestamps (e.g. 0:00 Intro, 0:10 Topic) will override automatic chapters.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            value: controller.autoChaptersEnabled.value,
            onChanged: (value) {
              controller.autoChaptersEnabled.value = value;
            },
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.bgDivider),
            ),
          ),
        ),
      ],
    );
  }
}
