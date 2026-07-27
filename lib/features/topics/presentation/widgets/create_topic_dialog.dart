import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modern, responsive, overflow-free Create Topic Dialog modal.
class CreateTopicDialog extends StatelessWidget {
  const CreateTopicDialog({
    required this.isDarkMode,
    required this.channelVideosFuture,
    required this.onCreateTopicSubmitted,
    super.key,
  });

  final bool isDarkMode;
  final Future<List<Map<String, dynamic>>> channelVideosFuture;
  final Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted;

  /// Helper launcher method for showing the dialog anywhere in the app.
  static Future<void> show({
    required BuildContext context,
    required bool isDarkMode,
    required Future<List<Map<String, dynamic>>> channelVideosFuture,
    required Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted,
  }) async {
    final controller = Get.put(CreateTopicController());
    controller.resetForm();

    await showDialog<void>(
      context: context,
      builder: (ctx) => CreateTopicDialog(
        isDarkMode: isDarkMode,
        channelVideosFuture: channelVideosFuture,
        onCreateTopicSubmitted: onCreateTopicSubmitted,
      ),
    );
  }

  static const List<String> availableCategories = [
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Gaming',
    'Technology',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion & Beauty',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CreateTopicController>();
    final mediaQuery = MediaQuery.of(context);
    final dialogBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final textColor = isDarkMode ? AppTheme.colors.textPrimary : AppTheme.colors.background;
    final subtextColor = isDarkMode ? AppTheme.colors.textPrimary70 : AppTheme.colors.background54;
    final borderSideColor = isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB);
    final inputBgColor = isDarkMode ? AppColors.bgInput : const Color(0xFFF9FAFB);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderSideColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderSideColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.topic_rounded,
                      color: Color(0xFF6366F1),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Topic',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Build a focused discussion around key events',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtextColor, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profanity / Validation Error Alert Banner
                      Obx(() {
                        if (controller.profanityError.value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.gavel_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  controller.profanityError.value,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Topic Title Input
                      TextFormField(
                        controller: controller.titleController,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Topic Title *',
                          labelStyle: TextStyle(color: subtextColor, fontSize: 13),
                          hintText: 'e.g. Artificial Intelligence Ethics 2026',
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Topic Title is required';
                          if (val.trim().length < 3) return 'Title must be at least 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Topic Handle Input
                      TextFormField(
                        controller: controller.handleController,
                        onChanged: (_) => controller.onHandleManualEdit(),
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Topic Handle *',
                          labelStyle: TextStyle(color: subtextColor, fontSize: 13),
                          prefixText: 'T/ ',
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                          hintText: 'e.g. ai_ethics',
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Handle is required';
                          if (val.contains(' ')) return 'Handle cannot contain spaces';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description Input
                      TextFormField(
                        controller: controller.descriptionController,
                        maxLines: 3,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(color: subtextColor, fontSize: 13),
                          hintText: 'Provide context for this topic...',
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      Text(
                        'Category',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: controller.categoryController.text.isNotEmpty
                            ? controller.categoryController.text
                            : 'Technology',
                        dropdownColor: isDarkMode ? const Color(0xFF1C2128) : Colors.white,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputBgColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderSideColor),
                          ),
                        ),
                        items: availableCategories
                            .map(
                              (cat) => DropdownMenuItem<String>(
                                value: cat,
                                child: Text(
                                  cat,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) controller.categoryController.text = val;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Visibility Dropdown
                      Text(
                        'Visibility Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Obx(
                        () => DropdownButtonFormField<TopicVisibilityType>(
                          isExpanded: true,
                          initialValue: controller.selectedVisibility.value,
                          dropdownColor: isDarkMode ? const Color(0xFF1C2128) : Colors.white,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBgColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderSideColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderSideColor),
                            ),
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
                            if (val != null) controller.selectedVisibility.value = val;
                          },
                        ),
                      ),

                      // Private Passcode Field
                      Obx(() {
                        if (controller.selectedVisibility.value != TopicVisibilityType.private) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextFormField(
                            controller: controller.accessCodeController,
                            obscureText: controller.obscureAccessCode.value,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Private Passcode *',
                              labelStyle: TextStyle(color: subtextColor, fontSize: 13),
                              filled: true,
                              fillColor: inputBgColor,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  controller.obscureAccessCode.value
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: subtextColor,
                                  size: 20,
                                ),
                                onPressed: controller.togglePasscodeVisibility,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderSideColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderSideColor),
                              ),
                            ),
                            validator: (val) {
                              if (controller.selectedVisibility.value == TopicVisibilityType.private) {
                                if (val == null || val.trim().isEmpty) return 'Passcode is required for private topic';
                                if (val.trim().length < 4) return 'Passcode must be at least 4 characters';
                              }
                              return null;
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 20),

                      // Thumbnail Source Segmented Control
                      Text(
                        'Topic Thumbnail',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(() {
                        final isVideo = controller.thumbnailSource.value == 'video';
                        return Container(
                          decoration: BoxDecoration(
                            color: inputBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderSideColor),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => controller.thumbnailSource.value = 'video',
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isVideo ? const Color(0xFF6366F1) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Use Video Thumbnail',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isVideo ? Colors.white : subtextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => controller.thumbnailSource.value = 'custom',
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !isVideo ? const Color(0xFF6366F1) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Upload Custom',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !isVideo ? Colors.white : subtextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      // Thumbnail Content Selector / Preview
                      Obx(() {
                        if (controller.thumbnailSource.value == 'custom') {
                          return _buildCustomThumbnailArea(context, controller, borderSideColor, inputBgColor, textColor, subtextColor);
                        } else {
                          return _buildVideoThumbnailArea(context, controller, borderSideColor, textColor, subtextColor);
                        }
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderSideColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: subtextColor,
                      side: BorderSide(color: borderSideColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isSubmitting.value
                          ? null
                          : () async {
                              final isValid = await controller.validateFormBeforeSubmit();
                              if (!isValid) return;

                              controller.isSubmitting.value = true;
                              try {
                                await onCreateTopicSubmitted(controller);
                                if (context.mounted) Navigator.of(context).pop();
                              } catch (e) {
                                AppSnackbar.show(
                                  'Error',
                                  'Failed to create topic: $e',
                                  backgroundColor: AppColors.error,
                                  colorText: Colors.white,
                                );
                              } finally {
                                controller.isSubmitting.value = false;
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: controller.isSubmitting.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Topic', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom Thumbnail Upload Area with Cloud Vision Status Indicators
  Widget _buildCustomThumbnailArea(
    BuildContext context,
    CreateTopicController controller,
    Color borderSideColor,
    Color inputBgColor,
    Color textColor,
    Color subtextColor,
  ) {
    final imageBytes = controller.pickedCustomImageBytes.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: controller.pickCustomThumbnail,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 130,
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderSideColor,
                style: imageBytes == null ? BorderStyle.solid : BorderStyle.none,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageBytes != null
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(imageBytes, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: controller.clearCustomThumbnail,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 32,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select custom thumbnail image',
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verified via Google Cloud Vision AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),

        // Vision AI Verification Status Bar
        if (imageBytes != null) ...[
          if (controller.isVisionScanning.value)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Scanning image with Google Cloud Vision AI...',
                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else if (controller.isVisionApproved.value)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verified safe by Google Cloud Vision AI',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else if (controller.visionError.value.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.visionError.value,
                      style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Video Link & Thumbnail Selector
  Widget _buildVideoThumbnailArea(
    BuildContext context,
    CreateTopicController controller,
    Color borderSideColor,
    Color textColor,
    Color subtextColor,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: channelVideosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No channel videos found. Select "Upload Custom" or link a video after uploading.',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        final channelVideos = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link Videos (At least 1 required for video thumbnail):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderSideColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: channelVideos.length,
                separatorBuilder: (c, i) => Divider(height: 1, color: borderSideColor),
                itemBuilder: (context, index) {
                  final video = channelVideos[index];
                  final videoId = (video['id'] as String?) ?? '';
                  final videoTitle = (video['title'] as String?) ?? 'Untitled Video';
                  final thumbUrl = (video['thumbnailUrl'] as String?) ?? '';
                  final isSelected = controller.selectedVideoIds.contains(videoId);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (val) {
                      controller.toggleVideoSelection(videoId, thumbUrl);
                    },
                    dense: true,
                    activeColor: const Color(0xFF6366F1),
                    title: Text(
                      videoTitle,
                      style: TextStyle(fontSize: 13, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: Container(
                      width: 44,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade800,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: thumbUrl.isNotEmpty
                          ? Image.network(thumbUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie, size: 16))
                          : const Icon(Icons.movie, size: 16),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
