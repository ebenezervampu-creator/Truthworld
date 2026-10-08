import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Form field label with optional required asterisk.
class EditTopicFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const EditTopicFieldLabel({
    required this.label,
    this.isRequired = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

/// Form input field with styled dark container matching Channel Wizard.
class EditTopicInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int? maxLength;
  final Widget? suffixIcon;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;

  const EditTopicInputField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.maxLength,
    this.suffixIcon,
    this.obscureText = false,
    this.inputFormatters,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        inputFormatters: inputFormatters ?? TruthworldTextInputFormatters.standard,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: suffixIcon,
          counterStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

/// Category selection dropdown for EditTopicDialog.
class EditTopicCategoryDropdown extends StatelessWidget {
  final EditTopicController controller;

  const EditTopicCategoryDropdown({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          value: controller.categoryController.text,
          dropdownColor: AppColors.bgSurface,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
          items: EditTopicController.categories
              .map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              controller.categoryController.text = val;
            }
          },
        ),
      ),
    );
  }
}

/// Visibility selection dropdown and access code configuration.
class EditTopicVisibilityDropdown extends StatelessWidget {
  final EditTopicController controller;

  const EditTopicVisibilityDropdown({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgDivider),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<TopicVisibilityType>(
                isExpanded: true,
                value: controller.selectedVisibility.value,
                dropdownColor: AppColors.bgSurface,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(
                    value: TopicVisibilityType.public,
                    child: Text(
                      'Public (Anyone can contribute)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: TopicVisibilityType.channelOnly,
                    child: Text(
                      'Channel Only (Only you can contribute)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: TopicVisibilityType.private,
                    child: Text(
                      'Private (Passcode required for others)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    controller.selectedVisibility.value = val;
                  }
                },
              ),
            ),
          ),
          if (controller.selectedVisibility.value == TopicVisibilityType.private) ...[
            const SizedBox(height: 16),
            const EditTopicFieldLabel(label: 'Setup Access Code', isRequired: true),
            const SizedBox(height: 8),
            EditTopicInputField(
              controller: controller.accessCodeController,
              hintText: 'Enter access code',
              obscureText: controller.obscureAccessCode.value,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscureAccessCode.value ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  controller.obscureAccessCode.value = !controller.obscureAccessCode.value;
                },
              ),
            ),
          ],
        ],
      );
    });
  }
}
