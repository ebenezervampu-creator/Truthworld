import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/create_playlist/create_playlist_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Screen for creating and configuring a new video playlist.
class CreatePlaylistScreen extends StatelessWidget {
  const CreatePlaylistScreen({
    super.key,
    this.initialVideoId,
  });

  final String? initialVideoId;

  CreatePlaylistController get _c {
    final c = Get.isRegistered<CreatePlaylistController>()
        ? Get.find<CreatePlaylistController>()
        : Get.put(CreatePlaylistController());
    if (initialVideoId != null && c.selectedVideos.isEmpty) {
      c.loadInitialVideo(initialVideoId);
    }
    return c;
  }

  void _openVideoSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return PlaylistVideoSelectorSheet(
          currentlySelected: List.from(_c.selectedVideos),
          onConfirm: (selected) {
            _c.updateSelectedVideos(selected);
          },
        );
      },
    );
  }

  Future<void> _handleCreatePlaylist(BuildContext context) async {
    final success = await _c.submitCreatePlaylist();
    if (success && context.mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48.0 : 16.0,
                  vertical: 24.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlaylistFormHeader(isDesktop: isDesktop),
                        const SizedBox(height: 24),
                        if (isDesktop)
                          _buildDesktopTwoColumnLayout(context)
                        else
                          _buildMobileSingleColumnLayout(context),
                        const SizedBox(height: 24),
                        PlaylistThumbnailSection(
                          controller: _c,
                          isDesktop: isDesktop,
                        ),
                        const SizedBox(height: 32),
                        if (isDesktop)
                          PlaylistDesktopFooterActions(
                            controller: _c,
                            onSubmit: () => _handleCreatePlaylist(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isDesktop)
              PlaylistMobileStickyFooter(
                controller: _c,
                onSubmit: () => _handleCreatePlaylist(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTwoColumnLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Step 1, 2, 3)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaylistNameSection(controller: _c),
              const SizedBox(height: 24),
              PlaylistDescriptionSection(controller: _c),
              const SizedBox(height: 24),
              PlaylistVisibilitySection(controller: _c),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right Column (Step 4)
        Expanded(
          flex: 6,
          child: PlaylistVideosSection(
            controller: _c,
            onAddVideos: () => _openVideoSelectorModal(context),
            isDesktop: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSingleColumnLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlaylistNameSection(controller: _c),
        const SizedBox(height: 20),
        PlaylistDescriptionSection(controller: _c),
        const SizedBox(height: 20),
        PlaylistVisibilitySection(controller: _c),
        const SizedBox(height: 20),
        PlaylistVideosSection(
          controller: _c,
          onAddVideos: () => _openVideoSelectorModal(context),
          isDesktop: false,
        ),
      ],
    );
  }
}
