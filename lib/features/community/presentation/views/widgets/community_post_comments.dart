import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

void _showCommunitySignInPrompt(String action) {
  AppSnackbar.warning(
    'Please sign in to $action.',
    actionLabel: 'SIGN IN',
    onAction: AuthService.to.signInWithGoogle,
  );
}

// Backward compatibility aliases
typedef _CommunityCommentItemWidget = CommunityCommentItemWidget;
typedef _CommunityReplyItem = CommunityReplyItem;

class CommunityCommentItemWidget extends StatefulWidget {
  const CommunityCommentItemWidget({
    required this.postId,
    required this.commentData,
    required this.currentUid,
    this.postOwnerId,
    super.key,
  });

  final String postId;
  final Map<String, dynamic> commentData;
  final String? currentUid;
  final String? postOwnerId;

  @override
  State<CommunityCommentItemWidget> createState() =>
      _CommunityCommentItemWidgetState();
}

class _CommunityCommentItemWidgetState
    extends State<CommunityCommentItemWidget> with ContentValidationMixin {
  late RxBool _isLiked;
  late RxBool _isDisliked;
  late RxInt _likeCount;
  late RxInt _dislikeCount;
  final RxBool _isReplying = false.obs;
  final RxBool _isRepliesExpanded = false.obs;
  final TextEditingController _replyController = TextEditingController();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _repliesStream;

  void _initRepliesStream() {
    final commentId = widget.commentData['id'] as String? ?? '';
    if (commentId.isNotEmpty) {
      _repliesStream = FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .snapshots();
    }
  }

  @override
  void initState() {
    super.initState();
    _initRepliesStream();
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

  @override
  void didUpdateWidget(covariant CommunityCommentItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.commentData['id'] != widget.commentData['id']) {
      _initRepliesStream();
    }
  }

  Future<void> _toggleCommentLike() async {
    final uid = widget.currentUid;
    if (uid == null || !AuthService.to.isAuthenticated.value) {
      _showCommunitySignInPrompt('like comments');
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
    if (uid == null || !AuthService.to.isAuthenticated.value) {
      _showCommunitySignInPrompt('dislike comments');
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
    if (!AuthService.to.isAuthenticated.value) {
      _showCommunitySignInPrompt('reply');
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;
    final validation = await validateContent(text, fieldName: 'Reply');
    if (!validation.isValid) {
      AppSnackbar.warning(
        validation.message,
        title: 'Inappropriate Content',
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
      final userAvatar = authService.activePhotoUrl;
      final userName = authService.activeDisplayName;

      final commentDoc = FirebaseFirestore.instance
          .collection('Community')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      await commentDoc.collection('replies').add({
        'text': text,
        'userId': uid,
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityPostComments.postReply',
      );
      AppSnackbar.error('Unable to post reply. Please check your connection and try again.');
    }
  }

  Future<void> _toggleSaveComment() async {
    if (!AuthService.to.isAuthenticated.value) {
      _showCommunitySignInPrompt('save comments');
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;
    final commentId = widget.commentData['id'] as String? ?? '';
    if (commentId.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedComments')
        .doc(commentId);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        AppSnackbar.info('Comment removed from Saved Comments');
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

        AppSnackbar.success(
          'Comment saved to Saved Comments',
          actionLabel: 'VIEW',
          onAction: () => Get.toNamed('/saved-comments'),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityPostComments.saveComment',
      );
      AppSnackbar.error('Unable to save comment. Please try again.');
    }
  }

  void _showCommentOptions(BuildContext context) {
    final authorId = widget.commentData['userId'] as String?;
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == authorId;
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
                  AppSnackbar.info('Comment copied to clipboard', title: 'Copied');
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
                    } catch (e, stackTrace) {
                      ErrorHandler.log(
                        e,
                        stackTrace: stackTrace,
                        context: 'CommunityPostComments.deleteComment',
                      );
                      AppSnackbar.error('Unable to delete comment. Please try again.');
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
                    AppSnackbar.info(
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
                                        ? Colors.white
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
                            if (!AuthService.to.isAuthenticated.value) {
                              _showCommunitySignInPrompt('reply to comments');
                              return;
                            }
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
    if (_repliesStream == null) return const SizedBox.shrink();
    final commentId = widget.commentData['id'] as String? ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repliesStream,
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
                          ? 'â€¢ 1 reply'
                          : 'â€¢ ${replies.length} replies',
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

class CommunityReplyItem extends StatefulWidget {
  const CommunityReplyItem({
    required this.postId,
    required this.commentId,
    required this.replyData,
    required this.onReplyToUser,
    required this.isLastReply,
    this.postOwnerId,
    super.key,
  });

  final String postId;
  final String commentId;
  final Map<String, dynamic> replyData;
  final String? postOwnerId;
  final bool isLastReply;
  final ValueChanged<String> onReplyToUser;

  @override
  State<CommunityReplyItem> createState() => _CommunityReplyItemState();
}

class _CommunityReplyItemState extends State<CommunityReplyItem> {
  late final String _replyId;
  String? get _currentUid =>
      AuthService.to.isAuthenticated.value ? AuthService.to.uid : null;

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
    if (_currentUid == null || !AuthService.to.isAuthenticated.value) {
      _showCommunitySignInPrompt('react to replies');
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
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityPostComments.replyLike.deleteLikeDoc',
                ));
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityPostComments.toggleReplyLike',
      );
    }
  }

  Future<void> _toggleReplyDislike() async {
    if (_currentUid == null || !AuthService.to.isAuthenticated.value) {
      _showCommunitySignInPrompt('react to replies');
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
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityPostComments.replyDislike.deleteLikeDoc',
                ));
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
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityPostComments.replyDislike.deleteDislikeDoc',
                ));
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityPostComments.toggleReplyDislike',
      );
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
                    AppSnackbar.success('Reply saved to Saved Comments');
                  } catch (e, stackTrace) {
                    ErrorHandler.log(
                      e,
                      stackTrace: stackTrace,
                      context: 'CommunityPostComments.saveReply',
                    );
                    AppSnackbar.error('Unable to save reply. Please try again.');
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
                  AppSnackbar.info('Reply copied to clipboard');
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
                    } catch (e, stackTrace) {
                      ErrorHandler.log(
                        e,
                        stackTrace: stackTrace,
                        context: 'CommunityPostComments.deleteReply',
                      );
                      AppSnackbar.error('Unable to delete reply. Please try again.');
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
                    AppSnackbar.info(
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
                                        ? Colors.white
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

