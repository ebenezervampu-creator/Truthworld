import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dialog to edit playlist name, description, and visibility.
class EditPlaylistDialog extends StatelessWidget {
  const EditPlaylistDialog({
    required this.playlist,
    super.key,
  });

  final PlaylistModel playlist;

  static Future<void> show(
    BuildContext context, {
    required PlaylistModel playlist,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => EditPlaylistDialog(playlist: playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();
    final titleController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description);
    final selectedVisibility = playlist.visibility.obs;
    final isSaving = false.obs;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Playlist Metadata',
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
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: TWTypography.uiFamily,
                ),
                decoration: InputDecoration(
                  labelText: 'Playlist Title',
                  labelStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: TWTypography.uiFamily,
                  ),
                  filled: true,
                  fillColor: AppColors.bgPage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                  labelText: 'Description',
                  labelStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: TWTypography.uiFamily,
                  ),
                  filled: true,
                  fillColor: AppColors.bgPage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                    if (val != null) selectedVisibility.value = val;
                  },
                );
              }),
              const SizedBox(height: 24),
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
                      onPressed: isSaving.value
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

                              isSaving.value = true;
                              final success =
                                  await controller.updatePlaylistMetadata(
                                playlistId: playlist.id,
                                name: name,
                                description: desc,
                                visibility: selectedVisibility.value,
                              );
                              isSaving.value = false;
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
                      child: isSaving.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Save Changes',
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
