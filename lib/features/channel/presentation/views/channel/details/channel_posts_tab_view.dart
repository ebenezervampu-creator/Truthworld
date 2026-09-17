import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';

/// Community posts tab view for Channel Details screen.
class ChannelPostsTabView extends GetView<ChannelController> {
  const ChannelPostsTabView({
    required this.channel,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final Channel channel;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSubscribed = controller.isSubscribed.value;
    final isOwner = currentUser != null && currentUser.uid == channel.ownerId;

    return StreamBuilder<QuerySnapshot>(
      stream: controller.getCommunityStream(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ChannelDetailsStateWidgets.buildShimmerGrid(
            isDesktop: isDesktop,
            isTablet: isTablet,
          );
        }
        if (snapshot.hasError) {
          return ChannelDetailsStateWidgets.buildErrorState(
            'Unable to load posts. Please try again.',
            () => controller.update(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ChannelDetailsStateWidgets.buildEmptyTabState(
            icon: Icons.chat_bubble_outline,
            title: 'Posts',
            subtitle: 'Community posts from this channel will appear here',
          );
        }

        final posts = snapshot.data!.docs
            .map(
              (doc) => CommunityPostModel.fromMap(
                doc.data()! as Map<String, dynamic>,
              ),
            )
            .where((post) {
              if (isOwner) return true;
              final vis = post.visibility.toLowerCase();
              if (vis == 'public') return true;
              if (vis == 'subscribers' && isSubscribed) return true;
              if (vis == 'members' && (isOwner || isSubscribed)) return true;
              return false;
            })
            .toList();

        // Sort posts by uploadedAt descending
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        if (posts.isEmpty) {
          return ChannelDetailsStateWidgets.buildEmptyTabState(
            icon: Icons.chat_bubble_outline,
            title: 'Posts',
            subtitle: 'Community posts from this channel will appear here',
          );
        }

        final horizontalPadding = isDesktop ? 64.0 : (isTablet ? 32.0 : 12.0);
        final maxContentWidth = isDesktop
            ? 720.0
            : (isTablet ? 600.0 : double.infinity);

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return CommunityPostCard(
                  post: posts[index],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
