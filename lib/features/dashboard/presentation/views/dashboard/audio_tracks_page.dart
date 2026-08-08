import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// 100% Responsive, Industry-Standard Creator Studio Multi-Language Audio Tracks & Dubs Page
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<AudioTracksController>()
        ? Get.find<AudioTracksController>()
        : Get.put(AudioTracksController());
    controller.setChannelContext(widget.channelId);
  }

  @override
  void didUpdateWidget(covariant AudioTracksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      controller.setChannelContext(widget.channelId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 600 && width < 1024;

    final surfaceColor = widget.isDarkMode
        ? const Color(0xFF141414)
        : AppColors.textPrimary;
    const bgColor = AppColors.bgPage;
    final textColor = widget.isDarkMode
        ? AppColors.textPrimary
        : Colors.black;
    final textSecondaryColor = widget.isDarkMode
        ? AppColors.textSecondary
        : const Color(0xFF4B5563);
    final borderColor = widget.isDarkMode
        ? const Color(0xFF262626)
        : AppColors.bgDivider;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            );
          }

          if (controller.isEmpty) {
            return _buildEmptyChannelState(textColor, textSecondaryColor);
          }

          if (isDesktop) {
            return _buildDesktopLayout(
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
            );
          }

          if (isTablet) {
            return _buildTabletLayout(
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
            );
          }

          return _buildMobileLayout(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------
  Widget _buildEmptyChannelState(Color textColor, Color textSecondaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
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
              'No Audio Workspace Scope Available',
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Upload video content to configure multi-language audio dubbing, voiceovers, and commentary tracks.',
              style: TextStyle(fontSize: 14, color: textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (>= 1024px)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Video Selector Sidebar
        SizedBox(
          width: 320,
          child: _buildVideoSelectionSidebar(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
          ),
        ),
        VerticalDivider(width: 1, color: borderColor),
        // Right Main Panel: Workspace Editor
        Expanded(
          child: _buildMainWorkspaceEditor(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: false,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TABLET LAYOUT (600px - 1023px)
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: _buildVideoSelectionSidebar(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            compact: true,
          ),
        ),
        VerticalDivider(width: 1, color: borderColor),
        Expanded(
          child: _buildMainWorkspaceEditor(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: false,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (< 600px)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    final selectedVideo = controller.selectedVideo.value;

    return Column(
      children: [
        // Mobile Top Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              if (selectedVideo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: selectedVideo.thumbnailUrl,
                    width: 44,
                    height: 32,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.video_library_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedVideo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Audio & Voiceover Workspace',
                        style: TextStyle(fontSize: 11, color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    'Select a Video',
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _showMobileVideoPickerSheet(context, surfaceColor, textColor, textSecondaryColor, borderColor),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.brand),
                label: const Text(
                  'Change',
                  style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Mobile Workspace Editor Body
        Expanded(
          child: _buildMainWorkspaceEditor(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: true,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT SIDEBAR: VIDEO SELECTION LIST
  // ---------------------------------------------------------------------------
  Widget _buildVideoSelectionSidebar({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    bool compact = false,
  }) {
    return ColoredBox(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Title Block
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                  style: GoogleFonts.roboto(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.filteredVideos.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: textColor),
              onChanged: (value) => controller.setSearchQuery(value),
              decoration: InputDecoration(
                hintText: 'Filter videos...',
                hintStyle: TextStyle(color: textSecondaryColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondaryColor),
                filled: true,
                fillColor: widget.isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Video Feed Items List
          Expanded(
            child: Obx(() {
              final videos = controller.filteredVideos;
              if (videos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No videos match your query',
                      style: TextStyle(fontSize: 13, color: textSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  final isSelected = controller.selectedVideo.value?.id == video.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => controller.selectVideo(video),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brand.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brand.withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Video Thumbnail
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: video.thumbnailUrl,
                                      width: compact ? 56 : 72,
                                      height: compact ? 40 : 48,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.movie_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 3,
                                    right: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        video.duration,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),

                              // Video Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('MMM d, yyyy').format(video.createdAt.toDate()),
                                          style: TextStyle(fontSize: 11, color: textSecondaryColor),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.brand.withValues(alpha: 0.2)
                                                : Colors.grey.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.music_note_rounded, size: 10, color: AppColors.textPrimary),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${video.audioTracks.length}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
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

  // ---------------------------------------------------------------------------
  // MAIN WORKSPACE EDITOR (RIGHT PANEL / MOBILE CONTAINER)
  // ---------------------------------------------------------------------------
  Widget _buildMainWorkspaceEditor({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isMobile,
  }) {
    return Obx(() {
      final video = controller.selectedVideo.value;
      if (video == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded, size: 48, color: AppColors.textPrimary),
              const SizedBox(height: 16),
              Text(
                'Select a Video to Manage Audio Tracks',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a video from the list to add dubbing, voiceovers, or commentary.',
                style: TextStyle(fontSize: 13, color: textSecondaryColor),
              ),
            ],
          ),
        );
      }

      final activeTab = controller.activeTab.value;
      final showRequests = controller.showRequestsPanel.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar & Actions
          if (!isMobile)
            _buildWorkspaceHeaderBar(
              video: video,
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
            ),

          // Mobile Header Actions Row
          if (isMobile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showUploadTrackDialog(context),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.black),
                    label: const Text('Upload Track'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  Obx(() {
                    final reqCount = controller.languageRequests.where((r) => r.type == 'audio').length;
                    return OutlinedButton.icon(
                      onPressed: () => controller.toggleRequestsPanel(),
                      icon: Icon(
                        showRequests ? Icons.close_rounded : Icons.mark_chat_unread_rounded,
                        size: 16,
                        color: showRequests ? AppColors.error : AppColors.brand,
                      ),
                      label: Text(
                        showRequests ? 'Close Requests' : 'Requests ($reqCount)',
                        style: TextStyle(
                          color: showRequests ? AppColors.error : AppColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: showRequests ? AppColors.error : AppColors.brand.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: controller.isSaving.value ? null : () => controller.saveCurrentAudioTracks(),
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.save_rounded, size: 16, color: Colors.black),
                    label: Text(controller.isSaving.value ? 'Saving' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          // Workspace Tab & Language Selector Row
          _buildWorkspaceTabBar(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: isMobile,
          ),

          // Main Workspace Body Content
          Expanded(
            child: showRequests
                ? _buildRequestsGridSection(textColor, textSecondaryColor, surfaceColor, borderColor)
                : (activeTab == 'languages'
                    ? _buildLanguagesAndLayersManager(textColor, textSecondaryColor, surfaceColor, borderColor)
                    : _buildTracksAndDubsList(video, textColor, textSecondaryColor, surfaceColor, borderColor)),
          ),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // WORKSPACE HEADER BAR (DESKTOP / TABLET)
  // ---------------------------------------------------------------------------
  Widget _buildWorkspaceHeaderBar({
    required Video video,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Video Thumbnail & Details
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              width: 72,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                color: Colors.grey[800],
                child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(() {
                      final count = controller.availableLanguages.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count Dub Languages',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Multi-Language Dubbed Voiceover & Track Workspace',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ),

          // Action Buttons
          ElevatedButton.icon(
            onPressed: () => _showUploadTrackDialog(context),
            icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.black),
            label: const Text('Upload Track'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              final tracks = controller.currentTracks;
              if (tracks.isNotEmpty) {
                controller.downloadAudioTrack(tracks.first);
              } else {
                controller.showError('No audio track available to download.');
              }
            },
            icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.textPrimary),
            label: const Text(
              'Download Audio',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: BorderSide(color: widget.isDarkMode ? const Color(0xFF333333) : AppColors.bgDivider),
            ),
          ),
          const SizedBox(width: 8),

          Obx(() {
            final hasReqs = controller.languageRequests.where((r) => r.type == 'audio').isNotEmpty;
            final showRequests = controller.showRequestsPanel.value;
            final reqCount = controller.languageRequests.where((r) => r.type == 'audio').length;

            return Badge(
              isLabelVisible: hasReqs && !showRequests,
              label: Text('$reqCount'),
              backgroundColor: AppColors.brand,
              child: OutlinedButton.icon(
                onPressed: () => controller.toggleRequestsPanel(),
                icon: Icon(
                  showRequests ? Icons.close_rounded : Icons.mark_chat_unread_rounded,
                  size: 16,
                  color: showRequests ? AppColors.error : AppColors.brand,
                ),
                label: Text(
                  showRequests ? 'Close Requests' : 'Viewer Requests',
                  style: TextStyle(
                    color: showRequests ? AppColors.error : AppColors.brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

          Obx(() {
            return ElevatedButton.icon(
              onPressed: controller.isSaving.value ? null : () => controller.saveCurrentAudioTracks(),
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18, color: Colors.black),
              label: Text(controller.isSaving.value ? 'Saving...' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB BAR & LANGUAGE SELECTION BAR
  // ---------------------------------------------------------------------------
  Widget _buildWorkspaceTabBar({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Obx(() {
                final activeTab = controller.activeTab.value;
                return Row(
                  children: [
                    _buildTabPill(
                      id: 'tracks',
                      label: 'Audio & Video Tracks',
                      icon: Icons.graphic_eq_rounded,
                      isActive: activeTab == 'tracks',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      id: 'languages',
                      label: 'Languages & Layers (${controller.availableLanguages.length})',
                      icon: Icons.language_rounded,
                      isActive: activeTab == 'languages',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                  ],
                );
              }),
            ],
          ),

          // Scrollable Quick Language Filter Bar (for tracks tab)
          Obx(() {
            if (controller.activeTab.value != 'tracks') return const SizedBox.shrink();
            final activeCode = controller.selectedLanguage.value;

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Language:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...controller.availableLanguages.map((langCode) {
                      final isChosen = langCode == activeCode;
                      final name = controller.getLanguageName(langCode);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: isChosen,
                          onSelected: (_) => controller.switchLanguageTrack(langCode),
                          selectedColor: AppColors.brand,
                          backgroundColor: widget.isDarkMode
                              ? const Color(0xFF262626)
                              : const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isChosen ? Colors.black : textColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String id,
    required String label,
    required IconData icon,
    required bool isActive,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: () => controller.setActiveTab(id),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brand.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.brand : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? textColor : textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRACKS & DUBS LIST WORKSPACE
  // ---------------------------------------------------------------------------
  Widget _buildTracksAndDubsList(
    Video video,
    Color textColor,
    Color textSecondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Obx(() {
      if (controller.isLoadingTracks.value) {
        return const Center(child: CircularProgressIndicator(color: AppColors.brand));
      }

      final audioList = controller.currentTracks;
      final commentaryList = controller.commentaryTracks;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio Dubbing Section
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Audio Dubbing & Voiceover Tracks (${audioList.length})',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (audioList.isEmpty)
            _buildEmptyTrackCard('No audio dub tracks available for selected language.', textColor, textSecondaryColor, surfaceColor, borderColor)
          else
            ...audioList.asMap().entries.map((entry) {
              final index = entry.key;
              final track = entry.value;
              return _buildAudioTrackCard(
                index: index,
                track: track,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              );
            }),

          const SizedBox(height: 24),

          // Commentary & Multi-Video Section
          Row(
            children: [
              const Icon(Icons.subtitles_rounded, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Commentary & Alternate Video Tracks (${commentaryList.length})',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (commentaryList.isEmpty)
            _buildEmptyTrackCard('No commentary or alternate angle tracks attached.', textColor, textSecondaryColor, surfaceColor, borderColor)
          else
            ...commentaryList.map((track) {
              return _buildCommentaryTrackCard(
                track: track,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              );
            }),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // AUDIO TRACK CARD COMPONENT
  // ---------------------------------------------------------------------------
  Widget _buildAudioTrackCard({
    required int index,
    required AudioTrackItem track,
    required Color textColor,
    required Color textSecondaryColor,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    final isBase = track.isBaseTrack;
    final trackUrlController = TextEditingController(text: track.audioUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBase ? AppColors.success.withValues(alpha: 0.5) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Track Top Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBase
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBase ? Icons.volume_up_rounded : Icons.translate_rounded,
                    color: isBase ? AppColors.success : AppColors.brand,
                    size: 20,
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
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBase
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : AppColors.info.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isBase ? 'Primary Base Audio' : 'Dubbed Track',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isBase ? AppColors.success : AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBase
                            ? 'Static file mapping reference link'
                            : 'Multi-Language Audio Voiceover Track Stream',
                        style: TextStyle(fontSize: 12, color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),

                // Actions: Download, Copy Link & Delete
                IconButton(
                  tooltip: 'Download Audio Track',
                  icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.textPrimary),
                  onPressed: () => controller.downloadAudioTrack(track),
                ),
                IconButton(
                  tooltip: 'Copy Reference Link',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textPrimary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: track.audioUrl));
                    Get.snackbar(
                      'Link Copied',
                      'Track URL copied to clipboard',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.success,
                      colorText: Colors.black,
                    );
                  },
                ),
                if (!isBase)
                  IconButton(
                    tooltip: 'Delete Track',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    onPressed: () => controller.removeDubForLanguage(track.languageCode),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Stream URL Input Box
            Text(
              'Storage Stream URL Reference:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondaryColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: trackUrlController,
              style: TextStyle(fontSize: 13, color: textColor, fontFamily: 'monospace'),
              onChanged: (val) => controller.updateTrackUrl(index, val),
              decoration: InputDecoration(
                hintText: 'Provide direct HTTPS audio target file URI e.g. https://...',
                hintStyle: TextStyle(fontSize: 12, color: textSecondaryColor),
                filled: true,
                fillColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMENTARY TRACK CARD
  // ---------------------------------------------------------------------------
  Widget _buildCommentaryTrackCard({
    required CommentaryTrackItem track,
    required Color textColor,
    required Color textSecondaryColor,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.video_collection_rounded, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: ${track.role} • Lang: ${track.langCode.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Download Track',
            icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.textPrimary),
            onPressed: () => controller.downloadCommentaryTrack(track),
          ),
          IconButton(
            tooltip: 'Copy Reference Link',
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textPrimary),
            onPressed: () => controller.exportTrackLinkToClipboard(track.videoUrl),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
            onPressed: () => controller.deleteCommentaryTrack(track.id),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTrackCard(
    String message,
    Color textColor,
    Color textSecondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: textSecondaryColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LANGUAGES & LAYERS MANAGER TAB
  // ---------------------------------------------------------------------------
  Widget _buildLanguagesAndLayersManager(
    Color textColor,
    Color textSecondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Configured Language Dub Layers',
          style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage available language streams for viewer audio track switching.',
          style: TextStyle(fontSize: 13, color: textSecondaryColor),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final langs = controller.availableLanguages;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: langs.map((code) {
              final name = controller.getLanguageName(code);
              return Chip(
                avatar: const Icon(Icons.language_rounded, size: 16, color: AppColors.textPrimary),
                label: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                backgroundColor: surfaceColor,
                side: BorderSide(color: borderColor),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIEWER REQUESTS GRID SECTION
  // ---------------------------------------------------------------------------
  Widget _buildRequestsGridSection(
    Color textColor,
    Color textSecondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Obx(() {
      final reqs = controller.languageRequests.where((r) => r.type == 'audio').toList();
      if (reqs.isEmpty) {
        return Center(
          child: Text(
            'No pending dubbing requests from viewers.',
            style: TextStyle(fontSize: 14, color: textSecondaryColor),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Viewer Audio Dubbing Requests (${reqs.length})',
            style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          ...reqs.map((req) {
            final langName = controller.getLanguageName(req.language);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_chat_unread_rounded, color: AppColors.brand, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Language: $langName',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          'Requested by ${req.count} viewers',
                          style: TextStyle(fontSize: 12, color: textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showUploadTrackDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
                    label: const Text('Add Dub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // MOBILE VIDEO PICKER BOTTOM SHEET
  // ---------------------------------------------------------------------------
  void _showMobileVideoPickerSheet(
    BuildContext context,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Video for Audio Workspace',
                  style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              Expanded(
                child: _buildVideoSelectionSidebar(
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UPLOAD TRACK DIALOG MODAL
  // ---------------------------------------------------------------------------
  void _showUploadTrackDialog(BuildContext context) {
    var selectedLangCode = 'es';
    var selectedRole = 'Dubbed Audio';
    PlatformFile? selectedFile;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Upload Audio Dub Track',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Language Dropdown
                    Text(
                      'Language',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? AppColors.textSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedLangCode,
                      dropdownColor: widget.isDarkMode ? const Color(0xFF262626) : Colors.white,
                      style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                      items: const [
                        DropdownMenuItem(value: 'es', child: Text('Spanish (Español)')),
                        DropdownMenuItem(value: 'fr', child: Text('French (Français)')),
                        DropdownMenuItem(value: 'de', child: Text('German (Deutsch)')),
                        DropdownMenuItem(value: 'te', child: Text('Telugu (తెలుగు)')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi (हिन्दी)')),
                        DropdownMenuItem(value: 'ja', child: Text('Japanese (日本語)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedLangCode = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: widget.isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Track Type Dropdown
                    Text(
                      'Track Type / Role',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? AppColors.textSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      dropdownColor: widget.isDarkMode ? const Color(0xFF262626) : Colors.white,
                      style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                      items: const [
                        DropdownMenuItem(value: 'Dubbed Audio', child: Text('Dubbed Audio Track')),
                        DropdownMenuItem(value: 'AI Voiceover', child: Text('AI Voiceover Stream')),
                        DropdownMenuItem(value: 'Director Commentary', child: Text('Director Commentary')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: widget.isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // File Picker Dropzone
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setDialogState(() => selectedFile = result.files.first);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedFile != null ? AppColors.success : AppColors.brand.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                              size: 32,
                              color: selectedFile != null ? AppColors.success : AppColors.brand,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedFile != null ? selectedFile!.name : 'Click to Pick Audio File (.mp3, .wav, .m4a)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedFile == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          final config = BatchTrackUploadConfig(
                            file: selectedFile!,
                            title: 'Dub Track - $selectedLangCode',
                            role: selectedRole,
                            type: 'Audio',
                            langCode: selectedLangCode,
                          );
                          controller.uploadMultipleTrackFiles(items: [config]);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Upload & Attach'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
