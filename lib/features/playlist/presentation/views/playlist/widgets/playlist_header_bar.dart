import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header bar for playlists screen with search and navigation controls.
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
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => controller.isSearchExpanded.value
                ? Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: controller.updateSearchQuery,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search playlists...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
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
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                      const SizedBox(width: 8),
                      Text(
                        'Playlists',
                        style: GoogleFonts.roboto(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
          Row(
            children: [
              Obx(
                () => !controller.isSearchExpanded.value
                    ? IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            controller.isSearchExpanded.value = true,
                      )
                    : const SizedBox.shrink(),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: onCreatePlaylist,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
