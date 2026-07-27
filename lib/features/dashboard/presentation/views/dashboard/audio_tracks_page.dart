import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
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
              color: AppColors.brand,
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
                      color: AppColors.brand,
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
                                                        .toDate() as DateTime,
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
                                              color: AppColors.brand.withValues(alpha: 0.15),
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
                  final trackCount = audioMap.isEmpty ? 1 : entireListUniqueTrackCounter(audioMap);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            icon: const Icon(Icons.cloud_upload_rounded, size: 14),
                            label: const Text('Upload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Obx(() {
                          final showRequests = controller.showRequestsPanel.value;
                          final audioReqCount = controller.languageRequests.where((r) => r.type == 'audio').length;
                          return OutlinedButton.icon(
                            onPressed: () => controller.toggleRequestsPanel(),
                            icon: Icon(
                              showRequests ? Icons.close_rounded : Icons.mark_chat_unread_rounded,
                              size: 14,
                              color: showRequests ? AppColors.error : AppColors.brand,
                            ),
                            label: Text(
                              showRequests ? 'Tracks' : 'Requests ($audioReqCount)',
                              style: TextStyle(
                                fontSize: 12,
                                color: showRequests ? AppColors.error : AppColors.brand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(alpha: 0.3),
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
                      final hasReqs = controller.languageRequests.where((r) => r.type == 'audio').isNotEmpty;
                      final showRequests = controller.showRequestsPanel.value;
                      return Badge(
                        isLabelVisible: hasReqs && !showRequests,
                        label: Text('${controller.languageRequests.where((r) => r.type == 'audio').length}'),
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
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: showRequests ? AppColors.error : AppColors.brand,
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
                          controller.isSaving.value ? 'Saving...' : 'Save Changes',
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

        // Multitrack Ribbon Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Text(
                'Languages:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(width: 10),
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
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isChosen ? AppColors.textPrimary : textColor,
                            ),
                            backgroundColor: widget.isDarkMode
                                ? const Color(0xFF262626)
                                : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ),

              // Add Track Layer Popup
              PopupMenuButton<String>(
                tooltip: 'Provision alternate audio layer',
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
                            style: TextStyle(
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
            final showRequests = controller.showRequestsPanel.value;

            if (isMobile) {
              if (showRequests) {
                return _buildRequestsPanel(surfaceColor, textColor, textSecondaryColor, borderColor, isMobile: true);
              } else {
                return _buildTracksList(surfaceColor, textColor, textSecondaryColor, borderColor);
              }
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildTracksList(surfaceColor, textColor, textSecondaryColor, borderColor),
                ),
                if (showRequests)
                  _buildRequestsPanel(surfaceColor, textColor, textSecondaryColor, borderColor, isMobile: false),
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
        return const Center(child: CircularProgressIndicator(color: AppColors.brand));
      }

      final list = controller.currentTracks;
      if (list.isEmpty) {
        return Center(
          child: Text(
            'No audio tracks configured for this language.',
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 13,
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final track = list[index];

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
                        color: track.isBaseTrack ? AppColors.success : AppColors.brand,
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
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  track.isBaseTrack ? 'Primary Audio' : 'Secondary Dub',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: track.isBaseTrack ? AppColors.success : AppColors.brand,
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
                      color: AppColors.brand,
                      tooltip: 'Copy Audio URI to clipboard',
                      onPressed: () => controller.exportTrackLinkToClipboard(track.audioUrl),
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
                  key: ValueKey('${controller.selectedLanguage.value}_${track.id}'),
                  initialValue: track.audioUrl,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Provide direct HTTPS audio target file URI e.g. gs://...',
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
        },
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
        border: Border(left: isMobile ? BorderSide.none : BorderSide(color: borderColor)),
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
                  color: AppColors.brand,
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
                  final reqs = controller.languageRequests.where((r) => r.type == 'audio').toList();
                  if (reqs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              final reqs = controller.languageRequests.where((r) => r.type == 'audio').toList();
              if (controller.isLoadingRequests.value) {
                return const Center(child: CircularProgressIndicator(color: AppColors.brand));
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
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = reqs[index];
                  final matchingLanguage = supportedLanguages.firstWhereOrNull(
                    (l) => l.name.toLowerCase() == r.language.toLowerCase(),
                  );
                  final langCode = matchingLanguage?.code ?? r.language;
                  final isAlreadyAdded = controller.availableLanguages.contains(langCode);

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
                                      matchingLanguage.nativeName,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_rounded,
                                    size: 12,
                                    color: AppColors.brand,
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
                                  icon: const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                  label: const Text('Provisioned'),
                                  style: OutlinedButton.styleFrom(
                                    disabledForegroundColor: AppColors.success,
                                    side: const BorderSide(color: AppColors.success),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    controller.addLanguageLayer(langCode);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 14),
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

  int entireListUniqueTrackCounter(Map<String, String> map) {
    final keys = map.keys.toList();
    if (!keys.contains('en')) return keys.length + 1;
    return keys.length;
  }

  void _showUploadTrackDialog(BuildContext context) {
    final titleController = TextEditingController();
    final selectedLangCode = 'en'.obs;
    final selectedType = 'Audio'.obs;
    final pickedFile = Rx<PlatformFile?>(null);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.bgDivider,
              ),
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
                        const Text(
                          'Upload Alternate Track',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!isUploading)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Track Title / Language Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., Spanish Dub, French Commentary',
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Language',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.bgInput,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedLangCode.value,
                                    isExpanded: true,
                                    dropdownColor: AppColors.bgSurface,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    items: controller.supportedLanguages.map((lang) {
                                      return DropdownMenuItem<String>(
                                        value: lang.code,
                                        child: Text(lang.name),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        selectedLangCode.value = val;
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Track Type',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.bgInput,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedType.value,
                                    isExpanded: true,
                                    dropdownColor: AppColors.bgSurface,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Audio', child: Text('Audio (Voiceover)')),
                                      DropdownMenuItem(value: 'Video', child: Text('Video (Dubbed)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        selectedType.value = val;
                                        pickedFile.value = null;
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Select File',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final extensions = selectedType.value == 'Audio'
                            ? ['mp3', 'wav', 'm4a', 'aac']
                            : ['mp4', 'mov', 'avi', 'mkv'];
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: extensions,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          pickedFile.value = result.files.first;
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.bgDivider,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedType.value == 'Audio' ? Icons.audiotrack : Icons.video_collection,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pickedFile.value?.name ?? 'No file selected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: pickedFile.value != null
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ),
                            if (pickedFile.value != null)
                              Text(
                                '${(pickedFile.value!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                                color: AppColors.brand,
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
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (!isUploading)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (pickedFile.value == null || titleController.text.trim().isEmpty)
                                ? null
                                : () async {
                                    final success = await controller.uploadTrackFile(
                                      file: pickedFile.value!,
                                      title: titleController.text,
                                      langCode: selectedLangCode.value,
                                      type: selectedType.value,
                                    );
                                    if (success && context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.textPrimary,
                              disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                              disabledForegroundColor: AppColors.textSecondary,
                            ),
                            child: const Text('Upload'),
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
    );
  }
}
