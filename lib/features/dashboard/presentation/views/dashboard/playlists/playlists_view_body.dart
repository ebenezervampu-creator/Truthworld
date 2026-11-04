import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlist_cards.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_state_widgets.dart';

/// Responsive playlists view displaying YouTube Studio-inspired grid or list of channel playlists.
class PlaylistsViewBody extends GetView<PlaylistsManagementController> {
  const PlaylistsViewBody({
    required this.channelId,
    super.key,
  });

  final String channelId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlaylistModel>>(
      stream: controller.fetchChannelPlaylists(channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PlaylistsLoadingGrid();
        }

        if (snapshot.hasError) {
          return PlaylistsErrorState(
            onRetry: () => controller.update(),
          );
        }

        final playlists = snapshot.data ?? [];

        // Update controller reactive list safely
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.playlistsList.length != playlists.length) {
            controller.playlistsList.assignAll(playlists);
          }
        });

        return Obx(() {
          final filtered = controller.filteredPlaylists;

          if (filtered.isEmpty) {
            return PlaylistsEmptyState(
              isSearch: controller.searchQuery.value.isNotEmpty,
              onClearFilters: () {
                controller.searchController.clear();
                controller.updateSearchQuery('');
                controller.setFilterMode('all');
              },
            );
          }

          if (controller.isGridView.value) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                var crossAxisCount = 1;
                if (width >= 1300) {
                  crossAxisCount = 4;
                } else if (width >= 900) {
                  crossAxisCount = 3;
                } else if (width >= 580) {
                  crossAxisCount = 2;
                }

                const spacing = 16.0;
                final totalSpacing = (crossAxisCount - 1) * spacing;
                final itemWidth = (width - totalSpacing) / crossAxisCount;

                // Dynamically calculate aspect ratio to perfectly fit 16:9 thumbnail + metadata
                final thumbnailHeight = (itemWidth - 20) * (9 / 16) + 16;
                const metadataHeight = 180.0;
                final totalCardHeight = thumbnailHeight + metadataHeight;
                final childAspectRatio = (itemWidth / totalCardHeight).clamp(0.65, 1.25);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final playlist = filtered[index];
                    return PlaylistGridCard(
                      playlist: playlist,
                      channelId: channelId,
                    );
                  },
                );
              },
            );
          } else {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final playlist = filtered[index];
                return PlaylistListCard(
                  playlist: playlist,
                  channelId: channelId,
                );
              },
            );
          }
        });
      },
    );
  }
}
