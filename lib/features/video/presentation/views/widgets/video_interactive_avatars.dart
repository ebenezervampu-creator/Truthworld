import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// ROTATING PLAYLIST AVATAR WIDGET
// ==========================================================================
class RotatingPlaylistAvatar extends StatefulWidget {
  final PlaylistModel playlist;
  final bool isPlaying;
  final VoidCallback? onTap;
  final double size;

  const RotatingPlaylistAvatar({
    required this.playlist,
    super.key,
    this.isPlaying = true,
    this.onTap,
    this.size = 52.0,
  });

  @override
  State<RotatingPlaylistAvatar> createState() => _RotatingPlaylistAvatarState();
}

class _RotatingPlaylistAvatarState extends State<RotatingPlaylistAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingPlaylistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        // Rotating vinyl disc / circular avatar
        RotationTransition(
          turns: _rotationController,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF1F2937),
                  Color(0xFF111827),
                  Color(0xFF374151),
                  Color(0xFF111827),
                  Color(0xFF1F2937),
                ],
              ),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: widget.playlist.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _buildFallback(),
                        errorWidget: (_, _, _) => _buildFallback(),
                      )
                    : _buildFallback(),
              ),
            ),
          ),
        ),
        // Center spindle dot for vinyl record styling
        Positioned.fill(
          child: Center(
            child: Container(
              width: widget.size * 0.22,
              height: widget.size * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.85),
                border: Border.all(color: Colors.white60),
              ),
            ),
          ),
        ),
        // Playing equalizer badge at bottom right corner
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4,
                ),
              ],
            ),
            child: PlayingAudioWaveAnimation(
              isPlaying: widget.isPlaying,
              height: 10,
              barWidth: 2,
            ),
          ),
        ),
      ],
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(
        Icons.playlist_play_rounded,
        color: Colors.white70,
        size: 24,
      ),
    );
  }
}

// ==========================================================================
// PLAYING AUDIO WAVE ANIMATION WIDGET
// ==========================================================================
class PlayingAudioWaveAnimation extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final double barWidth;
  final Color color;

  const PlayingAudioWaveAnimation({
    super.key,
    this.isPlaying = true,
    this.height = 14,
    this.barWidth = 2.5,
    this.color = AppColors.brand,
  });

  @override
  State<PlayingAudioWaveAnimation> createState() =>
      _PlayingAudioWaveAnimationState();
}

class _PlayingAudioWaveAnimationState extends State<PlayingAudioWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PlayingAudioWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animController.repeat(reverse: true);
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final t = _animController.value;
        final h1 = widget.height * (0.3 + 0.7 * (0.5 + 0.5 * (t * 3.14).abs()));
        final h2 =
            widget.height * (0.4 + 0.6 * (0.5 + 0.5 * ((1 - t) * 3.14).abs()));
        final h3 =
            widget.height *
            (0.2 + 0.8 * (0.5 + 0.5 * ((t + 0.5) * 3.14).abs()));

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(widget.isPlaying ? h1 : widget.height * 0.4),
              SizedBox(width: widget.barWidth),
              _buildBar(widget.isPlaying ? h2 : widget.height * 0.7),
              SizedBox(width: widget.barWidth),
              _buildBar(widget.isPlaying ? h3 : widget.height * 0.3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double barHeight) {
    return Container(
      width: widget.barWidth,
      height: barHeight.clamp(2.0, widget.height),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ==========================================================================
// ROTATING TOPIC AVATAR WIDGET
// ==========================================================================
class RotatingTopicAvatar extends StatefulWidget {
  final Topic topic;
  final bool isPlaying;
  final VoidCallback? onTap;
  final double size;

  const RotatingTopicAvatar({
    required this.topic,
    super.key,
    this.isPlaying = true,
    this.onTap,
    this.size = 52.0,
  });

  @override
  State<RotatingTopicAvatar> createState() => _RotatingTopicAvatarState();
}

class _RotatingTopicAvatarState extends State<RotatingTopicAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingTopicAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.topic.thumbnailUrl ?? widget.topic.coverImage ?? '';

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rotating vinyl disc / circular avatar
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF1D4ED8),
                    Color(0xFF8B5CF6),
                    Color(0xFF1D4ED8),
                    Color(0xFF3B82F6),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF60A5FA),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _buildFallback(),
                          errorWidget: (_, _, _) => _buildFallback(),
                        )
                      : _buildFallback(),
                ),
              ),
            ),
          ),
          // Center spindle dot for vinyl record styling
          Positioned.fill(
            child: Center(
              child: Container(
                width: widget.size * 0.22,
                height: widget.size * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.85),
                  border: Border.all(color: Colors.white60),
                ),
              ),
            ),
          ),
          // Playing equalizer badge at bottom right corner
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: PlayingAudioWaveAnimation(
                isPlaying: widget.isPlaying,
                height: 10,
                barWidth: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Text(
          '#',
          style: TextStyle(
            color: Color(0xFF60A5FA),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// TOPIC VIDEOS BOTTOM SHEET / POPUP
// ==========================================================================
class TopicVideosBottomSheet extends StatelessWidget {
  final Topic topic;
  final String? videoTag;

  TopicVideosBottomSheet({
    required this.topic,
    super.key,
    this.videoTag,
  }) {
    _loadTopicVideos();
  }

  final RxString _selectedFilter = 'All'.obs;
  final RxList<Video> _allVideos = <Video>[].obs;
  final RxBool _isLoading = true.obs;

  final List<String> _filters = [
    'All',
    'From subscribed channels',
    'New',
    'Trending',
    'Popular',
    'Fact checked',
  ];

  VideoController? get _videoController {
    try {
      if (videoTag != null &&
          Get.isRegistered<VideoController>(tag: videoTag)) {
        return Get.find<VideoController>(tag: videoTag);
      }
      if (Get.isRegistered<VideoController>()) {
        return Get.find<VideoController>();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoInteractiveAvatars.getVideoController',
      );
    }
    return null;
  }

  Future<void> _loadTopicVideos() async {
    try {
      final slug = topic.slug;
      final topicId = topic.id;

      // 1. Query by topic slug
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .where('topics', arrayContains: slug.isNotEmpty ? slug : topicId)
          .limit(30)
          .get();

      var fetched = snap.docs.map(Video.fromDocumentSnapshot).toList();

      // 2. If empty and featuredVideoIds present, fetch by IDs
      if (fetched.isEmpty && topic.featuredVideoIds.isNotEmpty) {
        final ids = topic.featuredVideoIds.take(10).toList();
        final snapIds = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: ids)
            .get();
        fetched = snapIds.docs.map(Video.fromDocumentSnapshot).toList();
      }

      // 3. Fallback to broad query
      if (fetched.isEmpty) {
        final snapFallback = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .limit(30)
            .get();
        fetched = snapFallback.docs
            .map(Video.fromDocumentSnapshot)
            .where(
              (v) =>
                  v.topics.any((t) => t.toLowerCase() == slug.toLowerCase()) ||
                  v.tags.any(
                    (t) => t.toLowerCase() == topic.title.toLowerCase(),
                  ) ||
                  v.category.toLowerCase() == topic.title.toLowerCase(),
            )
            .toList();
        if (fetched.isEmpty && snapFallback.docs.isNotEmpty) {
          fetched = snapFallback.docs.map(Video.fromDocumentSnapshot).toList();
        }
      }

      _allVideos.assignAll(fetched);
      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
    }
  }

  List<Video> get _filteredVideos {
    final videoController = _videoController;
    final currentVideo = videoController?.video;
    final filter = _selectedFilter.value;
    final all = _allVideos;

    switch (filter) {
      case 'From subscribed channels':
        if (videoController == null || currentVideo == null) return all;
        return all.where((v) {
          return videoController.channelController.isSubscribed.value &&
              v.channelId == currentVideo.channelId;
        }).toList();
      case 'New':
        final list = List<Video>.from(_allVideos);
        list.sort(
          (a, b) =>
              _getDateTime(b.createdAt).compareTo(_getDateTime(a.createdAt)),
        );
        return list;
      case 'Trending':
        final list = List<Video>.from(_allVideos);
        list.sort((a, b) => b.views.compareTo(a.views));
        return list;
      case 'Popular':
        final list = List<Video>.from(_allVideos);
        list.sort((a, b) => b.likes.compareTo(a.likes));
        return list;
      case 'Fact checked':
        final factChecked = _allVideos
            .where((v) => v.isFactChecked)
            .toList();
        return factChecked.isNotEmpty ? factChecked : _allVideos;
      case 'All':
      default:
        return _allVideos;
    }
  }

  DateTime _getDateTime(dynamic date) {
    if (date is DateTime) return date;
    if (date is Timestamp) return date.toDate();
    return DateTime(2000);
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '$views';
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is Timestamp) {
      dt = date.toDate();
    }
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()} years ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays >= 1) return '${diff.inDays} days ago';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Drag indicator handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Obx(() => Text(
                        '${_allVideos.length} topic videos',
                        style: GoogleFonts.roboto(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Filter pills bar
          Obx(() {
            final activeFilter = _selectedFilter.value;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: GoogleFonts.roboto(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _selectedFilter.value = filter;
                        }
                      },
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      selectedColor: const Color(0xFF3B82F6),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),

          const Divider(color: Colors.white10, height: 1),

          // Video list
          Expanded(
            child: Obx(() {
              final loading = _isLoading.value;
              final filtered = _filteredVideos;
              final activeFilter = _selectedFilter.value;
              final controller = _videoController;
              final currentVideoId = controller?.video.id;

              if (loading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF3B82F6),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No videos found for "$activeFilter"',
                    style: GoogleFonts.roboto(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final video = filtered[index];
                  final isCurrent = video.id == currentVideoId;

                  return Material(
                    color: isCurrent
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Get.offNamed(
                          '/watch?v=${video.id}',
                          arguments: {
                            'video': video,
                            'topic': topic,
                            'fromTopic': true,
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: video.thumbnailUrl,
                                    width: 120,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 240,
                                    placeholder: (_, _) => Container(
                                      width: 120,
                                      height: 68,
                                      color: Colors.grey[900],
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      width: 120,
                                      height: 68,
                                      color: Colors.grey[900],
                                      child: const Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                  if (video.duration.isNotEmpty)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.8,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          video.duration,
                                          style: GoogleFonts.roboto(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          video.title,
                                          style: GoogleFonts.roboto(
                                            color: isCurrent
                                                ? const Color(0xFF3B82F6)
                                                : Colors.white,
                                            fontSize: 13,
                                            fontWeight: isCurrent
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 6),
                                        Obx(() => PlayingAudioWaveAnimation(
                                          isPlaying: controller?.isPlayingRx.value ?? false,
                                          height: 12,
                                          barWidth: 2,
                                          color: const Color(0xFF3B82F6),
                                        )),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${video.channelName} • ${_formatViews(video.views)} views • ${_formatDate(video.createdAt)}',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
    );
  }
}
