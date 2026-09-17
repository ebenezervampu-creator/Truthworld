import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';

/// Desktop footer actions (Cancel & Create Playlist buttons).
class PlaylistDesktopFooterActions extends StatelessWidget {
  const PlaylistDesktopFooterActions({
    required this.controller,
    required this.onSubmit,
    super.key,
  });

  final CreatePlaylistController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCreating = controller.isCreating.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: Get.back,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: isCreating ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create Playlist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

/// Mobile sticky footer with full-width primary CTA.
class PlaylistMobileStickyFooter extends StatelessWidget {
  const PlaylistMobileStickyFooter({
    required this.controller,
    required this.onSubmit,
    super.key,
  });

  final CreatePlaylistController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCreating = controller.isCreating.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isCreating ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isCreating
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
                    'Create Playlist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      );
    });
  }
}
