import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialogs and bottom sheets used within the Library feature.
class LibraryDialogs {
  const LibraryDialogs._();

  static void showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Search Library',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          maxLength: ContentValidator.defaultMaxSearchLength,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: TruthworldTextInputFormatters.withLimit(
            ContentValidator.defaultMaxSearchLength,
          ),
          style: const TextStyle(color: primaryText),
          decoration: InputDecoration(
            hintText: 'Search videos, playlists...',
            hintStyle: const TextStyle(color: secondaryText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: buttonBg),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
            ),
            child: const Text(
              'Search',
              style: TextStyle(color: AppColors.bgPage),
            ),
          ),
        ],
      ),
    );
  }

  static void showCreatePlaylistDialog(BuildContext context) {
    Get.toNamed('/create-playlist');
  }

  static void showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildMoreOption(
              icon: Icons.settings_rounded,
              title: 'Library Settings',
              onTap: () {
                Navigator.pop(context);
                Get.toNamed('/settings');
              },
            ),
            _buildMoreOption(
              icon: Icons.download_rounded,
              title: 'Downloads',
              onTap: () {
                Navigator.pop(context);
                Get.toNamed('/downloads');
              },
            ),
            _buildMoreOption(
              icon: Icons.history_rounded,
              title: 'Clear All History',
              onTap: () {
                Navigator.pop(context);
                showClearHistoryDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMoreOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        title,
        style: const TextStyle(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  static void showClearHistoryDialog(BuildContext context) {
    final watchHistoryController = Get.isRegistered<WatchHistoryController>()
        ? Get.find<WatchHistoryController>()
        : Get.put(WatchHistoryController());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear History',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to clear your watch history? This action cannot be undone.',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await watchHistoryController.clearAllHistory();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
