import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_video_loader.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Channel identity header showing avatar and channel/creator name.
class PlaylistChannelInfoWidget extends StatelessWidget {
  const PlaylistChannelInfoWidget({
    required this.playlist,
    super.key,
  });

  final PlaylistModel playlist;

  @override
  Widget build(BuildContext context) {
    if (playlist.channelId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final displayName = user?.displayName?.isNotEmpty == true
          ? user!.displayName!
          : (playlist.ownerId.isNotEmpty ? playlist.ownerId : 'You');
      final photoUrl = user?.photoURL ?? '';

      return Row(
        children: [
          UserAvatar(
            radius: 16,
            photoUrl: photoUrl,
            displayName: displayName,
            backgroundColor: ytSurfaceLight,
            textColor: ytTextSecondary,
            fontSize: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              displayName,
              style: const TextStyle(
                fontSize: 14,
                color: ytTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(playlist.channelId)
          .get(),
      builder: (context, snapshot) {
        var channelName = 'Unknown Channel';
        var avatarUrl = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final channelData = snapshot.data!.data()! as Map<String, dynamic>;
          channelName =
              (channelData['name'] ?? channelData['channelName']) ??
              'Unknown Channel';
          avatarUrl = channelData['avatarUrl'] ?? '';
        }

        return InkWell(
          onTap: () {
            // Channel navigation
          },
          child: Row(
            children: [
              UserAvatar(
                radius: 16,
                photoUrl: avatarUrl,
                displayName: channelName,
                backgroundColor: ytSurfaceLight,
                textColor: ytTextSecondary,
                fontSize: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  channelName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ytTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Statistics line displaying total video count, aggregated views, and last modified date.
class PlaylistStatsWidget extends StatelessWidget {
  const PlaylistStatsWidget({
    required this.playlist,
    super.key,
  });

  final PlaylistModel playlist;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Video>>(
      future: fetchPlaylistVideos(playlist),
      builder: (context, snapshot) {
        final videoCount = snapshot.hasData
            ? snapshot.data!.length
            : (playlist.videoCount > 0
                ? playlist.videoCount
                : playlist.videoIds.length);
        final viewCount = snapshot.hasData
            ? snapshot.data!.fold<int>(0, (total, v) => total + v.views)
            : 0;
        final lastUpdated = timeago.format(playlist.updatedAt.toDate());

        return Text(
          '$videoCount ${videoCount == 1 ? "video" : "videos"} • ${formatPlaylistViews(viewCount)} views • Updated $lastUpdated',
          style: const TextStyle(
            fontSize: 12,
            color: ytTextTertiary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
