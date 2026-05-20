import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';

class AudioTracksPage extends StatefulWidget {
  final String channelId;
  final bool isDarkMode;

  const AudioTracksPage({
    super.key,
    required this.channelId,
    required this.isDarkMode,
  });

  @override
  State<AudioTracksPage> createState() => _AudioTracksPageState();
}

class _AudioTracksPageState extends State<AudioTracksPage> {
  late final AudioTracksController controller;

  @override
  void initState() {
    super.initState();
    // Retrieve persistent singleton or initialize lazily on-the-fly
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
        : Colors.white;
    final bgColor = widget.isDarkMode
        ? AppColors.bgPage
        : AppColors.bgPage;
    final textColor = widget.isDarkMode
        ? Colors.white
        : AppColors.textPrimary;
    final textSecondaryColor = widget.isDarkMode
        ? Colors.white60
        : AppColors.textSecondary;
    final borderColor = widget.isDarkMode
        ? const Color(0xFF262626)
        : AppColors.bgDivider;

    return Container(
      color: bgColor,
      child: Obx(() {
        if (controller.isLoading) {
          return Center(
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
            child: Icon(
              Icons.library_music_rounded,
              size: 64,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Audio Tracks Scope Available',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload base video files to assign local dub streams and alternate voiceovers.',
            style: GoogleFonts.roboto(fontSize: 15, color: textSecondaryColor),
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
                    Icon(
                      Icons.video_library_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select Video',
                      style: GoogleFonts.roboto(
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
                  style: GoogleFonts.roboto(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search videos...',
                    hintStyle: GoogleFonts.roboto(
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                        style: GoogleFonts.roboto(
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
                                // Thumbnail Element
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
                                            Container(
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
                                            color: Colors.black.withValues(
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
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Details Block
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        video.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.roboto(
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
                                                        .toDate(),
                                                  )
                                                : '',
                                            style: GoogleFonts.roboto(
                                              fontSize: 11,
                                              color: textSecondaryColor,
                                            ),
                                          ),
                                          // Badge indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.audiotrack_rounded,
                                                  size: 9,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '$trackCount',
                                                  style: GoogleFonts.roboto(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xFF3B82F6,
                                                    ),
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
    return Column(
      children: [
        // Top Active Editor Section if video is active
        Obx(() {
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
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        onPressed: () => controller.selectVideo(null),
                      ),
                      Expanded(
                        child: Text(
                          'Back to Video Scope',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderColor),
                _buildEditorWorkspace(
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                ),
              ],
            );
          }

          // Otherwise show scrollable catalog
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Channel Content',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final list = controller.filteredVideos;
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final video = list[index];
                        return ListTile(
                          leading: CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            width: 60,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                          title: Text(
                            video.title,
                            maxLines: 1,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            video.duration,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                          onTap: () => controller.selectVideo(video),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptySelectionState(Color textColor, Color textSecondaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 48,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a Video to Load Multi-Language Audio Scope',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an uploaded file from the left sidebar to assign localized base and dub voiceovers.',
            style: GoogleFonts.roboto(fontSize: 14, color: textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorWorkspace(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    final video = controller.selectedVideo.value!;

    return Column(
      children: [
        // Workspace Top Bar: Context & Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
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
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Unsaved state warning tag
                        Obx(() {
                          if (!controller.hasUnsavedChanges.value) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Unsaved',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    Text(
                      'Multi-Language Dubbed Voiceover Track Workspace',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Commit Synchronization Button
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
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    controller.isSaving.value ? 'Saving...' : 'Save Changes',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                );
              }),
            ],
          ),
        ),

        // Multitrack Ribbon Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Text(
                'Assigned Targets:',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() {
                  final activeCode = controller.selectedLanguage.value;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: controller.availableLanguages.map((langCode) {
                        final isChosen = langCode == activeCode;
                        final name = controller.getLanguageName(langCode);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(name),
                            selected: isChosen,
                            onSelected: (_) =>
                                controller.switchLanguageTrack(langCode),
                            selectedColor: AppColors.brand,
                            labelStyle: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isChosen ? Colors.white : textColor,
                            ),
                            backgroundColor: widget.isDarkMode
                                ? const Color(0xFF262626)
                                : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide.none,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ),

              // View Requests Action
              Obx(() => Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mark_chat_read_outlined),
                    color: AppColors.brand,
                    tooltip: 'View Language Requests',
                    onPressed: () => controller.showLanguageRequestsDialog(context),
                  ),
                  if (controller.languageRequests.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${controller.languageRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              )),

              // Add Track Layer Popup
              PopupMenuButton<String>(
                tooltip: 'Provision alternate audio layer',
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.brand,
                  ),
                ),
                color: surfaceColor,
                onSelected: (code) => controller.addLanguageLayer(code),
                itemBuilder: (context) {
                  return controller.supportedLanguages.map((lang) {
                    final isAlreadyAssigned = controller.availableLanguages
                        .contains(lang.code);
                    return PopupMenuItem<String>(
                      value: lang.code,
                      enabled: !isAlreadyAssigned,
                      child: Row(
                        children: [
                          Icon(
                            Icons.audiotrack_rounded,
                            size: 16,
                            color: isAlreadyAssigned
                                ? textSecondaryColor
                                : textColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lang.name,
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              color: isAlreadyAssigned
                                  ? textSecondaryColor
                                  : textColor,
                              decoration: isAlreadyAssigned
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ],
          ),
        ),

        // Live Audio Configuration Panels
        Expanded(
          child: Obx(() {
            if (controller.isLoadingTracks.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final list = controller.currentTracks;
            if (list.isEmpty) {
              return Center(
                child: Text(
                  'No valid audio track stream parameters available for this region.',
                  style: GoogleFonts.roboto(
                    color: textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final track = list[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
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
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.1)
                                  : const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              track.isBaseTrack
                                  ? Icons.volume_up_rounded
                                  : Icons.spatial_audio_rounded,
                              size: 18,
                              color: track.isBaseTrack
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF8B5CF6),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: track.isBaseTrack
                                            ? const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.15)
                                            : const Color(
                                                0xFF8B5CF6,
                                              ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        track.isBaseTrack
                                            ? 'Primary Audio'
                                            : 'Secondary Dub',
                                        style: GoogleFonts.roboto(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: track.isBaseTrack
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF8B5CF6),
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
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Direct export copy action
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            color: textSecondaryColor,
                            tooltip: 'Copy Audio URI to clipboard',
                            onPressed: () => controller
                                .exportTrackLinkToClipboard(track.audioUrl),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 16),

                      // Stream string URL field bound with strict ValueKey support
                      Text(
                        'Storage Stream URL Reference:',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: ValueKey(
                          '${controller.selectedLanguage.value}_${track.id}',
                        ),
                        initialValue: track.audioUrl,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Provide direct HTTPS audio target file URI e.g. gs://...',
                          hintStyle: GoogleFonts.roboto(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: widget.isDarkMode
                              ? const Color(0xFF1E1E1E)
                              : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) =>
                            controller.updateTrackUrl(index, val),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  int entireListUniqueTrackCounter(Map<String, String> map) {
    final keys = map.keys.toList();
    if (!keys.contains('en')) return keys.length + 1;
    return keys.length;
  }
}





