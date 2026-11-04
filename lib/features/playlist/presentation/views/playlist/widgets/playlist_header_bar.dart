import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';

/// Top header bar for playlists screen with search and navigation controls matching reference design.
class PlaylistHeaderBar extends StatelessWidget {
  const PlaylistHeaderBar({
    required this.controller,
    required this.isMobile,
    required this.isDashboard,
    required this.onCreatePlaylist,
    this.searchController,
    super.key,
  });

  final PlaylistController controller;
  final TextEditingController? searchController;
  final bool isMobile;
  final bool isDashboard;
  final VoidCallback onCreatePlaylist;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Obx(() {
        final isSearchExpanded = controller.isSearchExpanded.value;

        if (isSearchExpanded) {
          return Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF2C2C2C),
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    maxLength: defaultMaxSearchLength,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
                    onChanged: controller.updateSearchQuery,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search playlists...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.isSearchExpanded.value = false;
                          searchController?.clear();
                          controller.updateSearchQuery('');
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildHeaderActionButton(
                icon: Icons.add_circle_outline_rounded,
                size: 22,
                tooltip: 'Create Playlist',
                onPressed: onCreatePlaylist,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    if (isDashboard && Get.isRegistered<HomeController>()) {
                      Get.find<HomeController>()
                          .sideNavSelectedIndex
                          .value = HomeController.indexLibrary;
                    } else {
                      Get.back();
                    }
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  'Playlists',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildHeaderActionButton(
                  icon: Icons.search_rounded,
                  size: 20,
                  tooltip: 'Search',
                  onPressed: () => controller.isSearchExpanded.value = true,
                ),
                const SizedBox(width: 10),
                _buildHeaderActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  size: 22,
                  tooltip: 'Create Playlist',
                  onPressed: onCreatePlaylist,
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required double size,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgPage,
        border: Border.all(
          color: const Color(0xFF2C2C2C),
          width: 1.2,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: Icon(
          icon,
          color: Colors.white,
          size: size,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
