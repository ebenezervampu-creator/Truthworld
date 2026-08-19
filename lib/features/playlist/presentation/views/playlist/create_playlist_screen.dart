import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({
    super.key,
    this.initialVideoId,
  });

  final String? initialVideoId;

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _playlistController = Get.find<PlaylistController>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  
  bool _isPublic = true;
  final List<Video> _selectedVideos = [];
  int _selectedThumbnailIndex = 0;
  
  Uint8List? _customImageBytes;
  String? _customImageName;
  bool _useCustomThumbnail = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialVideo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialVideo() async {
    if (widget.initialVideoId != null && widget.initialVideoId!.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(widget.initialVideoId)
            .get();
        if (doc.exists) {
          setState(() {
            _selectedVideos.add(Video.fromDocumentSnapshot(doc));
          });
        }
      } catch (e) {
        debugPrint('Error loading initial video: $e');
      }
    }
  }

  Future<void> _pickCustomImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _customImageBytes = file.bytes;
          _customImageName = file.name;
          _useCustomThumbnail = true;
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  void _openVideoSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _VideoSelectorSheet(
          currentlySelected: List.from(_selectedVideos),
          onConfirm: (selected) {
            setState(() {
              _selectedVideos.clear();
              _selectedVideos.addAll(selected);
              if (_selectedThumbnailIndex >= _selectedVideos.length) {
                _selectedThumbnailIndex = 0;
              }
            });
          },
        );
      },
    );
  }

  Future<void> _submitCreatePlaylist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Required', 'Please enter a playlist name');
      return;
    }

    final nameVal = ContentValidator.validate(name, fieldName: 'Playlist Name');
    if (!nameVal.isValid) {
      Get.snackbar(
        'Inappropriate Content',
        nameVal.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final description = _descController.text.trim();
    if (description.isNotEmpty) {
      final descVal = ContentValidator.validate(
        description,
        fieldName: 'Playlist Description',
      );
      if (!descVal.isValid) {
        Get.snackbar(
          'Inappropriate Content',
          descVal.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      final String customThumbnailUrl;
      if (!_useCustomThumbnail && _selectedVideos.isNotEmpty) {
        if (_selectedThumbnailIndex < _selectedVideos.length) {
          customThumbnailUrl = _selectedVideos[_selectedThumbnailIndex].thumbnailUrl;
        } else {
          customThumbnailUrl = '';
        }
      } else {
        customThumbnailUrl = '';
      }

      final videoIds = _selectedVideos.map((v) => v.id).toList();

      final created = await _playlistController.createPlayList(
        name,
        isPublic: _isPublic,
        videoIds: videoIds,
        description: description,
        customThumbnailUrl: customThumbnailUrl,
      );

      if (created != null) {
        Get.back();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to create playlist');
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
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
            if (isDesktop) _buildDesktopTopHeader(context),
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

  // ================= Top Desktop Bar =================
  Widget _buildDesktopTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TRUTHWORLD',
                style: context.themeTypography.logo.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),

          // Search Bar
          Expanded(
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 540),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search videos, channels, topics...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Right Icons
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF333333),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ],
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
              onPressed: () => Get.back(),
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
                controller: _nameController,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
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
                child: Text(
                  '${_nameController.text.length}/100',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
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
                controller: _descController,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
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
                child: Text(
                  '${_descController.text.length}/500',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
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
          InkWell(
            onTap: () => setState(() => _isPublic = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPublic
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  width: _isPublic ? 1.5 : 1,
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
                        color: _isPublic
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: _isPublic
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
          ),
          const SizedBox(height: 12),

          // Private Option
          InkWell(
            onTap: () => setState(() => _isPublic = false),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_isPublic
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  width: !_isPublic ? 1.5 : 1,
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
                        color: !_isPublic
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: !_isPublic
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
          ),
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
                onPressed: _openVideoSelectorModal,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedVideos.length} videos selected',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_selectedVideos.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedVideos.clear();
                    });
                  },
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
          ),
          const SizedBox(height: 12),

          // Videos Reorderable List
          if (_selectedVideos.isEmpty)
            Container(
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
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedVideos.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _selectedVideos.removeAt(oldIndex);
                  _selectedVideos.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final video = _selectedVideos[index];
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
                              errorWidget: (context, url, error) => Container(
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
                        onPressed: () {
                          setState(() {
                            _selectedVideos.removeAt(index);
                          });
                        },
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

          if (_selectedVideos.isNotEmpty) ...[
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
                child: InkWell(
                  onTap: () => setState(() => _useCustomThumbnail = false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_useCustomThumbnail
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                        width: !_useCustomThumbnail ? 1.5 : 1,
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
                                  color: !_useCustomThumbnail
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: !_useCustomThumbnail
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
                        if (_selectedVideos.isEmpty)
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
                              itemCount: _selectedVideos.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final isSelected =
                                    !_useCustomThumbnail && _selectedThumbnailIndex == i;
                                final v = _selectedVideos[i];

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _useCustomThumbnail = false;
                                      _selectedThumbnailIndex = i;
                                    });
                                  },
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
                ),
              ),
              if (!isDesktop) const SizedBox(height: 12) else const SizedBox(width: 16),

              // Option 2: Upload Custom Image
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: InkWell(
                  onTap: () {
                    setState(() => _useCustomThumbnail = true);
                    _pickCustomImage();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _useCustomThumbnail
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                        width: _useCustomThumbnail ? 1.5 : 1,
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
                                  color: _useCustomThumbnail
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: _useCustomThumbnail
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
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (_customImageBytes != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    _customImageBytes!,
                                    height: 50,
                                    width: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _customImageName ?? 'Custom Image',
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= Desktop Actions =================
  Widget _buildDesktopFooterActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Get.back(),
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
          onPressed: _isCreating ? null : _submitCreatePlaylist,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isCreating
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
  }

  // ================= Mobile Sticky Footer =================
  Widget _buildMobileStickyFooter(BuildContext context) {
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
          onPressed: _isCreating ? null : _submitCreatePlaylist,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isCreating
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
  }
}

// ================= Modal Sheet to Select Videos =================
class _VideoSelectorSheet extends StatefulWidget {
  const _VideoSelectorSheet({
    required this.currentlySelected,
    required this.onConfirm,
  });

  final List<Video> currentlySelected;
  final ValueChanged<List<Video>> onConfirm;

  @override
  State<_VideoSelectorSheet> createState() => _VideoSelectorSheetState();
}

class _VideoSelectorSheetState extends State<_VideoSelectorSheet> {
  late List<Video> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.currentlySelected);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser?.uid ?? '';

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
              ElevatedButton(
                onPressed: () {
                  widget.onConfirm(_selected);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search videos...',
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              fillColor: const Color(0xFF161618),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.videos)
                  .where('ownerId', isEqualTo: currentUser)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No videos found',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }

                final videos = snapshot.data!.docs
                    .map(Video.fromDocumentSnapshot)
                    .where((v) =>
                        _searchQuery.isEmpty ||
                        v.title.toLowerCase().contains(_searchQuery))
                    .toList();

                return ListView.separated(
                  itemCount: videos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isChecked = _selected.any((v) => v.id == video.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selected.add(video);
                            } else {
                              _selected.removeWhere((v) => v.id == video.id);
                            }
                          });
                        },
                        secondary: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            width: 60,
                            height: 36,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 60,
                              height: 36,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        title: Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          video.duration,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
