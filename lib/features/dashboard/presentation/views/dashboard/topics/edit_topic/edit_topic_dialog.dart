import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_form_fields.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_thumbnail_selector.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_video_link_list.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Edit Topic Dialog matching Channel Wizard form aesthetics and design tokens.
class EditTopicDialog extends StatelessWidget {
  final Topic topic;
  final String channelId;
  final bool isDarkMode;
  final TopicManagementController controller;

  const EditTopicDialog({
    required this.topic,
    required this.channelId,
    required this.isDarkMode,
    required this.controller,
    super.key,
  });

  /// Static helper to display the Edit Topic dialog and safely manage controller lifecycle.
  static Future<void> show({
    required BuildContext context,
    required Topic topic,
    required String channelId,
    required bool isDarkMode,
    required TopicManagementController controller,
  }) async {
    if (Get.isRegistered<EditTopicController>(tag: topic.slug)) {
      Get.delete<EditTopicController>(tag: topic.slug, force: true);
    }

    await Get.dialog<void>(
      EditTopicDialog(
        topic: topic,
        channelId: channelId,
        isDarkMode: isDarkMode,
        controller: controller,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<EditTopicController>(tag: topic.slug)) {
        Get.delete<EditTopicController>(tag: topic.slug, force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editCtrl = Get.isRegistered<EditTopicController>(tag: topic.slug)
        ? Get.find<EditTopicController>(tag: topic.slug)
        : Get.put(
            EditTopicController(
              topic: topic,
              channelId: channelId,
              managementController: controller,
            ),
            tag: topic.slug,
          );

    return Obx(() {
      return Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.bgDivider),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Topic',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Get.back<void>();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: editCtrl.isLoading.value
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const EditTopicFieldLabel(label: 'Topic Title', isRequired: true),
                            const SizedBox(height: 8),
                            EditTopicInputField(
                              controller: editCtrl.titleController,
                              hintText: 'Enter topic title',
                              maxLength: 100,
                            ),
                            const SizedBox(height: 16),

                            const EditTopicFieldLabel(label: 'Description'),
                            const SizedBox(height: 8),
                            EditTopicInputField(
                              controller: editCtrl.descriptionController,
                              hintText: 'Describe your topic...',
                              maxLines: 3,
                              maxLength: 500,
                            ),
                            const SizedBox(height: 16),

                            // Category Dropdown
                            const EditTopicFieldLabel(label: 'Category', isRequired: true),
                            const SizedBox(height: 8),
                            EditTopicCategoryDropdown(controller: editCtrl),
                            const SizedBox(height: 16),

                            // Topic Visibility Type Selector
                            const EditTopicFieldLabel(label: 'Visibility Type', isRequired: true),
                            const SizedBox(height: 8),
                            EditTopicVisibilityDropdown(controller: editCtrl),
                            const SizedBox(height: 16),

                            // Topic Thumbnail Selector
                            const EditTopicFieldLabel(label: 'Topic Thumbnail'),
                            const SizedBox(height: 8),
                            EditTopicThumbnailSelector(controller: editCtrl),
                            const SizedBox(height: 16),

                            // Video Linking Section
                            const EditTopicFieldLabel(
                              label: 'Link Videos (At least 1 required)',
                              isRequired: true,
                            ),
                            const SizedBox(height: 8),
                            EditTopicVideoLinkList(controller: editCtrl),
                          ],
                        ),
                      ),
              ),

              // Dialog Action Buttons Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.bgDivider),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Get.back<void>();
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!editCtrl.isLoading.value)
                      ElevatedButton(
                        onPressed: editCtrl.isSaving.value
                            ? null
                            : () => editCtrl.submitUpdate(context: context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: editCtrl.isSaving.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
