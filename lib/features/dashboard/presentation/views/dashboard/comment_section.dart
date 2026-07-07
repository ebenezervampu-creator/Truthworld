import 'package:truthworld/theme/app_theme.dart';
// studio_comments_module.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:timeago/timeago.dart' as timeago;

// ------------------------------------------------------------
// MODELS
// ------------------------------------------------------------

class Comment {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final Timestamp createdAt;
  final int likeCount;
  final int dislikeCount;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final Timestamp? hiddenUntil;
  bool hasCreatorReply;
  Reply? creatorReply;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
    this.hiddenUntil,
    this.hasCreatorReply = false,
    this.creatorReply,
  });

  factory Comment.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      text: _stringFrom(data['text']),
      userId: _stringFrom(data['userId']),
      userName: _stringFrom(data['userName']),
      userProfilePicUrl: _stringFrom(data['userProfilePicUrl']),
      createdAt: _timestampFrom(data['createdAt']) ?? Timestamp.now(),
      likeCount: _intFrom(data['likeCount']),
      dislikeCount: _intFrom(data['dislikeCount']),
      likedBy: (data['likedBy'] as List<dynamic>?)?.cast<String>() ?? [],
      dislikedBy: (data['dislikedBy'] as List<dynamic>?)?.cast<String>() ?? [],
      hiddenUntil: _timestampFrom(data['hiddenUntil']),
    );
  }

  Comment copyWith({bool? hasCreatorReply, Reply? creatorReply}) {
    return Comment(
      id: id,
      text: text,
      userId: userId,
      userName: userName,
      userProfilePicUrl: userProfilePicUrl,
      createdAt: createdAt,
      likeCount: likeCount,
      dislikeCount: dislikeCount,
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      hiddenUntil: hiddenUntil,
      hasCreatorReply: hasCreatorReply ?? this.hasCreatorReply,
      creatorReply: creatorReply ?? this.creatorReply,
    );
  }
}

class Reply {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final Timestamp createdAt;

  Reply({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.createdAt,
  });

  factory Reply.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reply(
      id: doc.id,
      text: _stringFrom(data['text']),
      userId: _stringFrom(data['userId']),
      userName: _stringFrom(data['userName']),
      userProfilePicUrl: _stringFrom(data['userProfilePicUrl']),
      createdAt: _timestampFrom(data['createdAt']) ?? Timestamp.now(),
    );
  }
}

class VideoComment {
  final String videoId;
  final String videoTitle;
  final String videoThumbnail;
  final Comment comment;
  final int totalReplyCount;

  VideoComment({
    required this.videoId,
    required this.videoTitle,
    required this.videoThumbnail,
    required this.comment,
    required this.totalReplyCount,
  });
}

// ------------------------------------------------------------
// HELPER PARSING FUNCTIONS
// ------------------------------------------------------------

String _stringFrom(dynamic val) {
  if (val == null) return '';
  if (val is String) return val;
  if (val is num) return val.toString();
  try {
    return val.toString();
  } catch (_) {
    return '';
  }
}

int _intFrom(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  if (val is String) return int.tryParse(val) ?? 0;
  return 0;
}

Timestamp? _timestampFrom(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val;
  if (val is DateTime) return Timestamp.fromDate(val);
  return null;
}

// ------------------------------------------------------------
// STUDIO COMMENTS CONTROLLER
// ------------------------------------------------------------

class StudioCommentsController extends GetxController {
  final String channelId;
  final String channelImageUrl;
  final String channelName;

  StudioCommentsController({
    required this.channelId,
    required this.channelImageUrl,
    required this.channelName,
    String initialSearchQuery = '',
  }) {
    if (initialSearchQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchQuery.value = initialSearchQuery;
      });
    }
  }

  final comments = <VideoComment>[].obs;
  final isLoading = true.obs;
  final selectedFilter = 'all'.obs;
  final selectedSort = 'newest'.obs;
  final searchQuery = ''.obs;
  final expandedCommentIds = <String>{}.obs;
  final userCommentInteractions = <String, Map<String, bool>>{}.obs;

  Future<void> _loadUserInteractions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('comment_interactions')
          .get();
      for (var doc in snap.docs) {
        final data = doc.data();
        final type = data['type'];
        userCommentInteractions[doc.id] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }
    } catch (e) {
      debugPrint('Failed to load user interactions: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadUserInteractions().then((_) => _loadComments());
  }

  Future<void> _loadComments() async {
    try {
      isLoading.value = true;
      comments.clear();

      final videosSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .get();

      if (videosSnapshot.docs.isEmpty) {
        comments.value = [];
        return;
      }

      List<VideoComment> allComments = [];

      final List<Future<void>> fetches = videosSnapshot.docs.map((
        videoDoc,
      ) async {
        final videoData = videoDoc.data();

        final commentsSnapshot = await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoDoc.id)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          Comment comment = Comment.fromDocumentSnapshot(commentDoc);

          // Skip hidden comments
          if (comment.hiddenUntil != null &&
              comment.hiddenUntil!.toDate().isAfter(DateTime.now())) {
            continue;
          }

          bool hasCreatorReply = false;
          Reply? creatorReply;
          int totalReplyCount = 0;

          try {
            final repliesSnap = await commentDoc.reference
                .collection('replies')
                .get();
            totalReplyCount = repliesSnap.docs.length;

            final creatorReplies = repliesSnap.docs.where((doc) {
              final data = doc.data();
              return _stringFrom(data['userId']) == channelId;
            }).toList();

            if (creatorReplies.isNotEmpty) {
              hasCreatorReply = true;
              creatorReply = Reply.fromDocumentSnapshot(creatorReplies.first);
            }
          } catch (e) {
            debugPrint('Error fetching replies: $e');
          }

          comment = comment.copyWith(
            hasCreatorReply: hasCreatorReply,
            creatorReply: creatorReply,
          );

          allComments.add(
            VideoComment(
              videoId: videoDoc.id,
              videoTitle: _stringFrom(videoData['title'] ?? 'Untitled'),
              videoThumbnail: _stringFrom(videoData['thumbnail'] ?? ''),
              comment: comment,
              totalReplyCount: totalReplyCount,
            ),
          );
        }
      }).toList();

      await Future.wait(fetches);
      comments.value = allComments;
    } catch (e) {
      debugPrint('Error loading comments: $e');
      Get.snackbar('Error', 'Failed to load comments');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleLike(String videoId, String commentId, bool isLike) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final currentStatus = userCommentInteractions[commentId];
    final wasLiked = currentStatus?['isLiked'] ?? false;
    final wasDisliked = currentStatus?['isDisliked'] ?? false;

    try {
      if (isLike) {
        if (wasLiked) {
          userCommentInteractions[commentId] = {
            'isLiked': false,
            'isDisliked': false,
          };
          await CommentService().removeCommentInteraction(
            videoId: videoId,
            commentId: commentId,
            userId: userId,
          );
        } else {
          userCommentInteractions[commentId] = {
            'isLiked': true,
            'isDisliked': false,
          };
          await CommentService().likeComment(
            videoId: videoId,
            commentId: commentId,
            userId: userId,
            asChannel: true,
          );
        }
      } else {
        if (wasDisliked) {
          userCommentInteractions[commentId] = {
            'isLiked': false,
            'isDisliked': false,
          };
          await CommentService().removeCommentInteraction(
            videoId: videoId,
            commentId: commentId,
            userId: userId,
          );
        } else {
          userCommentInteractions[commentId] = {
            'isLiked': false,
            'isDisliked': true,
          };
          await CommentService().dislikeComment(
            videoId: videoId,
            commentId: commentId,
            userId: userId,
            asChannel: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to toggle comment interaction: $e');
    }

    await _loadComments();
  }

  Future<void> addReply(String videoId, String commentId, String text) async {
    if (text.trim().isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc();

    await ref.set({
      'text': text,
      'userId': channelId,
      'userName': channelName,
      'userProfilePicUrl': channelImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _loadComments();
  }

  Future<void> deleteComment(String videoId, String commentId) async {
    await FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .delete();

    await _loadComments();
  }

  Future<void> hideComment(
    String videoId,
    String commentId,
    DateTime until,
  ) async {
    await FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .update({'hiddenUntil': Timestamp.fromDate(until)});

    await _loadComments();
  }

  void toggleCommentExpansion(String commentId) {
    if (expandedCommentIds.contains(commentId)) {
      expandedCommentIds.remove(commentId);
    } else {
      expandedCommentIds.add(commentId);
    }
  }

  List<VideoComment> get filteredComments {
    List<VideoComment> filtered = List.from(comments);

    // Filter
    if (selectedFilter.value == 'unanswered') {
      filtered = filtered.where((c) => !c.comment.hasCreatorReply).toList();
    } else if (selectedFilter.value == 'answered') {
      filtered = filtered.where((c) => c.comment.hasCreatorReply).toList();
    } else if (selectedFilter.value == 'questions') {
      filtered = filtered.where((c) => c.comment.text.contains('?')).toList();
    }

    // Search
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered
          .where(
            (vc) =>
                vc.comment.text.toLowerCase().contains(query) ||
                vc.comment.userName.toLowerCase().contains(query) ||
                vc.videoTitle.toLowerCase().contains(query),
          )
          .toList();
    }

    // Sort
    if (selectedSort.value == 'oldest') {
      filtered.sort(
        (a, b) => a.comment.createdAt.compareTo(b.comment.createdAt),
      );
    } else if (selectedSort.value == 'popular') {
      filtered.sort(
        (a, b) => b.comment.likeCount.compareTo(a.comment.likeCount),
      );
    } else {
      filtered.sort(
        (a, b) => b.comment.createdAt.compareTo(a.comment.createdAt),
      );
    }

    return filtered;
  }

  int get unansweredCount =>
      comments.where((c) => !c.comment.hasCreatorReply).length;
  int get answeredCount =>
      comments.where((c) => c.comment.hasCreatorReply).length;
  int get questionsCount =>
      comments.where((c) => c.comment.text.contains('?')).length;
}

// ------------------------------------------------------------
// REPLY CONTROLLER
// ------------------------------------------------------------

class ReplyController extends GetxController {
  final String videoId;
  final String commentId;
  final String channelId;

  ReplyController({
    required this.videoId,
    required this.commentId,
    required this.channelId,
  });

  final replies = <Reply>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    try {
      isLoading.value = true;
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt')
          .get();

      replies.value = snapshot.docs
          .map((doc) => Reply.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading replies: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateReply(String replyId, String newText) async {
    if (newText.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .update({'text': newText});
    await _loadReplies();
  }

  Future<void> deleteReply(String replyId) async {
    await FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .delete();
    await _loadReplies();
  }
}

// ------------------------------------------------------------
// MAIN SCREEN
// ------------------------------------------------------------

class StudioCommentsScreen extends StatefulWidget {
  final String channelId;
  final String channelImageUrl;
  final String channelName;
  final String searchQuery;

  const StudioCommentsScreen({
    super.key,
    required this.channelId,
    required this.channelImageUrl,
    required this.channelName,
    this.searchQuery = '',
  });

  @override
  State<StudioCommentsScreen> createState() => _StudioCommentsScreenState();
}

class _StudioCommentsScreenState extends State<StudioCommentsScreen> {
  late StudioCommentsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      StudioCommentsController(
        channelId: widget.channelId,
        channelImageUrl: widget.channelImageUrl,
        channelName: widget.channelName,
        initialSearchQuery: widget.searchQuery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgPage,
        cardColor: const Color(0xFF1F1F1F),
        primaryColor: AppColors.textLink,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgPage,
          elevation: 0,
          title: Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Obx(
                () => DropdownButton<String>(
                  value: controller.selectedSort.value,
                  items: ['newest', 'oldest', 'popular']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.capitalizeFirst!),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      v != null ? controller.selectedSort.value = v : null,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort, color: Colors.white),
                  dropdownColor: const Color(0xFF1F1F1F),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: _FilterChip(
                        label: 'All',
                        count: controller.comments.length,
                        isSelected: controller.selectedFilter.value == 'all',
                        onTap: () => controller.selectedFilter.value = 'all',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterChip(
                        label: 'Unanswered',
                        count: controller.unansweredCount,
                        isSelected:
                            controller.selectedFilter.value == 'unanswered',
                        onTap: () =>
                            controller.selectedFilter.value = 'unanswered',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterChip(
                        label: 'Answered',
                        count: controller.answeredCount,
                        isSelected:
                            controller.selectedFilter.value == 'answered',
                        onTap: () =>
                            controller.selectedFilter.value = 'answered',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterChip(
                        label: 'Questions',
                        count: controller.questionsCount,
                        isSelected:
                            controller.selectedFilter.value == 'questions',
                        onTap: () =>
                            controller.selectedFilter.value = 'questions',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.textLink),
            );
          }

          final filtered = controller.filteredComments;
          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 80,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.selectedFilter.value == 'unanswered'
                        ? 'No unanswered comments'
                        : controller.selectedFilter.value == 'answered'
                        ? 'No answered comments'
                        : controller.selectedFilter.value == 'questions'
                        ? 'No questions'
                        : 'No comments yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller._loadComments,
            color: AppColors.textLink,
            child: ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => CommentCard(
                videoComment: filtered[i],
                controller: controller,
                channelImageUrl: widget.channelImageUrl,
                channelName: widget.channelName,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ------------------------------------------------------------
// FILTER CHIP
// ------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textLink : AppColors.bgSurfaceHover,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black26 : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// COMMENT CARD
// ------------------------------------------------------------

class CommentCard extends StatelessWidget {
  final VideoComment videoComment;
  final StudioCommentsController controller;
  final String channelImageUrl;
  final String channelName;

  const CommentCard({
    super.key,
    required this.videoComment,
    required this.controller,
    required this.channelImageUrl,
    required this.channelName,
  });

  void _showReplySheet(BuildContext context) {
    final textController = TextEditingController();
    showBottomSheet(
      context: context,
      builder: (_) => Container(
        color: const Color(0xFF1F1F1F),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.textLink),
              onPressed: () async {
                await controller.addReply(
                  videoComment.videoId,
                  videoComment.comment.id,
                  textController.text,
                );
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hide comment for'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('1 hour'),
              onTap: () => _hide(const Duration(hours: 1)),
            ),
            ListTile(
              title: const Text('24 hours'),
              onTap: () => _hide(const Duration(hours: 24)),
            ),
            ListTile(
              title: const Text('2 days'),
              onTap: () => _hide(const Duration(days: 2)),
            ),
            ListTile(
              title: const Text('7 days'),
              onTap: () => _hide(const Duration(days: 7)),
            ),
            ListTile(
              title: const Text('Permanent'),
              onTap: () => _hide(const Duration(days: 3650)),
            ),
          ],
        ),
      ),
    );
  }

  void _hide(Duration duration) {
    controller.hideComment(
      videoComment.videoId,
      videoComment.comment.id,
      DateTime.now().add(duration),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final comment = videoComment.comment;
      final isExpanded = controller.expandedCommentIds.contains(comment.id);
      final hasLiked = controller.userCommentInteractions[comment.id]?['isLiked'] ?? false;
      final hasDisliked = controller.userCommentInteractions[comment.id]?['isDisliked'] ?? false;

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: comment.hasCreatorReply
                ? AppColors.textLink.withValues(alpha: 0.3)
                : const Color(0xFF2F2F2F),
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video header
          Container(
            padding: EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF171717),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    videoComment.videoThumbnail,
                    width: 60,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF2F2F2F),
                      child: const Icon(Icons.video_library),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    videoComment.videoTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (comment.hasCreatorReply)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textLink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.textLink),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.textLink,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Replied',
                          style: TextStyle(
                            color: AppColors.textLink,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') {
                      controller.deleteComment(
                        videoComment.videoId,
                        comment.id,
                      );
                    }
                    if (v == 'hide') _showHideDialog(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete comment'),
                    ),
                    PopupMenuItem(value: 'hide', child: Text('Hide from list')),
                  ],
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                ),
              ],
            ),
          ),

          // Comment body
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(comment.userProfilePicUrl),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.userName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            timeago.format(comment.createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    InkWell(
                      onTap: () => controller.toggleLike(
                        videoComment.videoId,
                        comment.id,
                        true,
                      ),
                      child: _StatItem(
                        icon: hasLiked
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        count: comment.likeCount,
                        color: hasLiked
                            ? AppColors.textLink
                            : Colors.grey[400]!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => controller.toggleLike(
                        videoComment.videoId,
                        comment.id,
                        false,
                      ),
                      child: _StatItem(
                        icon: hasDisliked
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
                        count: comment.dislikeCount,
                        color: hasDisliked
                            ? AppColors.textLink
                            : Colors.grey[400]!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _StatItem(
                      icon: Icons.comment_outlined,
                      count: videoComment.totalReplyCount,
                      color: Colors.grey[400]!,
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _showReplySheet(context),
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: AppColors.textLink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (videoComment.totalReplyCount > 0)
                      InkWell(
                        onTap: () =>
                            controller.toggleCommentExpansion(comment.id),
                        child: Row(
                          children: [
                            Text(
                              isExpanded ? 'Hide' : 'View',
                              style: TextStyle(
                                color: AppColors.textLink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: AppColors.textLink,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Creator reply preview
          if (comment.hasCreatorReply && comment.creatorReply != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textLink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.textLink.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(channelImageUrl),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.creatorReply!.userName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.textLink,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'CREATOR',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          comment.creatorReply!.text,
                          style: TextStyle(
                            color: Colors.grey[200],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(
                            comment.creatorReply!.createdAt.toDate(),
                          ),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.push_pin,
                    color: AppColors.textLink,
                    size: 16,
                  ),
                ],
              ),
            ),

          // Replies (using GetX to avoid setState during build)
          if (isExpanded)
            GetX<ReplyController>(
              tag: comment.id,
              init: ReplyController(
                videoId: videoComment.videoId,
                commentId: comment.id,
                channelId: controller.channelId,
              ),
              builder: (replyCtrl) {
                if (replyCtrl.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textLink,
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF171717),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    itemCount: replyCtrl.replies.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Color(0xFF2F2F2F), height: 24),
                    itemBuilder: (_, i) {
                      final reply = replyCtrl.replies[i];
                      final isCreator = reply.userId == controller.channelId;
                      return ReplyCard(
                        reply: reply,
                        isCreator: isCreator,
                        channelImageUrl: channelImageUrl,
                        replyController: replyCtrl,
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
    });
  }
}

// ------------------------------------------------------------
// STAT ITEM
// ------------------------------------------------------------

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.count,
    required this.color,
  });

  String _format(int n) => n >= 1000000
      ? '${(n / 1000000).toStringAsFixed(1)}M'
      : n >= 1000
      ? '${(n / 1000).toStringAsFixed(1)}K'
      : '$n';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(_format(count), style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

// ------------------------------------------------------------
// REPLY CARD
// ------------------------------------------------------------

class ReplyCard extends StatelessWidget {
  final Reply reply;
  final bool isCreator;
  final String channelImageUrl;
  final ReplyController replyController;

  const ReplyCard({
    super.key,
    required this.reply,
    required this.isCreator,
    required this.channelImageUrl,
    required this.replyController,
  });

  void _edit(BuildContext context) {
    final ctrl = TextEditingController(text: reply.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit reply'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Edit text'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              replyController.updateReply(reply.id, ctrl.text);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 2,
          height: 40,
          color: isCreator ? AppColors.textLink : AppColors.bgElevated,
          margin: EdgeInsets.only(right: 12),
        ),
        CircleAvatar(
          radius: 14,
          backgroundImage: NetworkImage(
            isCreator ? channelImageUrl : reply.userProfilePicUrl,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reply.userName,
                    style: TextStyle(
                      color: isCreator ? AppColors.textLink : Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (isCreator) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.textLink,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'CREATOR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isCreator)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          _edit(context);
                        }
                        if (v == 'delete') {
                          replyController.deleteReply(reply.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      icon: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                reply.text,
                style: TextStyle(color: Colors.grey[200], fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                timeago.format(reply.createdAt.toDate()),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}







