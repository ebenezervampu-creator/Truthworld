import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/features/community/presentation/views/widgets/community_post_comments.dart';

/// Community Comments Modal Bottom Sheet
void showCommunityCommentsModal(
  BuildContext context,
  CommunityPostModel post,
  CommunityPostController controller,
) {
  final isSortNewest = false.obs;
  final textController = TextEditingController();
  final commentsStream = controller.commentsStream;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
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
                          stream: commentsStream,
                          builder: (context, snapshot) {
                            final count =
                                snapshot.data?.docs.length ??
                                controller.commentCount.value;
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
                              itemBuilder: (context) => <PopupMenuEntry<bool>>[
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
                                        const Text(
                                          'Top comments',
                                          style: TextStyle(color: Colors.white),
                                        ),
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
                                        const Text(
                                          'Newest first',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.sort_rounded,
                                  color: Colors.white, // Rule compliance: white icon
                                  size: 22,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white, // Rule compliance: white icon
                              ),
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
                      stream: commentsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
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
                              return CommunityCommentItemWidget(
                                postId: post.id,
                                commentData: commentData,
                                currentUid: controller.currentUid,
                                postOwnerId: post.ownerId,
                              );
                            },
                          );
                        });
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  SafeArea(
                    top: false,
                    child: Obx(() {
                      if (!AuthService.to.isAuthenticated.value) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: const Color(0xFF181818),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () => AuthBottomSheet.show(context),
                              icon: const Icon(
                                Icons.login_rounded,
                                size: 16,
                                color: Colors.white, // Rule compliance: white icon
                              ),
                              label: const Text(
                                'Sign in to add a comment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: const Color(0xFF181818),
                        child: Row(
                          children: [
                            UserAvatar(
                              radius: 16,
                              photoUrl: AuthService.to.activePhotoUrl,
                              displayName: AuthService.to.activeDisplayName,
                              fontSize: 11,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: textController,
                                maxLength: defaultMaxCommentLength,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxCommentLength),
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
                                color: Colors.white, // Rule compliance: white icon
                                size: 20,
                              ),
                              onPressed: () async {
                                final text = textController.text.trim();
                                if (text.isEmpty) return;
                                if (!AuthService.to.isAuthenticated.value) {
                                  AppSnackbar.warning(
                                    'Please sign in to comment.',
                                    actionLabel: 'SIGN IN',
                                    onAction: () => AuthBottomSheet.show(context),
                                  );
                                  return;
                                }
                                final uid = AuthService.to.uid;
                                if (uid.isEmpty) return;
                                final validation = ContentValidator.validate(
                                  text,
                                  fieldName: 'Comment',
                                  maxLength: defaultMaxCommentLength,
                                );
                                if (!validation.isValid) {
                                  AppSnackbar.warning(
                                    validation.message,

                                  );
                                  return;
                                }
                                textController.clear();
                                try {
                                  final authService = AuthService.to;
                                  final userAvatar =
                                      authService.activePhotoUrl;
                                  final rawName =
                                      authService.activeDisplayName;
                                  final userName = rawName.startsWith('@')
                                      ? rawName.substring(1)
                                      : rawName;

                                  final postDoc = FirebaseFirestore.instance
                                      .collection(FirestoreCollections.community)
                                      .doc(post.id);
                                  await postDoc.collection('comments').add({
                                    'text': ContentValidator.cleanProfanity(text),
                                    'userId': uid,
                                    'userName': userName,
                                    'userImage': userAvatar,
                                    'userProfilePicUrl': userAvatar,
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
                                  controller.commentCount.value += 1;
                                } catch (e, stackTrace) {
                                  ErrorHandler.log(
                                    e,
                                    stackTrace: stackTrace,
                                    context: 'CommunityPostCard.postComment',
                                  );
                                  AppSnackbar.error(
                                    'Unable to post comment. Please try again.',
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
