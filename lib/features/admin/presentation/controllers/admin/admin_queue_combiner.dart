import 'package:cloud_firestore/cloud_firestore.dart';

/// Aggregator and normalizer for multi-source administrative review queues.
class AdminQueueCombiner {
  /// Safely parse dynamic timestamps (Firestore Timestamp, ISO String, int, DateTime)
  static DateTime parseTimestamp(dynamic time) {
    if (time == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (time is Timestamp) return time.toDate();
    if (time is DateTime) return time;
    if (time is int) return DateTime.fromMillisecondsSinceEpoch(time);
    return DateTime.tryParse(time.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Combine flagged images, verification queue, community posts, and playlist thumbnails
  static List<Map<String, dynamic>> combineImagesAndPosts({
    required List<Map<String, dynamic>> rawFlaggedImages,
    required List<Map<String, dynamic>> rawVerificationQueue,
    required List<Map<String, dynamic>> rawCommunityPosts,
    required List<Map<String, dynamic>> rawPlaylistThumbnails,
  }) {
    final combinedMap = <String, Map<String, dynamic>>{};

    void addItem(Map<String, dynamic> rawItem,
        {String defaultCategory = 'Image'}) {
      final id = (rawItem['id'] ??
              rawItem['docId'] ??
              rawItem['verificationId'] ??
              '')
          .toString();
      if (id.isEmpty) return;

      final item = Map<String, dynamic>.from(rawItem);
      final rawCat = (item['category'] ?? '').toString().toLowerCase();
      final path = (item['filePath'] ??
              item['gcsUri'] ??
              item['path'] ??
              '')
          .toString()
          .toLowerCase();

      // NEVER allow topic items inside images queue
      if (rawCat.contains('topic') || path.contains('topics')) {
        return;
      }

      // Normalize category names
      if (rawCat.contains('banner') || path.contains('banners')) {
        item['category'] = 'Channel Banner';
      } else if (rawCat.contains('avatar') || path.contains('avatars')) {
        item['category'] = 'Channel Avatar';
      } else if (rawCat.contains('playlist') || path.contains('playlists')) {
        item['category'] = 'Playlist Thumbnail';
      } else if (rawCat.contains('community') || path.contains('community')) {
        item['category'] = 'Community Post';
      } else if (rawCat.contains('thumbnail') || path.contains('thumbnails')) {
        item['category'] = 'Video Thumbnail';
      } else if (item['category'] == null ||
          item['category'].toString().isEmpty) {
        item['category'] = defaultCategory;
      }

      combinedMap[id] = item;
    }

    for (final item in rawFlaggedImages) {
      addItem(item, defaultCategory: 'Flagged Image');
    }
    for (final item in rawVerificationQueue) {
      addItem(item, defaultCategory: 'Image Verification');
    }
    for (final item in rawCommunityPosts) {
      addItem(item, defaultCategory: 'Community Post');
    }
    for (final item in rawPlaylistThumbnails) {
      final hasThumb = (item['thumbnailUrl'] ??
              item['coverImage'] ??
              item['imageUrl'] ??
              '')
          .toString()
          .isNotEmpty;
      if (hasThumb) {
        addItem(item, defaultCategory: 'Playlist Thumbnail');
      }
    }

    final combined = combinedMap.values.toList();
    combined.sort((a, b) {
      final timeA = a['flaggedAt'] ??
          a['createdAt'] ??
          a['timestamp'] ??
          a['updatedAt'];
      final timeB = b['flaggedAt'] ??
          b['createdAt'] ??
          b['timestamp'] ??
          b['updatedAt'];
      final dtA = parseTimestamp(timeA);
      final dtB = parseTimestamp(timeB);
      return dtB.compareTo(dtA);
    });

    return combined;
  }

  /// Combine reports from multiple collections and synthesize reports from flagged videos
  static List<Map<String, dynamic>> combineReports({
    required List<Map<String, dynamic>> rawReportsDocs,
    required List<Map<String, dynamic>> rawVideoReportsDocs,
    required List<Map<String, dynamic>> rawVideoReportsAltDocs,
    required List<Map<String, dynamic>> videos,
  }) {
    final combinedMap = <String, Map<String, dynamic>>{};

    for (final item in rawReportsDocs) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty) combinedMap[id] = item;
    }

    for (final item in rawVideoReportsDocs) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty && !combinedMap.containsKey(id)) {
        combinedMap[id] = item;
      }
    }

    for (final item in rawVideoReportsAltDocs) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty && !combinedMap.containsKey(id)) {
        combinedMap[id] = item;
      }
    }

    // Also include reported/flagged videos from video queue
    for (final v in videos) {
      final vId = (v['id'] ?? '').toString();
      final isRep = v['isReported'] == true ||
          v['flagged'] == true ||
          v['status'] == 'reported' ||
          (v['reportsCount'] is num && (v['reportsCount'] as num) > 0) ||
          (v['reportCount'] is num && (v['reportCount'] as num) > 0);

      if (isRep && vId.isNotEmpty) {
        final synthId = 'reported_video_$vId';
        if (!combinedMap.containsKey(synthId) &&
            !combinedMap.values.any((r) => r['videoId'] == vId)) {
          combinedMap[synthId] = {
            'id': synthId,
            'videoId': vId,
            'channelId': v['channelId'] ?? '',
            'type': 'video',
            'status': v['moderation']?['status'] == 'rejected'
                ? 'resolved_rejected'
                : 'pending',
            'reason':
                v['reportReason'] ?? v['reason'] ?? 'User Reported Video',
            'comment': v['reportComment'] ??
                v['comment'] ??
                'Reported directly on video queue',
            'userEmail':
                v['reporterEmail'] ?? v['userEmail'] ?? 'Community User',
            'createdAt': v['createdAt'] ??
                v['updatedAt'] ??
                FieldValue.serverTimestamp(),
          };
        }
      }
    }

    final combined = combinedMap.values.toList();
    combined.sort((a, b) {
      final timeA = a['createdAt'] ?? a['timestamp'] ?? a['reportedAt'];
      final timeB = b['createdAt'] ?? b['timestamp'] ?? b['reportedAt'];
      final dtA = parseTimestamp(timeA);
      final dtB = parseTimestamp(timeB);
      return dtB.compareTo(dtA);
    });

    return combined;
  }

  /// Combine rejected image audit records and admin actions logs
  static List<Map<String, dynamic>> combineAuditLogs({
    required List<Map<String, dynamic>> rawRejectedImageLogs,
    required List<Map<String, dynamic>> rawActionLogs,
  }) {
    final combined = <Map<String, dynamic>>[];

    for (final raw in rawRejectedImageLogs) {
      final item = Map<String, dynamic>.from(raw);
      item['logType'] = 'rejected_image';
      item['displayType'] = 'Image Quarantine';
      item['action'] = item['action'] ?? 'Quarantine Image';
      item['actor'] = item['actor'] ?? item['adminEmail'] ?? 'Automated / Admin';
      item['target'] = item['originalPath'] ??
          item['quarantinePath'] ??
          item['userId'] ??
          'Image';
      item['timestamp'] =
          item['rejectedAt'] ?? item['timestamp'] ?? item['createdAt'];
      combined.add(item);
    }

    for (final raw in rawActionLogs) {
      final item = Map<String, dynamic>.from(raw);
      item['logType'] = 'admin_action';
      item['displayType'] = 'Admin Action';
      item['action'] = (item['action'] ?? 'Admin Action')
          .toString()
          .replaceAll('_', ' ')
          .toUpperCase();
      item['actor'] = item['adminEmail'] ?? item['adminId'] ?? 'Admin';
      item['target'] = item['userId'] ??
          item['targetId'] ??
          item['videoId'] ??
          (item['itemCount'] != null ? '${item['itemCount']} items' : 'System');
      item['timestamp'] = item['timestamp'] ?? item['createdAt'];
      combined.add(item);
    }

    combined.sort((a, b) {
      final timeA = a['timestamp'] ?? a['rejectedAt'] ?? a['createdAt'];
      final timeB = b['timestamp'] ?? b['rejectedAt'] ?? b['createdAt'];
      final dtA = parseTimestamp(timeA);
      final dtB = parseTimestamp(timeB);
      return dtB.compareTo(dtA);
    });

    return combined;
  }
}
