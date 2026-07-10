import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';

class WatchtimeDetailsPage extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;
  final Video? video;

  const WatchtimeDetailsPage({
    super.key,
    required this.channelId,
    required this.isDarkMode,
    this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      appBar: AppBar(
        title: Text('Watchtime Details'),
        backgroundColor: isDarkMode ? AppColors.textPrimary : Colors.white,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return buildShimmerVideoList(count: 6);
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final videos = snapshot.data?.docs ?? [];
          if (videos.isEmpty) {
            return Center(child: Text('No videos found.'));
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
                    return ListTile(title: Text(video['title'] ?? 'Untitled'));
                  }
                  final stats = statsSnapshot.data?.data() as Map<String, dynamic>?;
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(video['title'] ?? 'Untitled'),
                      subtitle: stats == null
                          ? Text('No stats available')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Views: \\${stats['totalViews'] ?? 0}'),
                                Text('Unique Users: \\${stats['uniqueUsers'] ?? 0}'),
                                Text('Total Watch Seconds: \\${stats['totalWatchSeconds'] ?? 0}'),
                                Text('Avg Watch Seconds: \\${stats['avgWatchSeconds'] ?? 0}'),
                                Text('Completion Rate: \\${stats['completionRate'] ?? 0}%'),
                                Text('Full Watched: \\${stats['fullWatched'] ?? 0}'),
                                Text('Half Watched: \\${stats['halfWatched'] ?? 0}'),
                                Text('Under 20 Sec: \\${stats['under20Sec'] ?? 0}'),
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






