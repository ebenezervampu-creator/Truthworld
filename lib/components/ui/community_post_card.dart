import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/utils/format_utils.dart';

class CommunityPostReactionState {
  final int likes;
  final int dislikes;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final bool isLiked;
  final bool isDisliked;

  const CommunityPostReactionState({
    required this.likes,
    required this.dislikes,
    required this.likedBy,
    required this.dislikedBy,
    required this.isLiked,
    required this.isDisliked,
  });
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
  final CommunityPostModel post;
  final VoidCallback? onTap;
  final bool isFullWidth;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.isFullWidth = true,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  int _currentPage = 0;
  late CommunityPostReactionState _reactionState;
  int _commentCount = 0;
  List<Map<String, dynamic>> _comments = const [];
  final _commentController = TextEditingController();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
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
    _reactionState = CommunityPostReactionState(
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
      Get.snackbar("Authentication Required", "Please sign in to like posts.");
      return;
    }

    final previousState = _reactionState;
    final nextState = CommunityPostCardReactionEngine.toggleLike(previousState, _currentUid!);
    setState(() => _reactionState = nextState);

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
      debugPrint("Error updating like status: $e");
      setState(() => _reactionState = previousState);
    }
  }

  Future<void> _toggleDislike() async {
    if (_currentUid == null) {
      Get.snackbar("Authentication Required", "Please sign in to dislike posts.");
      return;
    }

    final previousState = _reactionState;
    final nextState = CommunityPostCardReactionEngine.toggleDislike(previousState, _currentUid!);
    setState(() => _reactionState = nextState);

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
      debugPrint("Error updating dislike status: $e");
      setState(() => _reactionState = previousState);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_currentUid == null) {
      Get.snackbar("Authentication Required", "Please sign in to comment.");
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

      Get.snackbar("Success", "Comment posted successfully!");
    } catch (e) {
      Get.snackbar("Error", "Failed to post comment: $e");
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
                  radius: 20,
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
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppTheme.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
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
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: Colors.white,
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
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _reactionState.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: _reactionState.isLiked ? AppTheme.colors.primary : Colors.white,
                    size: 20,
                  ),
                  onPressed: _toggleLike,
                ),
                Text(
                  FormatUtils.formatCount(_reactionState.likes),
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    _reactionState.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                    color: _reactionState.isDisliked ? Colors.redAccent : Colors.white,
                    size: 20,
                  ),
                  onPressed: _toggleDislike,
                ),
                Text(
                  FormatUtils.formatCount(_reactionState.dislikes),
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.comment_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                ),
                Text(
                  FormatUtils.formatCount(_commentCount),
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
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
              setState(() {
                _currentPage = index;
              });
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
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.colors.surface,
                  child: const Icon(Icons.error, color: Colors.white),
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
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1}/${images.length}',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                  Text(
                    'Comments',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    FormatUtils.formatCount(_commentCount),
                    style: GoogleFonts.roboto(color: Colors.grey, fontSize: 12),
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
                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: GoogleFonts.roboto(color: Colors.grey, fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
                      icon: const Icon(Icons.send, color: Colors.blue, size: 16),
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
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                text,
                                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12),
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
        child: Container(
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
          errorWidget: (context, url, error) => Container(
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
              errorWidget: (context, url, error) => Container(
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
            SizedBox(width: 4),
            Text(
              '${widget.post.likes}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.thumb_down_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
            Text(
              '${widget.post.dislikeCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.comment_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
            Text(
              '${widget.post.commentCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.visibility_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
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
}
