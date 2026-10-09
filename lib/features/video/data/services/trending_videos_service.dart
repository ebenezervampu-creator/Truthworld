import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

class TrendingVideosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getTrendingVideos({int limit = 30}) async {
    final QuerySnapshot snapshot = await _firestore
        .collection(FirestoreCollections.videos)
        .where('status', isEqualTo: VideoVisibilityPolicy.publicStatus.name)
        .where(
          'visibility',
          isEqualTo: VideoVisibilityPolicy.publicVisibilityString,
        )
        .orderBy('views', descending: true)
        .limit(limit)
        .get();

    final videos = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data()! as Map);
      data['id'] = doc.id;

      // Extract engagement metrics
      final views = (data['views'] as num?)?.toInt() ?? (data['viewCount'] as num?)?.toInt() ?? 0;
      final likes = (data['likes'] as num?)?.toInt() ?? (data['likeCount'] as num?)?.toInt() ?? 0;
      final comments = (data['comments'] as num?)?.toInt() ?? (data['commentCount'] as num?)?.toInt() ?? 0;
      
      final rawDate = data['uploadedAt'] ?? data['createdAt'] ?? data['publishedAt'] ?? data['timestamp'];
      final date = TimestampUtils.parse(rawDate).toDate();

      // Calculate recency weight (newer videos get higher scores)
      final daysOld = DateTime.now().difference(date).inDays + 1; // Avoid division by zero
      final recencyWeight = 1.0 / daysOld;

      // Credibility Multiplier based on verified trustScore
      final trustScore = (data['trustScore'] as num?)?.toDouble() ?? 0.0;
      final double credibilityMultiplier;
      if (trustScore >= 4.0) {
        credibilityMultiplier = 1.25;
      } else if (trustScore >= 3.0) {
        credibilityMultiplier = 1.15;
      } else if (trustScore >= 2.0) {
        credibilityMultiplier = 1.0;
      } else if (trustScore <= 0.0) {
        credibilityMultiplier = 0.90; // Fair baseline for unverified content
      } else if (trustScore >= 1.0) {
        credibilityMultiplier = 0.50; // Demote low credibility
      } else {
        credibilityMultiplier = 0.20; // Heavily demote false content (< 1.0)
      }

      // Base engagement score
      final baseEngagement =
          (views * 0.5) +
          (likes * 0.3) +
          (comments * 0.2) +
          (recencyWeight * 100);

      // Credibility-aware Trending Score Formula
      final trendingScore = baseEngagement * credibilityMultiplier;

      return {...data, 'trendingScore': trendingScore};
    }).toList();

    // Sort videos by trending score in descending order
    videos.sort((a, b) => (b['trendingScore'] as num).compareTo(a['trendingScore'] as num));

    return videos;
  }
}
