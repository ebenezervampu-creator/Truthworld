import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/presentation/views/upload/community_image_picker_dropzone.dart';
import 'package:truthworld/features/community/presentation/views/upload/community_upload_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Content inputs section for community post creation (Image, Title, and Description).
class CommunityPostContentInputs
    extends GetView<CommunityPostUploadController> {
  const CommunityPostContentInputs({super.key});

  @override
  Widget build(BuildContext context) {
    return CommunityUploadSectionCard(
      title: '1. Post Content',
      children: [
        // Image Label
        RichText(
          text: TextSpan(
            text: 'Post Image ',
            style: context.twTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add an image to make your post more engaging.',
          style: context.twTypography.caption.copyWith(
            fontSize: 12,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Dropzone / Image Picker Box
        const CommunityImagePickerDropzone(),

        const SizedBox(height: 20),

        // Title Input
        RichText(
          text: TextSpan(
            text: 'Title ',
            style: context.twTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller.titleCtrl,
          builder: (context, value, _) {
            return TextFormField(
              controller: controller.titleCtrl,
              maxLength: 100,
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
              style: context.twTypography.body.copyWith(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) {
                  return 'Enter Title';
                }
                if (val.length < 5) {
                  return 'Title is too short (min 5 characters)';
                }
                final res = ContentValidator.validate(val, fieldName: 'Title');
                return res.isValid ? null : res.message;
              },
              decoration: InputDecoration(
                hintText: 'Enter a title for your post',
                hintStyle: context.twTypography.body.copyWith(
                  color: context.colors.textTertiary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF121212),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.error, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.error, width: 1.5),
                ),
                errorStyle: context.twTypography.caption.copyWith(
                  color: context.colors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: UnconstrainedBox(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${value.text.length}/100',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Description Input
        RichText(
          text: TextSpan(
            text: 'Description ',
            style: context.twTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller.descCtrl,
          builder: (context, value, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller.descCtrl,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: 2000,
                  inputFormatters: [TruthworldTextInputFormatters.englishOnly],
                  onChanged: (val) => controller.descriptionText.value = val,
                  style: context.twTypography.body.copyWith(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                  ),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) {
                      return 'Enter Description';
                    }
                    if (val.length < 10) {
                      return 'Description is too short (min 10 characters)';
                    }
                    final res = ContentValidator.validate(val, fieldName: 'Description');
                    return res.isValid ? null : res.message;
                  },
                  decoration: InputDecoration(
                    hintText: 'Write your post description...',
                    hintStyle: context.twTypography.body.copyWith(
                      color: context.colors.textTertiary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.colors.error, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.colors.error, width: 1.5),
                    ),
                    errorStyle: context.twTypography.caption.copyWith(
                      color: context.colors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${value.text.length}/2000',
                    style: context.twTypography.caption.copyWith(
                      fontSize: 12,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
