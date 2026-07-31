import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/theme/app_theme.dart';

void showMoreOptionsBottomSheet(
  BuildContext context,
  String videoId,
  Function(bool) rotateCallback,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.flag_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text('Report'),
            onTap: () {
              Navigator.pop(context);
              Get.snackbar('Report', 'Video reported.');
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.visibility_off_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text('Not interested'),
            onTap: () {
              Navigator.pop(context);
              UserPreferencesService.to.hideVideo(videoId);
              Get.snackbar(
                'Not interested',
                "We won't show this video anymore.",
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.download_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text('Save video'),
            onTap: () {
              Navigator.pop(context);
              Get.snackbar('Save Video', 'Video save not implemented.');
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rotate Video:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.rotate_left,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        rotateCallback(false);
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.rotate_right,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        rotateCallback(true);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
