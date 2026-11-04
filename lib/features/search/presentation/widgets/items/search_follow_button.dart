import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Realtime Follow Button for Topic cards.
class FollowButton extends StatelessWidget {
  const FollowButton({
    required this.topicId,
    String? topicName,
    String? topicTitle,
    this.videoCount = 0,
    super.key,
  }) : topicName = (topicName != null && topicName != '')
            ? topicName
            : (topicTitle ?? '');

  final String topicId;
  final String topicName;
  String get topicTitle => topicName;
  final int videoCount;
  static final Set<String> _pendingTopicIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = context.twColors;
    final typography = context.twTypography;
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    return Obx(() {
      final isFollowing = followingController.isTopicFollowed(topicId);
      return Material(
        color: isFollowing
            ? colors.textPrimary.withValues(alpha: 0.1)
            : colors.brand,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () async {
            if (_pendingTopicIds.contains(topicId)) return;

            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              AppSnackbar.warning(
                'Please sign in to follow topics.',
              );
              return;
            }

            _pendingTopicIds.add(topicId);
            try {
              var finalCount = videoCount;
              if (finalCount <= 0 && !isFollowing) {
                try {
                  final doc = await FirebaseFirestore.instance
                      .collection(FirestoreCollections.topics)
                      .doc(topicId)
                      .get();
                  if (doc.exists) {
                    final data = doc.data();
                    finalCount = (data?['videoCount'] as num?)?.toInt() ??
                        (data?['featuredVideoIds'] as List?)?.length ??
                        0;
                  }
                } catch (e, s) {
                  ErrorHandler.log(
                    e,
                    stackTrace: s,
                    tag: 'TopicCard.fetchTopicCount',
                  );
                }
              }

              if (finalCount <= 0 && !isFollowing) {
                AppSnackbar.info(
                  'This topic has no videos.',
                );
                return;
              }

              final slug = topicName.toLowerCase().replaceAll(' ', '-');
              final topic = Topic(
                id: topicId,
                name: topicName,
                title: topicName,
                slug: slug,
                handle: slug,
                handleLowercase: slug.toLowerCase(),
                description: '',
                category: 'General',
                videoCount: finalCount > 0 ? finalCount : 1,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await followingController.toggleFollowTopic(topic);
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'FollowButton.onTap',
              );
            } finally {
              _pendingTopicIds.remove(topicId);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: isFollowing
                  ? Border.all(
                      color: colors.textPrimary.withValues(alpha: 0.2),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: typography.label.copyWith(
                color: isFollowing ? colors.textPrimary : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    });
  }
}
