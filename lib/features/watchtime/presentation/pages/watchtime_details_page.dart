import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchtimeDetailsPage extends StatelessWidget {
  const WatchtimeDetailsPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.video,
  });
  final String channelId;
  final bool isDarkMode;
  final Video? video;

  Future<QuerySnapshot> _fetchVideosQuery() {
    final col = FirebaseFirestore.instance.collection(FirestoreCollections.videos);
    if (channelId.isNotEmpty) {
      return col.where('channelId', isEqualTo: channelId).get();
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return col.where('ownerId', isEqualTo: uid).get();
    }
    return col.limit(20).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Watchtime Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.appBarSurface,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _fetchVideosQuery(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return buildShimmerVideoList();
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load watch time details. Please try again later.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          final videos = snapshot.data?.docs ?? [];
          if (videos.isEmpty) {
            return const Center(child: Text('No videos found.'));
          }
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('video_stats')
                    .doc(video.id)
                    .get(),
                builder: (context, statsSnapshot) {
                  if (!statsSnapshot.hasData) {
                    return ListTile(
                      title: Text((video['title'] as String?) ?? 'Untitled'),
                    );
                  }
                  final stats =
                      statsSnapshot.data?.data() as Map<String, dynamic>?;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text((video['title'] as String?) ?? 'Untitled'),
                      subtitle: stats == null
                          ? const Text('No stats available')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Views: \\${stats['totalViews'] ?? 0}',
                                ),
                                Text(
                                  'Unique Users: \\${stats['uniqueUsers'] ?? 0}',
                                ),
                                Text(
                                  'Total Watch Seconds: \\${stats['totalWatchSeconds'] ?? 0}',
                                ),
                                Text(
                                  'Avg Watch Seconds: \\${stats['avgWatchSeconds'] ?? 0}',
                                ),
                                Text(
                                  'Completion Rate: \\${stats['completionRate'] ?? 0}%',
                                ),
                                Text(
                                  'Full Watched: \\${stats['fullWatched'] ?? 0}',
                                ),
                                Text(
                                  'Half Watched: \\${stats['halfWatched'] ?? 0}',
                                ),
                                Text(
                                  'Under 20 Sec: \\${stats['under20Sec'] ?? 0}',
                                ),
                              ],
                            ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
