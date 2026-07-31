import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/theme/app_colors.dart';

class AudioTracksPage extends StatefulWidget {
  const AudioTracksPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  State<AudioTracksPage> createState() => _AudioTracksPageState();
}

class _AudioTracksPageState extends State<AudioTracksPage> {
  late final AudioTracksController controller;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<AudioTracksController>()) {
      controller = Get.find<AudioTracksController>();
      controller.setChannelContext(widget.channelId);
    } else {
      controller = Get.put(AudioTracksController());
      controller.channelId.value = widget.channelId;
    }
  }

  @override
  void didUpdateWidget(covariant AudioTracksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      controller.setChannelContext(widget.channelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 800;
    final surfaceColor = widget.isDarkMode
        ? const Color(0xFF141414)
        : AppColors.textPrimary;
    const bgColor = AppColors.bgPage;
    const textColor = AppColors.textPrimary;
    const textSecondaryColor = AppColors.textSecondary;
    final borderColor = widget.isDarkMode
        ? const Color(0xFF262626)
        : AppColors.bgDivider;

    return ColoredBox(
      color: bgColor,
      child: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.brand,
              ),
            ),
          );
        }

        if (controller.isEmpty) {
          return _buildEmptyChannelState(textColor, textSecondaryColor);
        }

        return isDesktopOrTablet
            ? _buildDesktopSplitLayout(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              )
            : _buildMobileStackedLayout(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              );
      }),
    );
  }

  Widget _buildEmptyChannelState(Color textColor, Color textSecondaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.library_music_rounded,
              size: 64,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Audio Tracks Scope Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload base video files to assign local dub streams and alternate voiceovers.',
            style: TextStyle(fontSize: 15, color: textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSplitLayout(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Selection Layer: Videos Feed Column
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Title Block
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.video_library_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select Video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Embedded Live Text Filter Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search videos...',
                    hintStyle: TextStyle(
                      color: textSecondaryColor,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: textSecondaryColor,
                    ),
                    filled: true,
                    fillColor: widget.isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => controller.setSearchQuery(value),
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: borderColor),

              // Live Scrollable Listing
              Expanded(
                child: Obx(() {
                  final list = controller.filteredVideos;
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No matching videos found.',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final video = list[index];
                      final isSelected =
                          controller.selectedVideo.value?.id == video.id;
                      final audioMap = video.audioTracks;
                      final trackCount = audioMap.isEmpty
                          ? 1
                          : entireListUniqueTrackCounter(audioMap);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => controller.selectVideo(video),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.brand.withValues(
                                      alpha: 0.1,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.brand.withValues(
                                        alpha: 0.4,
                                      )
                                    : borderColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        width: 80,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(color: borderColor),
                                        errorWidget: (context, url, error) =>
                                            ColoredBox(
                                              color: borderColor,
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 16,
                                              ),
                                            ),
                                      ),
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.bgPage.withValues(
                                              alpha: 0.75,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            video.duration,
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 9,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        video.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppColors.brand
                                              : textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            (video.uploadedAt.runtimeType
                                                        .toString() ==
                                                    'Timestamp')
                                                ? DateFormat.yMMMd().format(
                                                    (video.uploadedAt
                                                                as dynamic)
                                                            .toDate()
                                                        as DateTime,
                                                  )
                                                : '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textSecondaryColor,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.brand.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.audiotrack_rounded,
                                                  size: 9,
                                                  color: AppColors.brand,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '$trackCount',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.brand,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),

        // Right Target Layer: Live Active Workspace Editor
        Expanded(
          child: Obx(() {
            if (controller.selectedVideo.value == null) {
              return _buildEmptySelectionState(textColor, textSecondaryColor);
            }
            return _buildEditorWorkspace(
              surfaceColor,
              textColor,
              textSecondaryColor,
              borderColor,
              isMobile: false,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMobileStackedLayout(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Obx(() {
      if (controller.selectedVideo.value != null) {
        return Column(
          children: [
            // Quick switch back banner bar
            Container(
              color: surfaceColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => controller.selectVideo(null),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Back to Video Scope',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: _buildEditorWorkspace(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
                isMobile: true,
              ),
            ),
          ],
        );
      }

      // Otherwise show scrollable catalog
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Channel Content',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final list = controller.filteredVideos;
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No videos found.',
                    style: TextStyle(color: textSecondaryColor, fontSize: 13),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final video = list[index];
                  final audioMap = video.audioTracks;
                  final trackCount = audioMap.isEmpty
                      ? 1
                      : entireListUniqueTrackCounter(audioMap);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        width: 64,
                        height: 42,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, err) => ColoredBox(
                          color: borderColor,
                          child: const Icon(Icons.broken_image, size: 16),
                        ),
                      ),
                    ),
                    title: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      '${video.duration} • $trackCount audio ${trackCount == 1 ? 'track' : 'tracks'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondaryColor,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.brand,
                    ),
                    onTap: () => controller.selectVideo(video),
                  );
                },
              );
            }),
          ),
        ],
      );
    });
  }

  Widget _buildEmptySelectionState(Color textColor, Color textSecondaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back,
              size: 48,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a Video to Load Multi-Language Audio Scope',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an uploaded file from the left sidebar to assign localized base and dub voiceovers.',
            style: TextStyle(fontSize: 14, color: textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorWorkspace(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor, {
    required bool isMobile,
  }) {
    final video = controller.selectedVideo.value!;

    return Column(
      children: [
        // Workspace Top Bar: Context & Actions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            width: 50,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Audio Dubbing Workspace',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showUploadTrackDialog(context),
                            icon: const Icon(
                              Icons.cloud_upload_rounded,
                              size: 14,
                            ),
                            label: const Text('Upload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Obx(() {
                          final showRequests =
                              controller.showRequestsPanel.value;
                          final audioReqCount = controller.languageRequests
                              .where((r) => r.type == 'audio')
                              .length;
                          return OutlinedButton.icon(
                            onPressed: () => controller.toggleRequestsPanel(),
                            icon: Icon(
                              showRequests
                                  ? Icons.close_rounded
                                  : Icons.mark_chat_unread_rounded,
                              size: 14,
                              color: showRequests
                                  ? AppColors.error
                                  : AppColors.brand,
                            ),
                            label: Text(
                              showRequests
                                  ? 'Tracks'
                                  : 'Requests ($audioReqCount)',
                              style: TextStyle(
                                fontSize: 12,
                                color: showRequests
                                    ? AppColors.error
                                    : AppColors.brand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              side: BorderSide(
                                color: showRequests
                                    ? AppColors.error.withValues(alpha: 0.5)
                                    : AppColors.brand.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 6),
                        Obx(() {
                          return ElevatedButton.icon(
                            onPressed: controller.isSaving.value
                                ? null
                                : () => controller.saveCurrentAudioTracks(),
                            icon: controller.isSaving.value
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.textPrimary,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 14),
                            label: Text(
                              controller.isSaving.value ? 'Saving' : 'Save',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        width: 50,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Obx(() {
                                if (!controller.hasUnsavedChanges.value) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Unsaved',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          Text(
                            'Multi-Language Dubbed Voiceover Track Workspace',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Upload Track Button
                    ElevatedButton.icon(
                      onPressed: () => _showUploadTrackDialog(context),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                      label: const Text('Upload Track'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Requests Toggle Button
                    Obx(() {
                      final hasReqs = controller.languageRequests
                          .where((r) => r.type == 'audio')
                          .isNotEmpty;
                      final showRequests = controller.showRequestsPanel.value;
                      return Badge(
                        isLabelVisible: hasReqs && !showRequests,
                        label: Text(
                          '${controller.languageRequests.where((r) => r.type == 'audio').length}',
                        ),
                        backgroundColor: AppColors.brand,
                        child: OutlinedButton.icon(
                          onPressed: () => controller.toggleRequestsPanel(),
                          icon: Icon(
                            showRequests
                                ? Icons.close_rounded
                                : Icons.mark_chat_unread_rounded,
                            size: 16,
                            color: showRequests
                                ? AppColors.error
                                : AppColors.brand,
                          ),
                          label: Text(
                            showRequests ? 'Close Requests' : 'Viewer Requests',
                            style: TextStyle(
                              color: showRequests
                                  ? AppColors.error
                                  : AppColors.brand,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: showRequests
                                ? AppColors.error
                                : AppColors.brand,
                            side: BorderSide(
                              color: showRequests
                                  ? AppColors.error.withValues(alpha: 0.5)
                                  : AppColors.brand.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),

                    // Save Changes Button
                    Obx(() {
                      return ElevatedButton.icon(
                        onPressed: controller.isSaving.value
                            ? null
                            : () => controller.saveCurrentAudioTracks(),
                        icon: controller.isSaving.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          controller.isSaving.value
                              ? 'Saving...'
                              : 'Save Changes',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      );
                    }),
                  ],
                ),
        ),

        // Studio Section Tab Bar: Audio & Video Tracks vs Languages & Target Layers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Obx(() {
            final activeTab = controller.activeTab.value;
            return Row(
              children: [
                InkWell(
                  onTap: () => controller.setActiveTab('tracks'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: activeTab == 'tracks'
                          ? AppColors.brand.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeTab == 'tracks'
                            ? AppColors.brand
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Audio & Video Tracks',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: activeTab == 'tracks'
                                ? AppColors.textPrimary
                                : textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => controller.setActiveTab('languages'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: activeTab == 'languages'
                          ? AppColors.brand.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeTab == 'languages'
                            ? AppColors.brand
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Languages & Layers (${controller.availableLanguages.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: activeTab == 'languages'
                                ? AppColors.textPrimary
                                : textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Quick Language Selector when on Tracks tab
                if (activeTab == 'tracks')
                  Obx(() {
                    final activeCode = controller.selectedLanguage.value;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: controller.availableLanguages.map((langCode) {
                          final isChosen = langCode == activeCode;
                          final name = controller.getLanguageName(langCode);

                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(name),
                              selected: isChosen,
                              onSelected: (_) =>
                                  controller.switchLanguageTrack(langCode),
                              selectedColor: AppColors.brand,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isChosen ? Colors.black : textColor,
                              ),
                              backgroundColor: widget.isDarkMode
                                  ? const Color(0xFF262626)
                                  : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
              ],
            );
          }),
        ),

        // Tab View Body
        Expanded(
          child: Obx(() {
            final activeTab = controller.activeTab.value;
            final showRequests = controller.showRequestsPanel.value;

            if (activeTab == 'languages') {
              return _buildLanguagesTab(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              );
            }

            // 'tracks' tab view
            if (isMobile) {
              if (showRequests) {
                return _buildRequestsPanel(
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                  isMobile: true,
                );
              } else {
                return _buildTracksList(
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                );
              }
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildTracksList(
                    surfaceColor,
                    textColor,
                    textSecondaryColor,
                    borderColor,
                  ),
                ),
                if (showRequests)
                  _buildRequestsPanel(
                    surfaceColor,
                    textColor,
                    textSecondaryColor,
                    borderColor,
                    isMobile: false,
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTracksList(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Obx(() {
      if (controller.isLoadingTracks.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        );
      }

      final audioList = controller.currentTracks;
      final commentaryList = controller.commentaryTracks;

      if (audioList.isEmpty && commentaryList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_collection_rounded,
                size: 48,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Audio Tracks or Multi-Video Commentary Configured',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Upload Director's commentary videos, Actors' reaction videos, or localized audio dubs.",
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Multi-Video Commentary & Perspective Tracks (Director, Actors, BTS)
          if (commentaryList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.video_camera_back_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Multi-Video Commentary & Perspectives (${commentaryList.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            ...commentaryList.map((track) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.video_collection_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    track.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      track.role,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      track.langCode.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.fileSizeMB > 0
                                    ? 'Attached video track • ${track.fileSizeMB.toStringAsFixed(1)} MB'
                                    : 'Attached video track reference',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons: Play Preview, Copy, Delete
                        if (track.videoUrl.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 22,
                            ),
                            color: AppColors.textPrimary,
                            tooltip: 'Preview Commentary Video',
                            onPressed: () => _showVideoPreviewDialog(
                              context,
                              '${track.role}: ${track.title}',
                              track.videoUrl,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          color: AppColors.textPrimary,
                          tooltip: 'Copy Stream Link',
                          onPressed: () =>
                              controller.exportTrackLinkToClipboard(
                                track.videoUrl.isNotEmpty
                                    ? track.videoUrl
                                    : track.audioUrl,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          color: AppColors.error,
                          tooltip: 'Remove Track',
                          onPressed: () =>
                              controller.deleteCommentaryTrack(track.id),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Section 2: Audio Dubbing & Voiceover Tracks
          if (audioList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.spatial_audio_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audio Dubbing & Voiceover Tracks (${audioList.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            ...audioList.asMap().entries.map((entry) {
              final index = entry.key;
              final track = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header tag metadata
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: track.isBaseTrack
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            track.isBaseTrack
                                ? Icons.volume_up_rounded
                                : Icons.spatial_audio_rounded,
                            size: 18,
                            color: track.isBaseTrack
                                ? AppColors.success
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    track.languageName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: track.isBaseTrack
                                          ? AppColors.success.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.brand.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      track.isBaseTrack
                                          ? 'Primary Audio'
                                          : 'Secondary Dub',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: track.isBaseTrack
                                            ? AppColors.success
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.isResolved
                                    ? 'Public storage link successfully auto-resolved'
                                    : 'Static file mapping reference link',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          color: AppColors.textPrimary,
                          tooltip: 'Copy Audio URI to clipboard',
                          onPressed: () => controller
                              .exportTrackLinkToClipboard(track.audioUrl),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 12),

                    Text(
                      'Storage Stream URL Reference:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: ValueKey(
                        '${controller.selectedLanguage.value}_${track.id}',
                      ),
                      initialValue: track.audioUrl,
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Provide direct HTTPS audio target file URI e.g. gs://...',
                        hintStyle: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) => controller.updateTrackUrl(index, val),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );
    });
  }

  Widget _buildRequestsPanel(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor, {
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: isMobile ? BorderSide.none : BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_chat_unread_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Viewer Language Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final reqs = controller.languageRequests
                      .where((r) => r.type == 'audio')
                      .toList();
                  if (reqs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reqs.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: Obx(() {
              final reqs = controller.languageRequests
                  .where((r) => r.type == 'audio')
                  .toList();
              if (controller.isLoadingRequests.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                );
              }
              if (reqs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.audiotrack_rounded,
                        size: 48,
                        color: textSecondaryColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No viewer language requests yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reqs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = reqs[index];
                  final matchingLanguage = controller.supportedLanguages
                      .firstWhereOrNull(
                        (l) => l.name.toLowerCase() == r.language.toLowerCase(),
                      );
                  final langCode = matchingLanguage?.code ?? r.language;
                  final isAlreadyAdded = controller.availableLanguages.contains(
                    langCode,
                  );

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    matchingLanguage?.name ?? r.language,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  if (matchingLanguage != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      matchingLanguage.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_rounded,
                                    size: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.count}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: isAlreadyAdded
                              ? OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                  label: const Text('Provisioned'),
                                  style: OutlinedButton.styleFrom(
                                    disabledForegroundColor: AppColors.success,
                                    side: const BorderSide(
                                      color: AppColors.success,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    controller.addLanguageLayer(langCode);
                                  },
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Add Layer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: AppColors.textPrimary,
                                    elevation: 0,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesTab(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    final video = controller.selectedVideo.value;
    final cachedLoc = video != null
        ? VideoMediaService.localizationCache[video.id]
        : null;
    final audioMap = Map<String, String>.from(
      cachedLoc?.audioTracks ?? video?.audioTracks ?? {},
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Banner & Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Languages & Localized Audio Dubs (${controller.supportedLanguages.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage audio dubbing tracks for all supported global languages. Upload audio dub files or edit direct URLs.',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Languages List
        ...controller.supportedLanguages.map((lang) {
          final langCode = lang.code;
          final langName = lang.name;
          final existingDubUrl = audioMap[langCode] ?? '';
          final isBaseAudio =
              langCode == 'en' || existingDubUrl == video?.videoUrl;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: existingDubUrl.isNotEmpty
                    ? AppColors.brand.withValues(alpha: 0.5)
                    : borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: existingDubUrl.isNotEmpty
                            ? AppColors.brand.withValues(alpha: 0.15)
                            : AppColors.textPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isBaseAudio
                            ? Icons.volume_up_rounded
                            : Icons.spatial_audio_rounded,
                        size: 20,
                        color: isBaseAudio
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                langName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  langCode.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: existingDubUrl.isNotEmpty
                                      ? (isBaseAudio
                                            ? AppColors.success.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppColors.brand.withValues(
                                                alpha: 0.15,
                                              ))
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isBaseAudio
                                      ? 'Primary Base Audio'
                                      : (existingDubUrl.isNotEmpty
                                            ? 'Dubbed Audio Active'
                                            : 'No Dubbed Audio File'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isBaseAudio
                                        ? AppColors.success
                                        : (existingDubUrl.isNotEmpty
                                              ? AppColors.textPrimary
                                              : textSecondaryColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            existingDubUrl.isNotEmpty
                                ? 'Target localized audio dubbing stream configured'
                                : 'Select file or input direct audio HTTPS stream URI below',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Manual Upload Dub File Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          unawaited(
                            controller.uploadSingleAudioDubForLanguage(
                              langCode: langCode,
                              file: result.files.first,
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.cloud_upload_rounded,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                      label: const Text(
                        'Upload Dub File',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Action buttons: Copy & Remove
                    if (existingDubUrl.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        color: AppColors.textPrimary,
                        tooltip: 'Copy Audio URI',
                        onPressed: () => controller.exportTrackLinkToClipboard(
                          existingDubUrl,
                        ),
                      ),
                      if (!isBaseAudio)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          color: AppColors.error,
                          tooltip: 'Remove Dub Track',
                          onPressed: () =>
                              controller.removeDubForLanguage(langCode),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Audio Stream URL TextFormField
                TextFormField(
                  key: ValueKey(
                    'dub_url_${langCode}_${existingDubUrl.hashCode}',
                  ),
                  initialValue: existingDubUrl,
                  style: GoogleFonts.robotoMono(fontSize: 12, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Direct Audio Stream URL ($langName)',
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: textSecondaryColor,
                    ),
                    hintText:
                        'Enter direct audio HTTPS target URI e.g. https://storage... or gs://...',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: textSecondaryColor,
                    ),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  onChanged: (val) =>
                      controller.updateDubUrlForLanguage(langCode, val),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),
        Divider(color: borderColor),
        const SizedBox(height: 16),

        // Viewer Language Requests Section
        _buildRequestsPanel(
          surfaceColor,
          textColor,
          textSecondaryColor,
          borderColor,
          isMobile: false,
        ),
      ],
    );
  }

  int entireListUniqueTrackCounter(Map<String, String> map) {
    final keys = map.keys.toList();
    if (!keys.contains('en')) return keys.length + 1;
    return keys.length;
  }

  void _showVideoPreviewDialog(
    BuildContext context,
    String title,
    String videoUrl,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: 720,
              height: 480,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      color: const Color(0xFF141414),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 64,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              videoUrl,
                              style: GoogleFonts.robotoMono(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUploadTrackDialog(BuildContext context) {
    final batchItems = <BatchTrackUploadConfig>[].obs;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 640,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Obx(() {
                final isUploading = controller.isUploading.value;
                final progress = controller.uploadProgress.value;
                final status = controller.uploadStatus.value;

                return IgnorePointer(
                  ignoring: isUploading,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.video_collection_rounded,
                                  color: AppColors.textPrimary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Multi-Video & Track Upload',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    "Upload Director's Commentary, Actors' video, BTS & Audio Dubs",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!isUploading)
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.bgDivider),
                      const SizedBox(height: 16),

                      if (batchItems.isEmpty) ...[
                        Center(
                          child: InkWell(
                            onTap: () async {
                              final result = await FilePicker.pickFiles(
                                allowMultiple: true,
                                allowedExtensions: [
                                  'mp4',
                                  'mov',
                                  'avi',
                                  'mkv',
                                  'mp3',
                                  'wav',
                                  'm4a',
                                  'aac',
                                ],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                for (final f in result.files) {
                                  final ext = f.extension?.toLowerCase() ?? '';
                                  final isAudio = [
                                    'mp3',
                                    'wav',
                                    'm4a',
                                    'aac',
                                  ].contains(ext);
                                  final baseName = f.name.contains('.')
                                      ? f.name.substring(
                                          0,
                                          f.name.lastIndexOf('.'),
                                        )
                                      : f.name;

                                  batchItems.add(
                                    BatchTrackUploadConfig(
                                      file: f,
                                      title: baseName,
                                      role: isAudio
                                          ? 'Voiceover Track'
                                          : 'Director Commentary',
                                      type: isAudio ? 'Audio' : 'Video',
                                      langCode: 'en',
                                    ),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 36,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgInput,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 44,
                                    color: AppColors.textPrimary,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Select Videos & Audio Files',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Choose multiple files (Director Commentary video, Actors video, BTS, Audio dubs)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected Tracks (${batchItems.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.pickFiles(
                                  allowMultiple: true,
                                  allowedExtensions: [
                                    'mp4',
                                    'mov',
                                    'avi',
                                    'mkv',
                                    'mp3',
                                    'wav',
                                    'm4a',
                                    'aac',
                                  ],
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  for (final f in result.files) {
                                    final ext =
                                        f.extension?.toLowerCase() ?? '';
                                    final isAudio = [
                                      'mp3',
                                      'wav',
                                      'm4a',
                                      'aac',
                                    ].contains(ext);
                                    final baseName = f.name.contains('.')
                                        ? f.name.substring(
                                            0,
                                            f.name.lastIndexOf('.'),
                                          )
                                        : f.name;

                                    batchItems.add(
                                      BatchTrackUploadConfig(
                                        file: f,
                                        title: baseName,
                                        role: isAudio
                                            ? 'Voiceover Track'
                                            : 'Director Commentary',
                                        type: isAudio ? 'Audio' : 'Video',
                                        langCode: 'en',
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              label: const Text(
                                'Add More Files',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: batchItems.length,
                            separatorBuilder: (context, idx) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final item = batchItems[idx];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.bgInput,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.bgDivider,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          item.type == 'Audio'
                                              ? Icons.audiotrack_rounded
                                              : Icons.video_camera_back_rounded,
                                          size: 18,
                                          color: AppColors.textPrimary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(item.file.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () =>
                                              batchItems.removeAt(idx),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            initialValue: item.title,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Track Title',
                                              labelStyle: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            onChanged: (v) => item.title = v,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<String>(
                                            value: item.role,
                                            isDense: true,
                                            dropdownColor: AppColors.bgSurface,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Track Role / Type',
                                              labelStyle: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'Director Commentary',
                                                child: Text(
                                                  "Director's Commentary",
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Actors Commentary',
                                                child: Text(
                                                  "Actors' Commentary",
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Behind the Scenes',
                                                child: Text(
                                                  'Behind the Scenes',
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Alternate Angle',
                                                child: Text(
                                                  'Alternate Angle / POV',
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Dubbed Video',
                                                child: Text('Dubbed Video'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Voiceover Track',
                                                child: Text('Voiceover Audio'),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) {
                                                item.role = v;
                                                batchItems.refresh();
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: item.langCode,
                                            dropdownColor: AppColors.bgSurface,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Lang',
                                              labelStyle: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            items: controller.supportedLanguages
                                                .map((l) {
                                                  return DropdownMenuItem(
                                                    value: l.code,
                                                    child: Text(
                                                      l.code.toUpperCase(),
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                            onChanged: (v) {
                                              if (v != null) item.langCode = v;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      if (isUploading) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.bgDivider,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.brand,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (!isUploading)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: batchItems.isEmpty
                                  ? null
                                  : () async {
                                      final success = await controller
                                          .uploadMultipleTrackFiles(
                                            items: batchItems,
                                          );
                                      if (success && context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                              icon: const Icon(
                                Icons.cloud_upload_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Upload (${batchItems.length}) Tracks',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: AppColors.textPrimary,
                                disabledBackgroundColor: AppColors.brand
                                    .withValues(alpha: 0.4),
                                disabledForegroundColor:
                                    AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
