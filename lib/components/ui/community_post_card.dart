import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class CommunityPostReactionState {
  const CommunityPostReactionState({
    required this.likes,
    required this.dislikes,
    required this.likedBy,
    required this.dislikedBy,
    required this.isLiked,
    required this.isDisliked,
  });
  final int likes;
  final int dislikes;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final bool isLiked;
  final bool isDisliked;
}

class CommunityPostCardReactionEngine {
  static CommunityPostReactionState toggleLike(
    CommunityPostReactionState state,
    String userId,
  ) {
    final likedBy = [...state.likedBy];
    final dislikedBy = [...state.dislikedBy];
    final hasLiked = likedBy.contains(userId);

    if (hasLiked) {
      likedBy.remove(userId);
      return CommunityPostReactionState(
        likes: (state.likes - 1).clamp(0, 999999999),
        dislikes: state.dislikes,
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: false,
        isDisliked: dislikedBy.contains(userId),
      );
    }

    final hadDisliked = dislikedBy.remove(userId);

    if (!likedBy.contains(userId)) {
      likedBy.add(userId);
    }

    return CommunityPostReactionState(
      likes: state.likes + 1,
      dislikes: hadDisliked
          ? (state.dislikes - 1).clamp(0, 999999999)
          : state.dislikes,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      isLiked: true,
      isDisliked: false,
    );
  }

  static CommunityPostReactionState toggleDislike(
    CommunityPostReactionState state,
    String userId,
  ) {
    final likedBy = [...state.likedBy];
    final dislikedBy = [...state.dislikedBy];
    final hasDisliked = dislikedBy.contains(userId);

    if (hasDisliked) {
      dislikedBy.remove(userId);
      return CommunityPostReactionState(
        likes: state.likes,
        dislikes: (state.dislikes - 1).clamp(0, 999999999),
        likedBy: likedBy,
        dislikedBy: dislikedBy,
        isLiked: likedBy.contains(userId),
        isDisliked: false,
      );
    }

    final hadLiked = likedBy.remove(userId);

    if (!dislikedBy.contains(userId)) {
      dislikedBy.add(userId);
    }

    return CommunityPostReactionState(
      likes: hadLiked ? (state.likes - 1).clamp(0, 999999999) : state.likes,
      dislikes: state.dislikes + 1,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      isLiked: false,
      isDisliked: true,
    );
  }
}

class CommunityPostCard extends StatefulWidget {
  const CommunityPostCard({
    required this.post,
    super.key,
    this.onTap,
    this.isFullWidth = true,
  });
  final CommunityPostModel post;
  final VoidCallback? onTap;
  final bool isFullWidth;

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard>
    with ContentValidationMixin {
  final RxInt _currentPage = 0.obs;
  late final Rx<CommunityPostReactionState> _reactionState;
  late final RxInt _commentCount;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;
  final RxBool _isHidden = false.obs;
  final RxBool _isSaved = false.obs;

  @override
  void initState() {
    super.initState();
    final likedBy = List<String>.from(widget.post.likedBy);
    final dislikedBy = List<String>.from(widget.post.dislikedBy);
    _reactionState = CommunityPostReactionState(
      likes: widget.post.likes,
      dislikes: widget.post.dislikes,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      isLiked: _currentUid != null && likedBy.contains(_currentUid),
      isDisliked: _currentUid != null && dislikedBy.contains(_currentUid),
    ).obs;
    _commentCount = widget.post.commentCount.obs;
    _checkSavedStatus();
    _checkHiddenStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          Get.arguments != null &&
          Get.arguments is Map &&
          (Get.arguments['postId'] == widget.post.id ||
              Get.arguments['commentId'] != null) &&
          (Get.arguments['autoOpenComments'] == true)) {
        _openCommentsPopup(context);
      }
    });
  }

  Future<void> _checkHiddenStatus() async {
    if (_currentUid == null) return;
    try {
      final hiddenDocFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('hiddenCommunityPosts')
          .doc(widget.post.id)
          .get();
      final mutedChannelFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('mutedCommunityChannels')
          .doc(widget.post.channelId)
          .get();
      final reportedDocFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('reportedCommunityPosts')
          .doc(widget.post.id)
          .get();

      final results = await Future.wait([
        hiddenDocFuture,
        mutedChannelFuture,
        reportedDocFuture,
      ]);
      if (results[0].exists || results[1].exists || results[2].exists) {
        if (mounted) {
          _isHidden.value = true;
        }
      }
    } catch (_) {}
  }

  Future<void> _checkSavedStatus() async {
    if (_currentUid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('savedCommunityPosts')
          .doc(widget.post.id)
          .get();
      _isSaved.value = doc.exists;
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _syncFromPost();
    }
  }

  void _syncFromPost() {
    final likedBy = List<String>.from(widget.post.likedBy);
    final dislikedBy = List<String>.from(widget.post.dislikedBy);
    _reactionState.value = CommunityPostReactionState(
      likes: widget.post.likes,
      dislikes: widget.post.dislikes,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      isLiked: _currentUid != null && likedBy.contains(_currentUid),
      isDisliked: _currentUid != null && dislikedBy.contains(_currentUid),
    );
    _commentCount = widget.post.commentCount.obs;
  }

  Future<void> _toggleLike() async {
    if (_currentUid == null) {
      Get.snackbar('Authentication Required', 'Please sign in to like posts.');
      return;
    }

    final previousState = _reactionState.value;
    final nextState = CommunityPostCardReactionEngine.toggleLike(
      previousState,
      _currentUid,
    );
    _reactionState.value = nextState;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.post.id);
      final updates = <String, dynamic>{};

      if (previousState.isLiked && !nextState.isLiked) {
        updates['likes'] = FieldValue.increment(-1);
        updates['likedby'] = FieldValue.arrayRemove([_currentUid]);
      } else if (!previousState.isLiked && nextState.isLiked) {
        updates['likes'] = FieldValue.increment(1);
        updates['likedby'] = FieldValue.arrayUnion([_currentUid]);
      }

      if (previousState.isDisliked && !nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(-1);
        updates['dislikedby'] = FieldValue.arrayRemove([_currentUid]);
      } else if (!previousState.isDisliked && nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(1);
        updates['dislikedby'] = FieldValue.arrayUnion([_currentUid]);
      }

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e) {
      debugPrint('Error updating like status: $e');
      _reactionState.value = previousState;
    }
  }

  Future<void> _toggleDislike() async {
    if (_currentUid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to dislike posts.',
      );
      return;
    }

    final previousState = _reactionState.value;
    final nextState = CommunityPostCardReactionEngine.toggleDislike(
      previousState,
      _currentUid,
    );
    _reactionState.value = nextState;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.post.id);
      final updates = <String, dynamic>{};

      if (previousState.isDisliked && !nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(-1);
        updates['dislikedby'] = FieldValue.arrayRemove([_currentUid]);
      } else if (!previousState.isDisliked && nextState.isDisliked) {
        updates['dislikes'] = FieldValue.increment(1);
        updates['dislikedby'] = FieldValue.arrayUnion([_currentUid]);
      }

      if (previousState.isLiked && !nextState.isLiked) {
        updates['likes'] = FieldValue.increment(-1);
        updates['likedby'] = FieldValue.arrayRemove([_currentUid]);
      } else if (!previousState.isLiked && nextState.isLiked) {
        updates['likes'] = FieldValue.increment(1);
        updates['likedby'] = FieldValue.arrayUnion([_currentUid]);
      }

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e) {
      debugPrint('Error updating dislike status: $e');
      _reactionState.value = previousState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_isHidden.value) return const SizedBox.shrink();
      if (!widget.isFullWidth) {
        return _buildCompactGridCard(context);
      }
      return _buildFullTruthworldCard(context);
    });
  }

  Widget _buildFullTruthworldCard(BuildContext context) {
    final hasImages = widget.post.images.isNotEmpty;
    final timeStr = timeago.format(widget.post.uploadedAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.colors.background,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.colors.border.withValues(alpha: 0.15),
            width: 8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _navigateToChannel(context),
                  borderRadius: BorderRadius.circular(20),
                  child: UserAvatar(
                    photoUrl: widget.post.channelImage,
                    displayName: widget.post.channelName,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _navigateToChannel(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.channelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => _showPostOptionsMenu(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Description Text
          if (widget.post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClickableUrlText(
                text: widget.post.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          if (widget.post.description.isNotEmpty && hasImages)
            const SizedBox(height: 12),

          // Images Carousel
          if (hasImages) _buildImageCarousel(),

          // Interaction buttons (Like, Dislike, Comment, Share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Obx(() {
              final state = _reactionState.value;
              return Row(
                children: [
                  if (widget.post.isLikeEnabled) ...[
                    IconButton(
                      icon: Icon(
                        state.isLiked
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleLike,
                    ),
                    if (widget.post.showLikeCount)
                      Text(
                        FormatUtils.formatCount(state.likes),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                  if (widget.post.isDislikeEnabled) ...[
                    IconButton(
                      icon: Icon(
                        state.isDisliked
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleDislike,
                    ),
                    if (widget.post.showDislikeCount)
                      Text(
                        FormatUtils.formatCount(state.dislikes),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  // Comment Button with Icon and Text
                  if (widget.post.isCommentsEnabled) ...[
                    InkWell(
                      onTap: () => _openCommentsPopup(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.comment_outlined,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Obx(() => Text(
                              FormatUtils.formatCount(_commentCount.value),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Share Button with Icon and Text
                  InkWell(
                    onTap: () {
                      ShareBottomSheet.show(
                        title: widget.post.title.isNotEmpty
                            ? widget.post.title
                            : widget.post.description,
                        url:
                            'https://www.truthworld.in/community/${widget.post.id}',
                        thumbnailUrl: widget.post.images.isNotEmpty
                            ? widget.post.images.first
                            : null,
                        channelName: widget.post.channelName,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.share_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.post.shares.isNotEmpty
                                ? FormatUtils.formatCount(
                                    widget.post.shares.length,
                                  )
                                : 'Share',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showPostOptionsMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Obx(
                () => ListTile(
                  leading: Icon(
                    _isSaved.value
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    _isSaved.value ? 'Unsave post' : 'Save post',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleSavePost();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Hide post',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _hidePost();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Off community posts from this channel',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _turnOffChannelPosts();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Unsubscribe',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _unsubscribeChannel();
                },
              ),
              if (_currentUid != null && _currentUid == widget.post.ownerId)
                ListTile(
                  leading: const Icon(
                    Icons.thumbs_up_down_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Like & Dislike Count Settings',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showPostReactionsSettingsModal(context);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.redAccent, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportModal(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showPostReactionsSettingsModal(BuildContext context) {
    final showLike = widget.post.showLikeCount.obs;
    final showDislike = widget.post.showDislikeCount.obs;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.thumbs_up_down_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Like & Dislike Counts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Show Like Count',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Show like count to users',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    value: showLike.value,
                    onChanged: (v) => showLike.value = v,
                    activeTrackColor: AppColors.brand,
                  ),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Show Dislike Count',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Show dislike count to users',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    value: showDislike.value,
                    onChanged: (v) => showDislike.value = v,
                    activeTrackColor: AppColors.brand,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await FirebaseFirestore.instance
                                .collection('Community')
                                .doc(widget.post.id)
                                .update({
                                  'showLikeCount': showLike.value,
                                  'showDislikeCount': showDislike.value,
                                });
                            Get.snackbar(
                              'Success',
                              'Post count settings updated.',
                            );
                          } catch (e) {
                            Get.snackbar(
                              'Error',
                              'Failed to update settings: $e',
                            );
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleSavePost() async {
    if (_currentUid == null) {
      Get.snackbar('Authentication Required', 'Please sign in to save posts.');
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('savedCommunityPosts')
        .doc(widget.post.id);

    try {
      if (_isSaved.value) {
        _isSaved.value = false;
        await docRef.delete();
        Get.snackbar(
          'Removed',
          'Post removed from Saved Posts',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } else {
        _isSaved.value = true;
        final data = widget.post.toMap();
        data['savedAt'] = FieldValue.serverTimestamp();
        await docRef.set(data);
        Get.snackbar(
          'Saved',
          'Post saved to Saved Posts',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/saved-community-posts'),
            child: const Text(
              'VIEW',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      _isSaved.value = !_isSaved.value;
      Get.snackbar(
        'Error',
        'Failed to save post: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void _navigateToChannel(BuildContext context) {
    if (widget.post.channelId.isEmpty) return;
    Get.toNamed<dynamic>('/channel/${widget.post.channelId}');
  }

  Future<void> _hidePost() async {
    _isHidden.value = true;
    if (_currentUid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('hiddenCommunityPosts')
            .doc(widget.post.id)
            .set({
              'postId': widget.post.id,
              'hiddenAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    }
    Get.snackbar(
      'Post Hidden',
      'Post hidden from your feed',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurface,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _turnOffChannelPosts() async {
    _isHidden.value = true;
    if (_currentUid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('mutedCommunityChannels')
            .doc(widget.post.channelId)
            .set({
              'channelId': widget.post.channelId,
              'channelName': widget.post.channelName,
              'mutedAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    }
    Get.snackbar(
      'Posts Turned Off',
      'Community posts from ${widget.post.channelName} turned off',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurface,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _unsubscribeChannel() async {
    if (_currentUid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to manage subscriptions.',
      );
      return;
    }
    try {
      final channelCtrl = Get.isRegistered<ChannelController>()
          ? Get.find<ChannelController>()
          : Get.put(ChannelController());
      await channelCtrl.unsubscribeFromChannel(
        widget.post.channelId,
      );
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc('${widget.post.channelId}_$_currentUid')
          .delete();
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('subscriptions')
          .doc(widget.post.channelId)
          .delete();
    } catch (_) {}

    Get.snackbar(
      'Unsubscribed',
      'Unsubscribed from ${widget.post.channelName}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurface,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _showReportModal(BuildContext context) {
    if (_currentUid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to report posts.',
      );
      return;
    }

    final reasons = [
      {
        'label': 'Sexual content',
        'description': 'Nudity, sexually explicit content, or pornography',
      },
      {
        'label': 'Violent or repulsive content',
        'description': 'Fight clips, self-harm, gore, or animal abuse',
      },
      {
        'label': 'Hateful or abusive content',
        'description': 'Promoting violence or hatred against protected groups',
      },
      {
        'label': 'Harassment or bullying',
        'description': 'Cyberbullying or personal abuse',
      },
      {
        'label': 'Harmful or dangerous acts',
        'description': 'Dangerous challenges, stunts, or drug promotion',
      },
      {
        'label': 'Child abuse',
        'description': 'Endangerment, exploitation, or sexualization of minors',
      },
      {
        'label': 'Spam or misleading',
        'description': 'Scams, clickbait, or deceptive metadata',
      },
      {
        'label': 'Infringement of my rights',
        'description': 'Copyright violation or privacy invasion',
      },
    ];

    final selectedReason = RxnString();
    final currentStep = 1.obs;
    final detailsController = TextEditingController();

    Get.bottomSheet<dynamic>(
      Obx(() {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (currentStep.value == 2)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => currentStep.value = 1,
                    ),
                  const Icon(
                    Icons.flag_rounded,
                    color: Colors.redAccent,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currentStep.value == 1
                        ? 'Report community post'
                        : 'Provide details',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (currentStep.value == 1) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reasons.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final item = reasons[index];
                      final label = item['label']!;
                      final desc = item['description']!;
                      return RadioListTile<String>(
                        value: label,
                        groupValue: selectedReason.value,
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          desc,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        activeColor: AppColors.brand,
                        onChanged: (val) {
                          selectedReason.value = val;
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: selectedReason.value == null
                      ? null
                      : () {
                          currentStep.value = 2;
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                Text(
                  'Selected Reason: ${selectedReason.value}',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _submitReport(
                      selectedReason.value ?? 'Reported',
                      detailsController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

  Future<void> _submitReport(String reason, String details) async {
    if (_currentUid == null) return;
    _isHidden.value = true;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'postId': widget.post.id,
        'channelId': widget.post.channelId,
        'userId': _currentUid,
        'reportedBy': _currentUid,
        'reason': reason,
        'details': details,
        'reportedAt': FieldValue.serverTimestamp(),
        'type': 'community_post',
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('reportedCommunityPosts')
          .doc(widget.post.id)
          .set({
            'postId': widget.post.id,
            'reason': reason,
            'reportedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}

    Get.snackbar(
      'Reported',
      'Thank you for reporting. This post has been hidden from your feed.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurface,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    if (images.isEmpty) return;
    final pageController = PageController(initialPage: initialIndex);
    final currentPage = initialIndex.obs;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                currentPage.value = index;
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brand,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: Get.back,
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Obx(
                      () => Text(
                        '${currentPage.value + 1} / ${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      useSafeArea: false,
    );
  }

  Widget _buildImageCarousel() {
    final images = widget.post.images;
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              _currentPage.value = index;
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, images, index),
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppTheme.colors.surface,
                    highlightColor: AppTheme.colors.border,
                    child: Container(color: AppTheme.colors.surface),
                  ),
                  errorWidget: (context, url, error) => ColoredBox(
                    color: AppTheme.colors.surface,
                    child: const Icon(
                      Icons.error,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgPage.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Obx(
                  () => Text(
                    '${_currentPage.value + 1}/${images.length}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactGridCard(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: 'Community Post: ${widget.post.title}',
      child: AnimatedContainer(
        duration: AppTheme.animations.normal,
        curve: AppTheme.animations.easeOutCubic,
        decoration: BoxDecoration(
          color: AppTheme.colors.surface,
          borderRadius: AppTheme.radius.circularLg,
          border: Border.all(
            color: AppTheme.colors.border.withValues(alpha: 0.3),
            width: AppTheme.components.dividerThickness,
          ),
          boxShadow: AppTheme.shadows.elevationMd,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTheme.radius.circularLg,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppTheme.radius.circularLg,
            hoverColor: AppTheme.colors.surface.withValues(alpha: 0.8),
            splashColor: AppTheme.colors.primary.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactImages(),
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing.xs),
                  child: _buildCompactDetails(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactImages() {
    if (widget.post.images.isEmpty) {
      return SizedBox(
        height: 120,
        child: ColoredBox(
          color: AppTheme.colors.surface,
          child: Icon(
            Icons.article,
            size: AppTheme.sizes.iconLg,
            color: AppTheme.colors.primary,
          ),
        ),
      );
    }

    if (widget.post.images.length == 1) {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, widget.post.images, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radius.lg),
          ),
          child: CachedNetworkImage(
            imageUrl: widget.post.images.first,
            fit: BoxFit.cover,
            height: 150,
            memCacheWidth: AppTheme.sizes.imageCacheMediumWidth,
            memCacheHeight: AppTheme.sizes.imageCacheMediumHeight,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: AppTheme.colors.surface,
              highlightColor: AppTheme.colors.border,
              child: Container(color: AppTheme.colors.surface),
            ),
            errorWidget: (context, url, error) => ColoredBox(
              color: AppTheme.colors.surface,
              child: const Icon(Icons.error),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius.lg),
      ),
      child: SizedBox(
        height: 150,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.post.images.length > 4 ? 3 : 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: widget.post.images.take(4).length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () =>
                  _showFullScreenImage(context, widget.post.images, index),
              child: CachedNetworkImage(
                imageUrl: widget.post.images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: AppTheme.colors.surface,
                  highlightColor: AppTheme.colors.border,
                  child: Container(color: AppTheme.colors.surface),
                ),
                errorWidget: (context, url, error) => ColoredBox(
                  color: AppTheme.colors.surface,
                  child: const Icon(Icons.error),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClickableUrlText(
          text: widget.post.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.typography.body.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        SizedBox(height: AppTheme.spacing.xs),
        InkWell(
          onTap: () => _navigateToChannel(context),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              UserAvatar(
                radius: 12,
                photoUrl: widget.post.channelImage,
                displayName: widget.post.channelName,
                fontSize: 12,
              ),
              SizedBox(width: AppTheme.spacing.xs),
              Expanded(
                child: Text(
                  widget.post.channelName,
                  style: AppTheme.typography.bodyMedium.copyWith(
                    color: AppTheme.colors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppTheme.spacing.xs),
        Row(
          children: [
            Icon(
              Icons.thumb_up_outlined,
              size: 14,
              color: AppTheme.colors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.post.likes}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(
              Icons.thumb_down_outlined,
              size: 14,
              color: AppTheme.colors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.post.dislikeCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(
              Icons.comment_outlined,
              size: 14,
              color: AppTheme.colors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.post.commentCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(
              Icons.visibility_outlined,
              size: 14,
              color: AppTheme.colors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.post.views}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openCommentsPopup(BuildContext context) {
    final isSortNewest = false.obs;
    final textController = TextEditingController();

    Get.bottomSheet<void>(
      DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F0F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('Community')
                            .doc(widget.post.id)
                            .collection('comments')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count =
                              snapshot.data?.docs.length ?? _commentCount;
                          return Text(
                            'Comments ($count)',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      Row(
                        children: [
                          PopupMenuButton<bool>(
                            onSelected: (newest) {
                              isSortNewest.value = newest;
                            },
                            offset: const Offset(0, 30),
                            itemBuilder: (context) =>
                                <PopupMenuEntry<bool>>[
                                  PopupMenuItem<bool>(
                                    value: false,
                                    child: Obx(() {
                                      final isSelected = !isSortNewest.value;
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.check,
                                            size: 18,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Top comments'),
                                        ],
                                      );
                                    }),
                                  ),
                                  PopupMenuItem<bool>(
                                    value: true,
                                    child: Obx(() {
                                      final isSelected = isSortNewest.value;
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.check,
                                            size: 18,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Newest first'),
                                        ],
                                      );
                                    }),
                                  ),
                                ],
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.sort_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('Community')
                        .doc(widget.post.id)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brand,
                          ),
                        );
                      }

                      final docs =
                          snapshot.data?.docs
                              .map((d) => {'id': d.id, ...d.data()})
                              .toList() ??
                          [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Obx(() {
                        final newest = isSortNewest.value;
                        final sortedDocs = List<Map<String, dynamic>>.from(
                          docs,
                        );
                        if (newest) {
                          sortedDocs.sort((a, b) {
                            final tsA =
                                a['createdAt'] as Timestamp? ??
                                a['timestamp'] as Timestamp? ??
                                Timestamp.now();
                            final tsB =
                                b['createdAt'] as Timestamp? ??
                                b['timestamp'] as Timestamp? ??
                                Timestamp.now();
                            return tsB.compareTo(tsA);
                          });
                        } else {
                          sortedDocs.sort((a, b) {
                            final likesA =
                                (a['likeCount'] as num?)?.toInt() ??
                                (a['likes'] as num?)?.toInt() ??
                                ((a['likedBy'] as List?)?.length ?? 0);
                            final likesB =
                                (b['likeCount'] as num?)?.toInt() ??
                                (b['likes'] as num?)?.toInt() ??
                                ((b['likedBy'] as List?)?.length ?? 0);
                            return likesB.compareTo(likesA);
                          });
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: sortedDocs.length,
                          itemBuilder: (context, index) {
                            final commentData = sortedDocs[index];
                            return _CommunityCommentItemWidget(
                              postId: widget.post.id,
                              commentData: commentData,
                              currentUid: _currentUid,
                              postOwnerId: widget.post.ownerId,
                            );
                          },
                        );
                      });
                    },
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: const Color(0xFF181818),
                    child: Row(
                      children: [
                        UserAvatar(
                          radius: 16,
                          photoUrl: AuthService.to.activePhotoUrl.isNotEmpty
                              ? AuthService.to.activePhotoUrl
                              : (FirebaseAuth.instance.currentUser?.photoURL ??
                                    ''),
                          displayName:
                              AuthService.to.activeDisplayName.isNotEmpty
                              ? AuthService.to.activeDisplayName
                              : (FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.displayName ??
                                    'User'),
                          fontSize: 11,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: textController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              Get.snackbar(
                                'Authentication Required',
                                'Please sign in to comment.',
                              );
                              return;
                            }
                            final validation = await validateContent(
                              text,
                              fieldName: 'Comment',
                            );
                            if (!validation.isValid) {
                              Get.snackbar(
                                'Inappropriate Content',
                                validation.message,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.bgSurface,
                                colorText: AppColors.textPrimary,
                              );
                              return;
                            }
                            textController.clear();
                            try {
                              final authService = AuthService.to;
                              final hasChannel = authService.hasChannel.value;
                              final channel = authService.userChannel;

                              final channelId = hasChannel ? channel?.id : null;
                              final channelName = hasChannel
                                  ? (channel?.handle.isNotEmpty ?? false
                                        ? channel?.handle
                                        : channel?.name)
                                  : null;
                              final channelAvatar = hasChannel
                                  ? channel?.avatarUrl
                                  : null;
                              final userAvatar =
                                  authService.activePhotoUrl.isNotEmpty
                                  ? authService.activePhotoUrl
                                  : (user.photoURL ?? '');
                              final userName =
                                  authService.activeDisplayName.isNotEmpty
                                  ? authService.activeDisplayName
                                  : (user.displayName ?? 'User');

                              final postDoc = FirebaseFirestore.instance
                                  .collection('Community')
                                  .doc(widget.post.id);
                              await postDoc.collection('comments').add({
                                'text': text,
                                'userId': user.uid,
                                'userName': userName,
                                'userImage': userAvatar,
                                'userProfilePicUrl': userAvatar,
                                'channelId': channelId,
                                'channelName': channelName,
                                'channelProfilePicUrl': channelAvatar,
                                'createdAt': FieldValue.serverTimestamp(),
                                'timestamp': FieldValue.serverTimestamp(),
                                'likeCount': 0,
                                'dislikeCount': 0,
                                'likedBy': [],
                                'dislikedBy': [],
                                'replyCount': 0,
                              });
                              await postDoc.update({
                                'commentCount': FieldValue.increment(1),
                              });
                              _commentCount.value += 1;
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Failed to post comment: $e',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _CommunityCommentItemWidget extends StatefulWidget {
  const _CommunityCommentItemWidget({
    required this.postId,
    required this.commentData,
    required this.currentUid,
    this.postOwnerId,
  });

  final String postId;
  final Map<String, dynamic> commentData;
  final String? currentUid;
  final String? postOwnerId;

  @override
  State<_CommunityCommentItemWidget> createState() =>
      _CommunityCommentItemWidgetState();
}

class _CommunityCommentItemWidgetState
    extends State<_CommunityCommentItemWidget> with ContentValidationMixin {
  late RxBool _isLiked;
  late RxBool _isDisliked;
  late RxInt _likeCount;
  late RxInt _dislikeCount;
  final RxBool _isReplying = false.obs;
  final RxBool _isRepliesExpanded = false.obs;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final likedBy = List<String>.from(
      widget.commentData['likedBy'] ?? widget.commentData['likedby'] ?? [],
    );
    final dislikedBy = List<String>.from(
      widget.commentData['dislikedBy'] ??
          widget.commentData['dislikedby'] ??
          [],
    );
    final uid = widget.currentUid ?? '';
    _isLiked = likedBy.contains(uid).obs;
    _isDisliked = dislikedBy.contains(uid).obs;
    _likeCount =
        ((widget.commentData['likeCount'] ??
                    widget.commentData['likes'] ??
                    likedBy.length)
                as num)
            .toInt()
            .obs;
    _dislikeCount =
        ((widget.commentData['dislikeCount'] ??
                    widget.commentData['dislikes'] ??
                    dislikedBy.length)
                as num)
            .toInt()
            .obs;
  }

  Future<void> _toggleCommentLike() async {
    final uid = widget.currentUid;
    if (uid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to like comments.',
      );
      return;
    }
    final commentId = widget.commentData['id'] as String;
    final docRef = FirebaseFirestore.instance
        .collection('Community')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    if (_isLiked.value) {
      _isLiked.value = false;
      _likeCount.value = (_likeCount.value - 1).clamp(0, 999999);
      await docRef.update({
        'likeCount': FieldValue.increment(-1),
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
        'likedby': FieldValue.arrayRemove([uid]),
      });
    } else {
      if (_isDisliked.value) {
        _isDisliked.value = false;
        _dislikeCount.value = (_dislikeCount.value - 1).clamp(0, 999999);
        await docRef.update({
          'dislikeCount': FieldValue.increment(-1),
          'dislikes': FieldValue.increment(-1),
          'dislikedBy': FieldValue.arrayRemove([uid]),
          'dislikedby': FieldValue.arrayRemove([uid]),
        });
      }
      _isLiked.value = true;
      _likeCount.value += 1;
      await docRef.update({
        'likeCount': FieldValue.increment(1),
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
        'likedby': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> _toggleCommentDislike() async {
    final uid = widget.currentUid;
    if (uid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to dislike comments.',
      );
      return;
    }
    final commentId = widget.commentData['id'] as String;
    final docRef = FirebaseFirestore.instance
        .collection('Community')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    if (_isDisliked.value) {
      _isDisliked.value = false;
      _dislikeCount.value = (_dislikeCount.value - 1).clamp(0, 999999);
      await docRef.update({
        'dislikeCount': FieldValue.increment(-1),
        'dislikes': FieldValue.increment(-1),
        'dislikedBy': FieldValue.arrayRemove([uid]),
        'dislikedby': FieldValue.arrayRemove([uid]),
      });
    } else {
      if (_isLiked.value) {
        _isLiked.value = false;
        _likeCount.value = (_likeCount.value - 1).clamp(0, 999999);
        await docRef.update({
          'likeCount': FieldValue.increment(-1),
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
          'likedby': FieldValue.arrayRemove([uid]),
        });
      }
      _isDisliked.value = true;
      _dislikeCount.value += 1;
      await docRef.update({
        'dislikeCount': FieldValue.increment(1),
        'dislikes': FieldValue.increment(1),
        'dislikedBy': FieldValue.arrayUnion([uid]),
        'dislikedby': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('Authentication Required', 'Please sign in to reply.');
      return;
    }
    final validation = await validateContent(text, fieldName: 'Reply');
    if (!validation.isValid) {
      Get.snackbar(
        'Inappropriate Content',
        validation.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
      );
      return;
    }
    _replyController.clear();
    _isReplying.value = false;

    final commentId = widget.commentData['id'] as String;
    try {
      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final channelId = hasChannel ? channel?.id : null;
      final channelName = hasChannel
          ? (channel?.handle.isNotEmpty ?? false
                ? channel?.handle
                : channel?.name)
          : null;
      final channelAvatar = hasChannel ? channel?.avatarUrl : null;
      final userAvatar = authService.activePhotoUrl.isNotEmpty
          ? authService.activePhotoUrl
          : (user.photoURL ?? '');
      final userName = authService.activeDisplayName.isNotEmpty
          ? authService.activeDisplayName
          : (user.displayName ?? 'User');

      final commentDoc = FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      await commentDoc.collection('replies').add({
        'text': text,
        'userId': user.uid,
        'userName': userName,
        'userImage': userAvatar,
        'userProfilePicUrl': userAvatar,
        'channelId': channelId,
        'channelName': channelName,
        'channelProfilePicUrl': channelAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'dislikeCount': 0,
        'likedBy': [],
        'dislikedBy': [],
      });

      await commentDoc.update({
        'replyCount': FieldValue.increment(1),
      });

      _isRepliesExpanded.value = true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to post reply: $e');
    }
  }

  Future<void> _toggleSaveComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to save comments.',
      );
      return;
    }
    final commentId = widget.commentData['id'] as String? ?? '';
    if (commentId.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedComments')
        .doc(commentId);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        Get.snackbar('Removed', 'Comment removed from Saved Comments');
      } else {
        final userName =
            widget.commentData['channelName']?.toString().isNotEmpty ?? false
            ? widget.commentData['channelName'].toString()
            : (widget.commentData['userName']?.toString() ?? 'User');
        final userImage =
            widget.commentData['channelProfilePicUrl']?.toString().isNotEmpty ??
                false
            ? widget.commentData['channelProfilePicUrl'].toString()
            : (widget.commentData['userImage']?.toString() ??
                  widget.commentData['userProfilePicUrl']?.toString() ??
                  '');
        final text = widget.commentData['text']?.toString() ?? '';

        await docRef.set({
          'text': text,
          'userName': userName,
          'userImage': userImage,
          'sourceType': 'community_post',
          'sourceId': widget.postId,
          'sourceTitle': 'Community Post',
          'savedAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar(
          'Saved',
          'Comment saved to Saved Comments',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/saved-comments'),
            child: const Text(
              'VIEW',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to save comment: $e');
    }
  }

  void _showCommentOptions(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authorId = widget.commentData['userId'] as String?;
    final isOwner = user != null && user.uid == authorId;
    final text = widget.commentData['text']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save comment',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSaveComment();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: const Text(
                  'Copy comment text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                  Get.snackbar('Copied', 'Comment copied to clipboard');
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete comment',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final commentId = widget.commentData['id'] as String;
                    try {
                      final commentDoc = FirebaseFirestore.instance
                          .collection('Community')
                          .doc(widget.postId)
                          .collection('comments')
                          .doc(commentId);
                      await commentDoc.delete();
                      await FirebaseFirestore.instance
                          .collection('Community')
                          .doc(widget.postId)
                          .update({'commentCount': FieldValue.increment(-1)});
                    } catch (e) {
                      Get.snackbar('Error', 'Failed to delete comment: $e');
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report comment',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Get.snackbar(
                      'Reported',
                      'Thank you for reporting inappropriate content',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        widget.commentData['channelName']?.toString().isNotEmpty ?? false
        ? widget.commentData['channelName'].toString()
        : (widget.commentData['userName']?.toString() ?? 'User');
    final userImage =
        widget.commentData['channelProfilePicUrl']?.toString().isNotEmpty ??
            false
        ? widget.commentData['channelProfilePicUrl'].toString()
        : (widget.commentData['userImage']?.toString() ??
              widget.commentData['userProfilePicUrl']?.toString() ??
              '');
    final text = widget.commentData['text']?.toString() ?? '';
    final ts =
        widget.commentData['createdAt'] as Timestamp? ??
        widget.commentData['timestamp'] as Timestamp?;
    final timeStr = ts != null ? timeago.format(ts.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                radius: 16,
                photoUrl: userImage,
                displayName: userName,
                fontSize: 11,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: GoogleFonts.roboto(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Obx(
                          () => InkWell(
                            onTap: _toggleCommentLike,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked.value
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    color: _isLiked.value
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 16,
                                  ),
                                  if (_likeCount.value > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      FormatUtils.formatCount(_likeCount.value),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => InkWell(
                            onTap: _toggleCommentDislike,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isDisliked.value
                                        ? Icons.thumb_down
                                        : Icons.thumb_down_outlined,
                                    color: _isDisliked.value
                                        ? AppColors.error
                                        : Colors.white70,
                                    size: 16,
                                  ),
                                  if (_dislikeCount.value > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      FormatUtils.formatCount(
                                        _dislikeCount.value,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            _isReplying.value = !_isReplying.value;
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Reply',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                            size: 16,
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () => _showCommentOptions(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Obx(() {
            if (!_isReplying.value) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(left: 44, top: 8, bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to @$userName',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Add a reply...',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _isReplying.value = false,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _submitReply,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          _buildRepliesList(),
        ],
      ),
    );
  }

  Widget _buildRepliesList() {
    final commentId = widget.commentData['id'] as String;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final replies = snapshot.data!.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        if (replies.isEmpty) return const SizedBox.shrink();

        return Obx(() {
          final isExpanded = _isRepliesExpanded.value;

          if (!isExpanded) {
            final firstReply = replies.first;
            final replyAvatar =
                firstReply['channelProfilePicUrl']?.toString().isNotEmpty ??
                    false
                ? firstReply['channelProfilePicUrl'].toString()
                : (firstReply['userImage']?.toString() ??
                      firstReply['userProfilePicUrl']?.toString() ??
                      '');
            final replyName =
                firstReply['channelName']?.toString().isNotEmpty ?? false
                ? firstReply['channelName'].toString()
                : (firstReply['userName']?.toString() ?? 'User');

            return InkWell(
              onTap: () => _isRepliesExpanded.value = true,
              child: Padding(
                padding: const EdgeInsets.only(left: 44, top: 4),
                child: Row(
                  children: [
                    const CustomPaint(
                      size: Size(20, 24),
                      painter: ReplyThreadLinePainter(
                        color: Colors.white24,
                        isLast: true,
                        branchY: 12,
                      ),
                    ),
                    UserAvatar(
                      radius: 10,
                      photoUrl: replyAvatar,
                      displayName: replyName,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      replies.length == 1
                          ? '• 1 reply'
                          : '• ${replies.length} replies',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more,
                      color: Colors.blue,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(replies.length, (index) {
              final reply = replies[index];
              final isLastReply = index == replies.length - 1;
              return _CommunityReplyItem(
                postId: widget.postId,
                commentId: commentId,
                replyData: reply,
                postOwnerId: widget.postOwnerId,
                isLastReply: isLastReply,
                onReplyToUser: (targetUser) {
                  _replyController.text = '@$targetUser ';
                  _replyController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _replyController.text.length),
                  );
                  _isReplying.value = true;
                },
              );
            }),
          );
        });
      },
    );
  }
}

class _CommunityReplyItem extends StatefulWidget {
  const _CommunityReplyItem({
    required this.postId,
    required this.commentId,
    required this.replyData,
    required this.postOwnerId,
    required this.isLastReply,
    required this.onReplyToUser,
  });

  final String postId;
  final String commentId;
  final Map<String, dynamic> replyData;
  final String? postOwnerId;
  final bool isLastReply;
  final ValueChanged<String> onReplyToUser;

  @override
  State<_CommunityReplyItem> createState() => _CommunityReplyItemState();
}

class _CommunityReplyItemState extends State<_CommunityReplyItem> {
  late final String _replyId;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  late final RxBool _isLiked;
  late final RxBool _isDisliked;
  late final RxInt _likeCount;
  late final RxInt _dislikeCount;

  @override
  void initState() {
    super.initState();
    _replyId = widget.replyData['id'] as String? ?? '';
    final likedBy = List<String>.from(
      widget.replyData['likedBy'] ?? widget.replyData['likedby'] ?? [],
    );
    final dislikedBy = List<String>.from(
      widget.replyData['dislikedBy'] ?? widget.replyData['dislikedby'] ?? [],
    );

    _likeCount =
        ((widget.replyData['likeCount'] ??
                    widget.replyData['likes'] ??
                    likedBy.length)
                as num)
            .toInt()
            .obs;
    _dislikeCount =
        ((widget.replyData['dislikeCount'] ??
                    widget.replyData['dislikes'] ??
                    dislikedBy.length)
                as num)
            .toInt()
            .obs;

    _isLiked = (_currentUid != null && likedBy.contains(_currentUid)).obs;
    _isDisliked = (_currentUid != null && dislikedBy.contains(_currentUid)).obs;
  }

  DocumentReference<Map<String, dynamic>> get _replyRef => FirebaseFirestore
      .instance
      .collection('Community')
      .doc(widget.postId)
      .collection('comments')
      .doc(widget.commentId)
      .collection('replies')
      .doc(_replyId);

  Future<void> _toggleReplyLike() async {
    if (_currentUid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to react to replies.',
      );
      return;
    }

    final willLike = !_isLiked.value;
    _isLiked.value = willLike;
    if (willLike) {
      _likeCount.value++;
      if (_isDisliked.value) {
        _isDisliked.value = false;
        _dislikeCount.value = (_dislikeCount.value - 1).clamp(0, 99999999);
      }
    } else {
      _likeCount.value = (_likeCount.value - 1).clamp(0, 99999999);
    }

    try {
      if (willLike) {
        await _replyRef.update({
          'likes': FieldValue.increment(1),
          'likeCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([_currentUid]),
          'dislikedBy': FieldValue.arrayRemove([_currentUid]),
        });
        await _replyRef.collection('likes').doc(_currentUid).set({
          'likedAt': FieldValue.serverTimestamp(),
        });
        await _replyRef
            .collection('dislikes')
            .doc(_currentUid)
            .delete()
            .catchError((_) {});
      } else {
        await _replyRef.update({
          'likes': FieldValue.increment(-1),
          'likeCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([_currentUid]),
        });
        await _replyRef
            .collection('likes')
            .doc(_currentUid)
            .delete()
            .catchError((_) {});
      }
    } catch (e) {
      debugPrint('Error toggling reply like: $e');
    }
  }

  Future<void> _toggleReplyDislike() async {
    if (_currentUid == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to react to replies.',
      );
      return;
    }

    final willDislike = !_isDisliked.value;
    _isDisliked.value = willDislike;
    if (willDislike) {
      _dislikeCount.value++;
      if (_isLiked.value) {
        _isLiked.value = false;
        _likeCount.value = (_likeCount.value - 1).clamp(0, 99999999);
      }
    } else {
      _dislikeCount.value = (_dislikeCount.value - 1).clamp(0, 99999999);
    }

    try {
      if (willDislike) {
        await _replyRef.update({
          'dislikes': FieldValue.increment(1),
          'dislikeCount': FieldValue.increment(1),
          'dislikedBy': FieldValue.arrayUnion([_currentUid]),
          'likedBy': FieldValue.arrayRemove([_currentUid]),
        });
        await _replyRef.collection('dislikes').doc(_currentUid).set({
          'dislikedAt': FieldValue.serverTimestamp(),
        });
        await _replyRef
            .collection('likes')
            .doc(_currentUid)
            .delete()
            .catchError((_) {});
      } else {
        await _replyRef.update({
          'dislikes': FieldValue.increment(-1),
          'dislikeCount': FieldValue.increment(-1),
          'dislikedBy': FieldValue.arrayRemove([_currentUid]),
        });
        await _replyRef
            .collection('dislikes')
            .doc(_currentUid)
            .delete()
            .catchError((_) {});
      }
    } catch (e) {
      debugPrint('Error toggling reply dislike: $e');
    }
  }

  void _showReplyOptions(BuildContext context) {
    final authorId =
        widget.replyData['userId'] as String? ??
        widget.replyData['channelId'] as String?;
    final isOwner =
        _currentUid != null &&
        (_currentUid == authorId || _currentUid == widget.postOwnerId);
    final text = widget.replyData['text']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save reply',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (_currentUid == null) return;
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_currentUid)
                        .collection('savedComments')
                        .doc(_replyId)
                        .set({
                          'text': text,
                          'userName': widget.replyData['userName'] ?? 'User',
                          'userImage': widget.replyData['userImage'] ?? '',
                          'sourceType': 'community_post_reply',
                          'sourceId': widget.postId,
                          'sourceTitle': 'Community Post Reply',
                          'savedAt': FieldValue.serverTimestamp(),
                        });
                    Get.snackbar('Saved', 'Reply saved to Saved Comments');
                  } catch (e) {
                    Get.snackbar('Error', 'Failed to save reply: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: const Text(
                  'Copy reply text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                  Get.snackbar('Copied', 'Reply copied to clipboard');
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete reply',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _replyRef.delete();
                      await FirebaseFirestore.instance
                          .collection('Community')
                          .doc(widget.postId)
                          .collection('comments')
                          .doc(widget.commentId)
                          .update({'replyCount': FieldValue.increment(-1)});
                    } catch (e) {
                      Get.snackbar('Error', 'Failed to delete reply: $e');
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report reply',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Get.snackbar(
                      'Reported',
                      'Thank you for reporting inappropriate content',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rName =
        widget.replyData['channelName']?.toString().isNotEmpty ?? false
        ? widget.replyData['channelName'].toString()
        : (widget.replyData['userName']?.toString() ?? 'User');
    final rImage =
        widget.replyData['channelProfilePicUrl']?.toString().isNotEmpty ?? false
        ? widget.replyData['channelProfilePicUrl'].toString()
        : (widget.replyData['userImage']?.toString() ??
              widget.replyData['userProfilePicUrl']?.toString() ??
              '');
    final rText = widget.replyData['text']?.toString() ?? '';
    final rTs =
        widget.replyData['createdAt'] as Timestamp? ??
        widget.replyData['timestamp'] as Timestamp?;
    final rTimeStr = rTs != null ? timeago.format(rTs.toDate()) : '';
    final isChannel =
        (widget.replyData['channelId']?.toString().isNotEmpty ?? false) ||
        (widget.postOwnerId != null &&
            (widget.replyData['userId'] == widget.postOwnerId ||
                widget.replyData['channelId'] == widget.postOwnerId));

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(left: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomPaint(
              size: const Size(20, double.infinity),
              painter: ReplyThreadLinePainter(
                color: Colors.white24,
                isLast: widget.isLastReply,
                branchY: 16,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 4,
                  bottom: 6,
                  left: 6,
                  right: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          radius: 10,
                          photoUrl: rImage,
                          displayName: rName,
                          fontSize: 9,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rName,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (isChannel) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Channel',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                        if (rTimeStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            rTimeStr,
                            style: GoogleFonts.roboto(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rText,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Obx(
                          () => InkWell(
                            onTap: _toggleReplyLike,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked.value
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    color: _isLiked.value
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 14,
                                  ),
                                  if (_likeCount.value > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      FormatUtils.formatCount(_likeCount.value),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => InkWell(
                            onTap: _toggleReplyDislike,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isDisliked.value
                                        ? Icons.thumb_down
                                        : Icons.thumb_down_outlined,
                                    color: _isDisliked.value
                                        ? AppColors.error
                                        : Colors.white70,
                                    size: 14,
                                  ),
                                  if (_dislikeCount.value > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      FormatUtils.formatCount(
                                        _dislikeCount.value,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        InkWell(
                          onTap: () => widget.onReplyToUser(rName),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Reply',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                            size: 14,
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () => _showReplyOptions(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReplyThreadLinePainter extends CustomPainter {
  const ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });

  final Color color;
  final bool isLast;
  final double branchY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    if (isLast) {
      path.moveTo(10, 0);
      path.lineTo(10, branchY - 4);
      path.quadraticBezierTo(10, branchY, 16, branchY);
      path.lineTo(size.width, branchY);
    } else {
      path.moveTo(10, 0);
      path.lineTo(10, size.height);
      path.moveTo(10, branchY);
      path.lineTo(size.width, branchY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ReplyThreadLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLast != isLast ||
        oldDelegate.branchY != branchY;
  }
}
