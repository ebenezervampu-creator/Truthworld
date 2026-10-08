import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/video_picker_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dialog to create a new channel playlist with title, description, visibility, and initial videos.
class CreatePlaylistDialog extends StatelessWidget {
  const CreatePlaylistDialog({
    required this.channelId,
    super.key,
  });

  final String channelId;

  static Future<void> show(
    BuildContext context, {
    required String channelId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreatePlaylistDialog(channelId: channelId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final selectedVisibility = PlaylistVisibility.public.obs;
    final selectedVideos = <Video>[].obs;
    final isCreating = false.obs;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Playlist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: TWTypography.brandFamily,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Curate your channel videos into an organized playlist series.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: TWTypography.uiFamily,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        inputFormatters: TruthworldTextInputFormatters.standard,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontFamily: TWTypography.uiFamily,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Playlist Title *',
                          labelStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: TWTypography.uiFamily,
                          ),
                          hintText: 'e.g., Full Flutter Course 2026',
                          hintStyle: const TextStyle(
                            color: AppColors.textTertiary,
                            fontFamily: TWTypography.uiFamily,
                          ),
                          filled: true,
                          fillColor: AppColors.bgPage,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.bgDivider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.bgDivider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        inputFormatters: TruthworldTextInputFormatters.standard,
                        maxLines: 3,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontFamily: TWTypography.uiFamily,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          labelStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: TWTypography.uiFamily,
                          ),
                          hintText:
                              'What is this playlist about? Help viewers find your topics.',
                          hintStyle: const TextStyle(
                            color: AppColors.textTertiary,
                            fontFamily: TWTypography.uiFamily,
                          ),
                          filled: true,
                          fillColor: AppColors.bgPage,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.bgDivider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.bgDivider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        return DropdownButtonFormField<PlaylistVisibility>(
                          value: selectedVisibility.value,
                          dropdownColor: const Color(0xFF1E1E1E),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontFamily: TWTypography.uiFamily,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Visibility',
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: TWTypography.uiFamily,
                            ),
                            filled: true,
                            fillColor: AppColors.bgPage,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.bgDivider,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.bgDivider,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          items: PlaylistVisibility.values.map((vis) {
                            return DropdownMenuItem(
                              value: vis,
                              child: Text(vis.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              selectedVisibility.value = val;
                            }
                          },
                        );
                      }),
                      const SizedBox(height: 20),

                      // Initial Videos Selection Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Initial Videos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: TWTypography.brandFamily,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => VideoPickerSheet.show(
                              context,
                              channelId: channelId,
                              targetList: selectedVideos,
                            ),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            label: const Text(
                              'Add Videos',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: TWTypography.uiFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Obx(() {
                        if (selectedVideos.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.bgDivider,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'No videos selected yet (you can add videos anytime)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontFamily: TWTypography.uiFamily,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: selectedVideos.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final vid = selectedVideos[index];
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.bgPage,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.bgDivider,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      width: 48,
                                      height: 28,
                                      child: vid.thumbnailUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: vid.thumbnailUrl,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: AppColors.bgSurfaceHover,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      vid.title,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontFamily: TWTypography.uiFamily,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textPrimary,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        selectedVideos.removeAt(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Obx(() {
                    return ElevatedButton(
                      onPressed: isCreating.value
                          ? null
                          : () async {
                              final name = titleController.text.trim();
                              final titleVal = ContentValidator.validate(
                                name,
                                fieldName: 'Playlist Title',
                                minLength: 2,
                                maxLength: 80,
                              );
                              if (!titleVal.isValid) {
                                AppSnackbar.warning(titleVal.message);
                                return;
                              }

                              final desc = descController.text.trim();
                              if (desc.isNotEmpty) {
                                final descVal = ContentValidator.validate(
                                  desc,
                                  fieldName: 'Playlist Description',
                                  maxLength: 500,
                                );
                                if (!descVal.isValid) {
                                  AppSnackbar.warning(descVal.message);
                                  return;
                                }
                              }

                              isCreating.value = true;
                              final success = await controller.createPlaylist(
                                channelId: channelId,
                                name: name,
                                description: descController.text.trim(),
                                visibility: selectedVisibility.value,
                                selectedVideoIds: selectedVideos
                                    .map((v) => v.id)
                                    .toList(),
                              );
                              isCreating.value = false;

                              if (success && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
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
                      child: isCreating.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Create Playlist',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: TWTypography.uiFamily,
                              ),
                            ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
