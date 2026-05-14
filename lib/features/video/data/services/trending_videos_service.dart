import 'package:cloud_firestore/cloud_firestore.dart';

class TrendingVideosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getTrendingVideos() async {
    QuerySnapshot snapshot = await _firestore
        .collection('videos')
        .where('visibility', isEqualTo: 'Public')
        .where('status', isEqualTo: 'published')
        .orderBy('views', descending: true) // Start by sorting by views
        .limit(20) // Limit to top 20 videos
        .get();

    List<Map<String, dynamic>> videos = snapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;

      // Extract engagement metrics
      int views = data['views'] ?? 0;
      int likes = data['likes'] ?? 0;
      int comments = data['comments'] ?? 0;
      DateTime timestamp = (data['timestamp'] as Timestamp).toDate();

      // Calculate recency weight (newer videos get higher scores)
      int daysOld =
          DateTime.now().difference(timestamp).inDays +
          1; // Avoid division by zero
      double recencyWeight = 1 / daysOld; // More w eight for newer videos

      // Trending Score Formula
      double trendingScore =
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





