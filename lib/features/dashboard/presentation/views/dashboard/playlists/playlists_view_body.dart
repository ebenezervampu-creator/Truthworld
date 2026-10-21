import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlist_cards.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_state_widgets.dart';

/// Responsive playlists view displaying grid or list of channel playlists.
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
                if (width >= 1200) {
                  crossAxisCount = 4;
                } else if (width >= 850) {
                  crossAxisCount = 3;
                } else if (width >= 550) {
                  crossAxisCount = 2;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
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
