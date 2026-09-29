import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 8: Video Playlist Assignment and Creation
class CreateContentPlaylistSection extends StatelessWidget {
  const CreateContentPlaylistSection({
    required this.uploadController,
    required this.playlistController,
    super.key,
  });

  final UploadController uploadController;
  final PlaylistController playlistController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedPlaylistId = uploadController.selectedPlaylist.value;

      // Combine playlists from user's playlists and public playlists without duplicates
      final combinedMap = <String, PlaylistModel>{};
      for (final p in playlistController.allUserPlaylists) {
        combinedMap[p.id] = p;
      }
      for (final p in playlistController.playlists) {
        combinedMap[p.id] = p;
      }
      for (final p in playlistController.publicPlaylists) {
        combinedMap[p.id] = p;
      }
      final playlists = combinedMap.values.toList();
      final currentPlaylist =
          playlists.firstWhereOrNull((p) => p.id == selectedPlaylistId);

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '8. Playlist',
                  style: context.themeTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final createCtrl = Get.isRegistered<CreatePlaylistController>()
                        ? Get.find<CreatePlaylistController>()
                        : Get.put(CreatePlaylistController());
                    createCtrl.resetForm();

                    final dynamic created = await Navigator.of(context).push<dynamic>(
                      MaterialPageRoute(
                        builder: (ctx) => const CreatePlaylistScreen(fromUpload: true),
                      ),
                    );

                    if (created is PlaylistModel) {
                      playlistController.refreshPlaylistsTick();
                      await playlistController.refreshPlaylists();
                      uploadController.selectedPlaylist.value = created.id;
                      AppSnackbar.success(
                        'Playlist created! Video will be added upon publishing.',
                      );
                    }
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text(
                    'Create Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: playlists.any((p) => p.id == selectedPlaylistId)
                  ? selectedPlaylistId
                  : '',
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select Playlist to save video (Optional)',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
                fillColor: const Color(0xFF0F0F11),
                filled: true,
                prefixIcon: const Icon(Icons.playlist_play_rounded,
                    color: Colors.white, size: 20),
                suffixIcon: selectedPlaylistId.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                        onPressed: () =>
                            uploadController.selectedPlaylist.value = '',
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              dropdownColor: const Color(0xFF161618),
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    'None (Do not save to playlist)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                ...playlists.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Row(
                      children: [
                        Icon(
                          p.isPublic ? Icons.public : Icons.lock_outline,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.playlistName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.videoCount > 0)
                          Text(
                            ' ${p.videoCount}v',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                uploadController.selectedPlaylist.value = val ?? '';
              },
            ),
            if (currentPlaylist != null) ...[
              const SizedBox(height: 8),
              Text(
                '✓ Video will be automatically added to "${currentPlaylist.playlistName}" upon publishing.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Section 9: Video Topic Association and Hub Connection
class CreateContentTopicSection extends StatelessWidget {
  const CreateContentTopicSection({
    required this.uploadController,
    required this.onCreateNewTopic,
    super.key,
  });

  final UploadController uploadController;
  final void Function(bool isDark) onCreateNewTopic;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedTopicId = uploadController.selectedTopicId.value;
      final newTopicData = uploadController.newTopicData;
      final hasNewTopicDraft = newTopicData.isNotEmpty;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Look up selected topic model if any
      Topic? selectedTopic;
      if (selectedTopicId.isNotEmpty &&
          !hasNewTopicDraft &&
          selectedTopicId != 'new_topic_draft') {
        selectedTopic = uploadController.availableTopics.firstWhereOrNull(
          (t) => t.slug == selectedTopicId || t.id == selectedTopicId,
        );
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '9. Topic',
                  style: context.themeTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onCreateNewTopic(isDark),
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text(
                    'Create Topic',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasNewTopicDraft)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                newTopicData['title'] ?? 'New Topic Draft',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Draft',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${newTopicData['handle'] ?? ''} • ${newTopicData['category'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 18),
                      tooltip: 'Change Topic',
                      onPressed: () {
                        TopicSelectionBottomSheet.show(
                          context,
                          uploadController,
                          onCreateNewTopic: onCreateNewTopic,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      tooltip: 'Remove Topic',
                      onPressed: () {
                        uploadController.newTopicData.clear();
                        uploadController.selectedTopicId.value = '';
                      },
                    ),
                  ],
                ),
              )
            else if (selectedTopic != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    if (selectedTopic.thumbnailUrl != null &&
                        selectedTopic.thumbnailUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: selectedTopic.thumbnailUrl!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 42,
                            height: 42,
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(Icons.topic,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.topic,
                            color: Colors.white, size: 20),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedTopic.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedTopic.handle} • ${FormatUtils.formatCount(selectedTopic.followerCount)} followers • ${FormatUtils.formatCount(selectedTopic.videoCount)} videos',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz,
                          color: Colors.white, size: 20),
                      tooltip: 'Change Topic',
                      onPressed: () {
                        TopicSelectionBottomSheet.show(
                          context,
                          uploadController,
                          onCreateNewTopic: onCreateNewTopic,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      tooltip: 'Remove Topic',
                      onPressed: () {
                        uploadController.selectedTopicId.value = '';
                      },
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () {
                  TopicSelectionBottomSheet.show(
                    context,
                    uploadController,
                    onCreateNewTopic: onCreateNewTopic,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.topic, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedTopicId.isNotEmpty
                                  ? selectedTopicId
                                  : 'Select Topic (Optional)',
                              style: TextStyle(
                                color: selectedTopicId.isNotEmpty
                                    ? Colors.white
                                    : Colors.white
                                        .withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            if (selectedTopicId.isEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Connect your video to a topic hub or category community',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (selectedTopicId.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                          onPressed: () =>
                              uploadController.selectedTopicId.value = '',
                        )
                      else
                        const Icon(Icons.chevron_right,
                            color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
