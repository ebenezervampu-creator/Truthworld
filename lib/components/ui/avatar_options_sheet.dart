import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet for changing or removing user profile avatar.
class AvatarOptionsSheet {
  const AvatarOptionsSheet._();

  static void show(BuildContext context) {
    final settingsCtrl = UserSettingsController.to;
    final auth = AuthService.to;

    Get.bottomSheet(
      Material(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Change Profile Avatar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: Get.back,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Uploaded avatars are automatically verified for safety with Google Cloud Vision.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () {
                    Get.back();
                    settingsCtrl.changeAvatar(
                      source: ImageSource.gallery,
                      context: context,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () {
                    Get.back();
                    settingsCtrl.changeAvatar(
                      source: ImageSource.camera,
                      context: context,
                    );
                  },
                ),
                if (auth.activePhotoUrl.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.white),
                    title: const Text(
                      'Remove Avatar',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Get.back();
                      settingsCtrl.removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
