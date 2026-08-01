import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrendingVideosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getTrendingVideos() async {
    final QuerySnapshot snapshot = await _firestore
        .collection(FirestoreCollections.videos)
        .where('visibility', isEqualTo: 'Public')
        .where('status', isEqualTo: 'published')
        .orderBy('views', descending: true) // Start by sorting by views
        .limit(20) // Limit to top 20 videos
        .get();

    final videos = snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;

      // Extract engagement metrics
      final int views = data['views'] ?? 0;
      final int likes = data['likes'] ?? 0;
      final int comments = data['comments'] ?? 0;
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      // Calculate recency weight (newer videos get higher scores)
      final daysOld =
          DateTime.now().difference(timestamp).inDays +
          1; // Avoid division by zero
      final recencyWeight = 1 / daysOld; // More w eight for newer videos

      // Trending Score Formula
      final trendingScore =
          (views * 0.5) +
          (likes * 0.3) +
          (comments * 0.2) +
          (recencyWeight * 100);

      return {...data, 'trendingScore': trendingScore};
    }).toList();

    // Sort videos by trending score in descending order
    videos.sort((a, b) => b['trendingScore'].compareTo(a['trendingScore']));

    return videos;
  }
}
