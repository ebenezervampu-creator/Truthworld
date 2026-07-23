import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/utils/format_utils.dart';
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
      dislikes: hadDisliked ? (state.dislikes - 1).clamp(0, 999999999) : state.dislikes,
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
    required this.post, super.key,
    this.onTap,
    this.isFullWidth = true,
  });
  final CommunityPostModel post;
  final VoidCallback? onTap;
  final bool isFullWidth;

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  final RxInt _currentPage = 0.obs;
  late final Rx<CommunityPostReactionState> _reactionState;
  int _commentCount = 0;
  List<Map<String, dynamic>> _comments = const [];
  final _commentController = TextEditingController();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

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
    _commentCount = widget.post.commentCount;
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
    _commentCount = widget.post.commentCount;
  }

  Future<void> _toggleLike() async {
    if (_currentUid == null) {
      Get.snackbar('Authentication Required', 'Please sign in to like posts.');
      return;
    }

    final previousState = _reactionState.value;
    final nextState = CommunityPostCardReactionEngine.toggleLike(previousState, _currentUid);
    _reactionState.value = nextState;

    try {
      final docRef = FirebaseFirestore.instance.collection('Community').doc(widget.post.id);
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
      Get.snackbar('Authentication Required', 'Please sign in to dislike posts.');
      return;
    }

    final previousState = _reactionState.value;
    final nextState = CommunityPostCardReactionEngine.toggleDislike(previousState, _currentUid);
    _reactionState.value = nextState;

    try {
      final docRef = FirebaseFirestore.instance.collection('Community').doc(widget.post.id);
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_currentUid == null) {
      Get.snackbar('Authentication Required', 'Please sign in to comment.');
      return;
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      final postDoc = FirebaseFirestore.instance.collection('Community').doc(widget.post.id);
      
      await postDoc.collection('comments').add({
        'userId': _currentUid,
        'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous',
        'userImage': FirebaseAuth.instance.currentUser?.photoURL ?? '',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await postDoc.update({
        'commentCount': FieldValue.increment(1),
      });

      Get.snackbar('Success', 'Comment posted successfully!');
    } catch (e) {
      Get.snackbar('Error', 'Failed to post comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFullWidth) {
      return _buildCompactGridCard(context);
    }
    return _buildFullYoutubeCard(context);
  }

  Widget _buildFullYoutubeCard(BuildContext context) {
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
                UserAvatar(
                  photoUrl: widget.post.channelImage,
                  displayName: widget.post.channelName,
                  fontSize: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
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
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                  onPressed: () {
                    // Show post options menu
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Description Text
          if (widget.post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.post.description,
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

          // Interaction buttons (Like, Dislike, Share, Comment)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Obx(() {
              final state = _reactionState.value;
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      state.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: state.isLiked ? AppTheme.colors.primary : AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: _toggleLike,
                  ),
                  Text(
                    FormatUtils.formatCount(state.likes),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      state.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                      color: state.isDisliked ? AppColors.error : AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: _toggleDislike,
                  ),
                  Text(
                    FormatUtils.formatCount(state.dislikes),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.comment_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () => _openCommentsPopup(context),
                ),
                GestureDetector(
                  onTap: () => _openCommentsPopup(context),
                  child: Text(
                    FormatUtils.formatCount(_commentCount),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            );
          }),
        ),

          _buildCommentsBox(),
        ],
      ),
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
              return CachedNetworkImage(
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
                  child: const Icon(Icons.error, color: AppColors.textPrimary),
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
                child: Obx(() => Text(
                  '${_currentPage.value + 1}/${images.length}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsBox() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _comments = snapshot.data!.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
          _commentCount = snapshot.data!.docs.length;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    FormatUtils.formatCount(_commentCount),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  UserAvatar(
                    radius: 12,
                    photoUrl: FirebaseAuth.instance.currentUser?.photoURL ?? '',
                    displayName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                    fontSize: 10,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  if (_commentController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.info, size: 16),
                      onPressed: _submitComment,
                    ),
                ],
              ),
              if (_comments.isNotEmpty) ...[
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length > 3 ? 3 : _comments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    final text = comment['text']?.toString() ?? '';
                    final userName = comment['userName']?.toString() ?? 'User';
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(
                          radius: 12,
                          photoUrl: comment['userImage']?.toString() ?? '',
                          displayName: userName,
                          fontSize: 10,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                text,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
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
      return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius.lg)),
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
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius.lg)),
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
            return CachedNetworkImage(
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
        Text(
          widget.post.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.typography.body.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        SizedBox(height: AppTheme.spacing.xs),
        Row(
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
        SizedBox(height: AppTheme.spacing.xs),
        Row(
          children: [
            Icon(Icons.thumb_up_outlined, size: 14, color: AppTheme.colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              '${widget.post.likes}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.thumb_down_outlined, size: 14, color: AppTheme.colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              '${widget.post.dislikeCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.comment_outlined, size: 14, color: AppTheme.colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              '${widget.post.commentCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.visibility_outlined, size: 14, color: AppTheme.colors.textTertiary),
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
    final textController = TextEditingController();

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppColors.bgDivider,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mode_comment_outlined,
                        color: AppColors.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Comments (${FormatUtils.formatCount(_commentCount)})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2E2E2E)),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Community')
                    .doc(widget.post.id)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final comment = docs[index].data();
                      final text = comment['text']?.toString() ?? '';
                      final userName = comment['userName']?.toString() ?? 'User';
                      final userImage = comment['userImage']?.toString() ?? '';
                      final ts = comment['createdAt'] as Timestamp?;
                      final timeStr = ts != null
                          ? timeago.format(ts.toDate())
                          : '';

                      return Row(
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
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2E2E2E)),
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              ),
              color: const Color(0xFF181818),
              child: Row(
                children: [
                  UserAvatar(
                    radius: 16,
                    photoUrl: FirebaseAuth.instance.currentUser?.photoURL ?? '',
                    displayName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                    fontSize: 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.brand, size: 20),
                    onPressed: () async {
                      final text = textController.text.trim();
                      if (text.isEmpty) return;
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        Get.snackbar('Authentication Required', 'Please sign in to comment.');
                        return;
                      }
                      textController.clear();
                      try {
                        final postDoc = FirebaseFirestore.instance.collection('Community').doc(widget.post.id);
                        await postDoc.collection('comments').add({
                          'text': text,
                          'userId': user.uid,
                          'userName': user.displayName ?? 'User',
                          'userImage': user.photoURL ?? '',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        await postDoc.update({'commentCount': FieldValue.increment(1)});
                        setState(() {
                          _commentCount += 1;
                        });
                      } catch (e) {
                        Get.snackbar('Error', 'Failed to post comment: $e');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
