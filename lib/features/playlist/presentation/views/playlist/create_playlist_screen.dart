import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

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
        return _VideoSelectorSheet(
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
                        _buildPageHeader(context, isDesktop),
                        const SizedBox(height: 24),
                        if (isDesktop)
                          _buildDesktopTwoColumnLayout(context)
                        else
                          _buildMobileSingleColumnLayout(context),
                        const SizedBox(height: 24),
                        _buildSection5Thumbnail(context, isDesktop),
                        const SizedBox(height: 32),
                        if (isDesktop) _buildDesktopFooterActions(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isDesktop) _buildMobileStickyFooter(context),
          ],
        ),
      ),
    );
  }

  // ================= Page Header =================
  Widget _buildPageHeader(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Text(
              'Create Playlist',
              style: context.themeTypography.display.copyWith(
                fontSize: isDesktop ? 26 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            'Organize videos into a playlist and share with your audience.',
            style: context.themeTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
      ],
    );
  }

  // ================= Desktop 2-Column Layout =================
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
              _buildSection1Name(context),
              const SizedBox(height: 24),
              _buildSection2Description(context),
              const SizedBox(height: 24),
              _buildSection3Visibility(context),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right Column (Step 4)
        Expanded(
          flex: 6,
          child: _buildSection4AddVideos(context, isDesktop: true),
        ),
      ],
    );
  }

  // ================= Mobile Single Column Layout =================
  Widget _buildMobileSingleColumnLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection1Name(context),
        const SizedBox(height: 20),
        _buildSection2Description(context),
        const SizedBox(height: 20),
        _buildSection3Visibility(context),
        const SizedBox(height: 20),
        _buildSection4AddVideos(context, isDesktop: false),
      ],
    );
  }

  // ================= Step 1: Playlist Name =================
  Widget _buildSection1Name(BuildContext context) {
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
                '1. Playlist Name',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: _c.nameController,
                maxLength: 100,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter playlist name',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  counterText: '',
                  fillColor: const Color(0xFF0F0F11),
                  filled: true,
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 60, 14),
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
              ),
              Positioned(
                right: 14,
                child: Obx(
                  () => Text(
                    '${_c.nameLength.value}/100',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Give your playlist a clear and catchy name.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Step 2: Description =================
  Widget _buildSection2Description(BuildContext context) {
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
          Text(
            '2. Description (Optional)',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              TextField(
                controller: _c.descController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Describe your playlist',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  counterText: '',
                  fillColor: const Color(0xFF0F0F11),
                  filled: true,
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
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
              ),
              Positioned(
                right: 14,
                bottom: 10,
                child: Obx(
                  () => Text(
                    '${_c.descLength.value}/500',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tell viewers what your playlist is about.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Step 3: Playlist Type =================
  Widget _buildSection3Visibility(BuildContext context) {
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
          Text(
            '3. Playlist Type',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose who can view this playlist',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Public Option
          Obx(() {
            final isPub = _c.isPublic.value;
            return InkWell(
              onTap: () => _c.setPublic(true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPub
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                    width: isPub ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Public',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Anyone can view this playlist',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPub
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: isPub
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Private Option
          Obx(() {
            final isPriv = !_c.isPublic.value;
            return InkWell(
              onTap: () => _c.setPublic(false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPriv
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                    width: isPriv ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Private',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Only you can view this playlist',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPriv
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: isPriv
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ================= Step 4: Add Videos =================
  Widget _buildSection4AddVideos(BuildContext context, {required bool isDesktop}) {
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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4. Add Videos',
                    style: context.themeTypography.title.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select videos to add to your playlist',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _openVideoSelectorModal(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text(
                  'Select videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Count & Clear row
          Obx(() {
            final videos = _c.selectedVideos;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${videos.length} videos selected',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (videos.isNotEmpty)
                  TextButton.icon(
                    onPressed: _c.clearSelectedVideos,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      'Clear all',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 12),

          // Videos Reorderable List
          Obx(() {
            final videos = _c.selectedVideos;
            if (videos.isEmpty) {
              return Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No videos selected yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: videos.length,
                  onReorder: _c.reorderVideos,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return Container(
                      key: ValueKey(video.id),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Drag Icon
                          const Icon(
                            Icons.drag_indicator,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),

                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: video.thumbnailUrl,
                                  width: 80,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 80,
                                    height: 48,
                                    color: const Color(0xFF252528),
                                    child: const Icon(
                                      Icons.movie,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      video.duration,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title
                          Expanded(
                            child: Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Delete X Icon
                          IconButton(
                            onPressed: () => _c.removeVideoAt(index),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Drag and drop to reorder videos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ================= Step 5: Playlist Thumbnail =================
  Widget _buildSection5Thumbnail(BuildContext context, bool isDesktop) {
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
          Text(
            '5. Playlist Thumbnail',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a thumbnail for your playlist',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Option 1: Selected Video Thumbnail
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Obx(() {
                  final useCustom = _c.useCustomThumbnail.value;
                  final selectedIdx = _c.selectedThumbnailIndex.value;
                  final videos = _c.selectedVideos;

                  return InkWell(
                    onTap: () => _c.setUseCustomThumbnail(false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !useCustom
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.1),
                          width: !useCustom ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: !useCustom
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: !useCustom
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Use thumbnail from selected video',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              'Choose from your selected videos',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // List of video thumbnails
                          if (videos.isEmpty)
                            Text(
                              'Select videos first',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: videos.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final isSelected =
                                      !useCustom && selectedIdx == i;
                                  final v = videos[i];

                                  return GestureDetector(
                                    onTap: () =>
                                        _c.setSelectedThumbnailIndex(i),
                                    child: Container(
                                      width: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: v.thumbnailUrl,
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              right: 4,
                                              bottom: 4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 3,
                                                  vertical: 1,
                                                ),
                                                color: Colors.black.withValues(
                                                  alpha: 0.8,
                                                ),
                                                child: Text(
                                                  v.duration,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              if (!isDesktop)
                const SizedBox(height: 12)
              else
                const SizedBox(width: 16),

              // Option 2: Upload Custom Image
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Obx(() {
                  final useCustom = _c.useCustomThumbnail.value;
                  final customBytes = _c.customImageBytes.value;
                  final customName = _c.customImageName.value;

                  return InkWell(
                    onTap: () {
                      _c.setUseCustomThumbnail(true);
                      _c.pickCustomImage();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: useCustom
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.1),
                          width: useCustom ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: useCustom
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: useCustom
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Upload custom image',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              'Pick an image from your device',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Dropzone / Upload Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                if (customBytes != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      customBytes,
                                      height: 50,
                                      width: 90,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    customName ?? 'Custom Image',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.file_upload_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Upload image',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'PNG, JPG or WEBP. Max 5MB.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= Desktop Actions =================
  Widget _buildDesktopFooterActions(BuildContext context) {
    return Obx(() {
      final isCreating = _c.isCreating.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: Get.back,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: isCreating ? null : () => _handleCreatePlaylist(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create Playlist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      );
    });
  }

  // ================= Mobile Sticky Footer =================
  Widget _buildMobileStickyFooter(BuildContext context) {
    return Obx(() {
      final isCreating = _c.isCreating.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isCreating ? null : () => _handleCreatePlaylist(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isCreating
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
                    'Create Playlist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      );
    });
  }
}

class _VideoSelectorSheet extends StatelessWidget {
  _VideoSelectorSheet({
    required this.currentlySelected,
    required this.onConfirm,
  }) {
    _selectedVideos.assignAll(currentlySelected);
    _fetchUserVideos();
  }

  final List<Video> currentlySelected;
  final ValueChanged<List<Video>> onConfirm;

  final RxList<Video> _selectedVideos = <Video>[].obs;
  final RxList<Video> _allVideos = <Video>[].obs;
  final RxBool _isLoading = true.obs;
  final RxString _searchQuery = ''.obs;

  Future<void> _fetchUserVideos() async {
    _isLoading.value = true;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final userChannelId = Get.isRegistered<AuthService>()
          ? (AuthService.to.userChannel?.id ?? '')
          : '';

      final targetIds = <String>{};
      if (currentUid.isNotEmpty) targetIds.add(currentUid);
      if (userChannelId.isNotEmpty) targetIds.add(userChannelId);

      final videos = <Video>[];
      final seenIds = <String>{};

      void addVideoDocs(Iterable<QueryDocumentSnapshot> docs) {
        for (final doc in docs) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            try {
              final video = Video.fromDocumentSnapshot(doc);
              videos.add(video);
            } catch (e) {
              debugPrint('Error parsing video ${doc.id}: $e');
            }
          }
        }
      }

      for (final id in targetIds) {
        try {
          final q1 = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: id)
              .get();
          addVideoDocs(q1.docs);
        } catch (_) {}

        try {
          final q2 = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: id)
              .get();
          addVideoDocs(q2.docs);
        } catch (_) {}

        try {
          final q3 = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: id)
              .get();
          addVideoDocs(q3.docs);
        } catch (_) {}

        try {
          final qSub = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .doc(id)
              .collection(FirestoreCollections.videos)
              .get();
          addVideoDocs(qSub.docs);
        } catch (_) {}
      }

      // Sort newest videos first
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _allVideos.assignAll(videos);
    } catch (e) {
      debugPrint('Error fetching user videos for playlist: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Videos',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Row(
                children: [
                  Obx(() {
                    if (_allVideos.isEmpty) return const SizedBox.shrink();
                    final allSelected = _selectedVideos.length == _allVideos.length;
                    return TextButton(
                      onPressed: () {
                        if (allSelected) {
                          _selectedVideos.clear();
                        } else {
                          _selectedVideos.assignAll(_allVideos);
                        }
                      },
                      child: Text(
                        allSelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      onConfirm(_selectedVideos.toList());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Obx(() {
                      return Text(
                        'Done (${_selectedVideos.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => _searchQuery.value = val.trim().toLowerCase(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search videos...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              fillColor: const Color(0xFF161618),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final query = _searchQuery.value;
              final displayVideos = query.isEmpty
                  ? _allVideos
                  : _allVideos
                      .where((v) =>
                          v.title.toLowerCase().contains(query) ||
                          v.description.toLowerCase().contains(query))
                      .toList();

              if (displayVideos.isEmpty) {
                return const Center(
                  child: Text(
                    'No videos found in your channel',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: displayVideos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final video = displayVideos[index];
                  return Obx(() {
                    final isChecked =
                        _selectedVideos.any((v) => v.id == video.id);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isChecked) {
                            _selectedVideos
                                .removeWhere((v) => v.id == video.id);
                          } else {
                            _selectedVideos.add(video);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? const Color(0xFF222226)
                                : const Color(0xFF161618),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChecked
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isChecked ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: video.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        width: 60,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          width: 60,
                                          height: 36,
                                          color: Colors.grey[800],
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 36,
                                        color: Colors.grey[800],
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      video.duration.isNotEmpty
                                          ? video.duration
                                          : '${video.views} views',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? const Color(0xFF27272A)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isChecked
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: isChecked
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
