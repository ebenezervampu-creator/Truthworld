import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';

/// Standardized query builder for constructing Firestore queries with visibility policy.
class VideoQueryBuilder {
  static const String collectionName = 'videos';

  /// Construct base public videos query with optional filters and pagination
  static Query publicVideos(
    FirebaseFirestore firestore, {
    int? limit,
    DocumentSnapshot? startAfter,
    String? category,
    String? topicId,
    String? channelId,
  }) {
    Query query = firestore
        .collection(collectionName)
        .where('status', isEqualTo: VideoVisibilityPolicy.publicStatus.name)
        .where(
          'visibility',
          isEqualTo: VideoVisibilityPolicy.publicVisibilityString,
        )
        .orderBy('uploadedAt', descending: true);

    final isSpecialCategory = category == null ||
        category.isEmpty ||
        category == 'All' ||
        category == 'Subscriptions' ||
        category == '🪙 Flip Coin' ||
        category == 'Posts' ||
        category == '🔥 Trending' ||
        category == 'Trending' ||
        category == '✨ New' ||
        category == 'New' ||
        category == '⭐ Popular' ||
        category == 'Popular';

    if (!isSpecialCategory) {
      query = query.where('category', isEqualTo: category);
    }

    if (topicId != null && topicId.isNotEmpty) {
      query = query.where('topicId', isEqualTo: topicId);
    }

    if (channelId != null && channelId.isNotEmpty) {
      query = query.where('channelId', isEqualTo: channelId);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    return query;
  }
}
