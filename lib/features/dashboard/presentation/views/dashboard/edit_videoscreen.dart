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
              style: AppTextStyles.titleLarge,
            ),
            backgroundColor: AppColors.bgSurface,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: controller.save,
                  icon: const Icon(Icons.save, size: 18, color: Colors.black),
                  label: Text('Save', style: AppTextStyles.buttonText.copyWith(color: Colors.black)),
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
                  _buildTextField(
                    controller: controller.titleController,
                    label: 'Title',
                    validator: ContentValidator.formValidator('Title'),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: controller.descriptionController,
                    label: 'Description',
                    maxLines: 5,
                    validator: ContentValidator.formValidator('Description', required: false),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: controller.tagsController,
                    label: 'Tags (comma separated, max 5)',
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final tagList = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        if (tagList.length > 5) {
                          return 'Maximum 5 tags allowed';
                        }
                        for (final tag in tagList) {
                          final res = ContentValidator.validate(tag, fieldName: 'Tag');
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: [...TruthworldTextInputFormatters.standard],
      validator: validator,
      style: AppTextStyles.inputText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.inputHint,
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
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
                  child: Text(opt['label']!, style: AppTextStyles.bodyMedium),
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
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 2),
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
              style: AppTextStyles.bodyMedium,
            ),
            value: controller.isKidFriendly.value,
            onChanged: (value) {
              controller.isKidFriendly.value = value;
            },
            activeThumbColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Show Like Count',
              style: AppTextStyles.bodyMedium,
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
            activeThumbColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Show Dislike Count',
              style: AppTextStyles.bodyMedium,
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
            activeThumbColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
