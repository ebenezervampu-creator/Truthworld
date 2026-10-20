import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Mixin providing aggregated platform analytics and violation tracking.
mixin AdminAnalyticsMixin on GetxController {
  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Analytics State
  // ═══════════════════════════════════════════════════════════════════════════
  final RxMap<String, dynamic> analyticsData = <String, dynamic>{}.obs;
  final RxString analyticsTimeRange = '7d'.obs;
  final RxBool isLoadingAnalytics = false.obs;

  DateTime? _getAnalyticsFilterDate() {
    final range = analyticsTimeRange.value;
    final now = DateTime.now();
    switch (range) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      case 'all':
      default:
        return null;
    }
  }

  DateTime? _extractTimestamp(dynamic rawTime) {
    if (rawTime == null) return null;
    if (rawTime is Timestamp) return rawTime.toDate();
    if (rawTime is DateTime) return rawTime;
    if (rawTime is int) return DateTime.fromMillisecondsSinceEpoch(rawTime);
    if (rawTime is String) return DateTime.tryParse(rawTime);
    return null;
  }

  bool _isNotViolationCategory(String cat) {
    final lower = cat.trim().toLowerCase();
    const nonViolations = {
      'general',
      'technology',
      'tech',
      'entertainment',
      'music',
      'short films',
      'shortfilms',
      'short film',
      'education',
      'news',
      'sports',
      'comedy',
      'science',
      'travel',
      'vlog',
      'people',
      'lifestyle',
      'community post',
      'community',
      'video thumbnail',
      'thumbnail',
      'channel avatar',
      'avatar',
      'channel banner',
      'banner',
      'playlist thumbnail',
      'topic thumbnail',
      'video',
      'image',
      'all',
      'none',
      'n/a',
      'unknown',
      'approved',
      'pending',
      'clean',
    };
    return nonViolations.contains(lower);
  }

  String _normalizeViolationCategory(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('gaming') || lower.contains('gameplay') || lower.contains('esports')) return 'Prohibited Gaming Content';
    if (lower.contains('romance') || lower.contains('romantic')) return 'Prohibited Romance Content';
    if (lower.contains('fashion') || lower.contains('glamour modeling')) return 'Prohibited Fashion Content';
    if (lower.contains('hate')) return 'Hate Speech & Harassment';
    if (lower.contains('harass') || lower.contains('bully')) return 'Harassment & Bullying';
    if (lower.contains('copyright') || lower.contains('dmca') || lower.contains('ip ')) return 'Copyright Infringement';
    if (lower.contains('adult') || lower.contains('nsfw') || lower.contains('nudity') || lower.contains('sexual')) return 'Adult / NSFW Content';
    if (lower.contains('violence') || lower.contains('gore') || lower.contains('graphic')) return 'Graphic Violence';
    if (lower.contains('spam') || lower.contains('scam') || lower.contains('fraud') || lower.contains('phish')) return 'Spam & Deceptive Practices';
    if (lower.contains('misinformation') || lower.contains('fake news')) return 'Misinformation';
    if (lower.contains('child') || lower.contains('csam')) return 'Child Safety Violation';
    if (lower.contains('terror') || lower.contains('dangerous')) return 'Dangerous & Illegal Acts';
    if (lower.contains('racy')) return 'Racy / Borderline Content';
    if (lower.contains('medical')) return 'Sensitive Medical Content';
    if (lower.contains('spoof')) return 'Spoof & Impersonation';
    if (lower.contains('guideline') || lower.contains('community')) return 'Community Guideline Breach';

    return raw.split(RegExp(r'[_\s]+')).map((w) => w.capitalizeFirst ?? w).join(' ');
  }

  /// Fetches real aggregated analytics data from Firestore for the selected time range
  Future<void> fetchAnalytics() async {
    isLoadingAnalytics.value = true;
    try {
      final filterDate = _getAnalyticsFilterDate();

      // 1. Fetch Real Videos from Firestore
      QuerySnapshot<Map<String, dynamic>>? videosSnap;
      try {
        videosSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchVideos');
      }

      // 2. Fetch Real Channels from Firestore
      QuerySnapshot<Map<String, dynamic>>? channelsSnap;
      try {
        channelsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchChannels');
      }

      // 3. Fetch Real Reports from Firestore
      QuerySnapshot<Map<String, dynamic>>? reportsSnap;
      try {
        reportsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.reports)
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchReports');
      }

      QuerySnapshot<Map<String, dynamic>>? videoReportsSnap;
      try {
        videoReportsSnap = await FirebaseFirestore.instance
            .collection('video_reports')
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchVideoReports');
      }

      QuerySnapshot<Map<String, dynamic>>? altVideoReportsSnap;
      try {
        altVideoReportsSnap = await FirebaseFirestore.instance
            .collection('videoReports')
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchAltVideoReports');
      }

      // 4. Fetch Real Flagged & Moderated Media from Firestore
      QuerySnapshot<Map<String, dynamic>>? flaggedImagesSnap;
      try {
        flaggedImagesSnap = await FirebaseFirestore.instance
            .collection('flagged_images_review')
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchFlaggedImages');
      }

      QuerySnapshot<Map<String, dynamic>>? rejectedLogsSnap;
      try {
        rejectedLogsSnap = await FirebaseFirestore.instance
            .collection('rejected_images_log')
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchRejectedLogs');
      }

      QuerySnapshot<Map<String, dynamic>>? communitySnap;
      try {
        communitySnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.community)
            .limit(300)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchCommunityPosts');
      }

      // 5. Fetch Appeals from Firestore
      QuerySnapshot<Map<String, dynamic>>? appealsSnap;
      try {
        appealsSnap = await FirebaseFirestore.instance
            .collection('content_appeals')
            .limit(200)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchAppeals');
      }

      // 6. Fetch Users from Firestore for Strikes & Profile Lookups
      QuerySnapshot<Map<String, dynamic>>? usersSnap;
      try {
        usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .limit(500)
            .get();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchUsers');
      }

      final userLookup = <String, Map<String, dynamic>>{};
      var totalPlatformUsers = 0;
      var bannedUsersCount = 0;

      if (usersSnap != null) {
        totalPlatformUsers = usersSnap.docs.length;
        for (final doc in usersSnap.docs) {
          final data = doc.data();
          final uid = doc.id;
          final isBanned = data['isBanned'] == true || data['role'] == 'banned';
          final strikes = (data['strikes'] is num) ? (data['strikes'] as num).toInt() : 0;
          if (isBanned) bannedUsersCount++;

          userLookup[uid] = {
            'name': data['displayName'] ?? data['name'] ?? data['username'] ?? uid,
            'email': data['email'] ?? '',
            'strikes': strikes,
            'isBanned': isBanned,
          };
        }
      }

      // Aggregate Violation Categories (ONLY real violations)
      final violationCounts = <String, int>{};
      final userOffenses = <String, Map<String, dynamic>>{};

      void recordOffense(String userId, {String? email, String? name}) {
        if (userId.isEmpty || userId == 'unknown') return;
        final existing = userOffenses[userId] ?? {
          'user': name ?? userLookup[userId]?['name'] ?? email ?? userLookup[userId]?['email'] ?? userId,
          'email': email ?? userLookup[userId]?['email'] ?? '',
          'violationsCount': 0,
          'strikes': userLookup[userId]?['strikes'] ?? 0,
          'isBanned': userLookup[userId]?['isBanned'] ?? false,
        };
        existing['violationsCount'] =
            ((existing['violationsCount'] as num?)?.toInt() ?? 0) + 1;
        userOffenses[userId] = existing;
      }

      // Process Videos
      var totalVideosInPeriod = 0;
      var approvedVideos = 0;
      var rejectedVideos = 0;
      var pendingVideosCount = 0;
      final allVideosDocs = videosSnap?.docs ?? [];

      for (final doc in allVideosDocs) {
        final data = doc.data();
        final timestamp = _extractTimestamp(data['createdAt'] ?? data['uploadedAt'] ?? data['timestamp']);

        // Check if within time filter
        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalVideosInPeriod++;
        final mod = data['moderation'] as Map<String, dynamic>?;
        final status = (mod?['status'] ?? data['status'] ?? '').toString().toLowerCase();

        if (status == 'approved') {
          approvedVideos++;
        } else if (status == 'rejected') {
          rejectedVideos++;
          final uId = (data['userId'] ?? data['creatorId'] ?? data['uploaderId'] ?? '').toString();
          recordOffense(uId, email: data['userEmail']?.toString());

          // Extract real violation categories
          final categories = mod?['violationCategories'];
          if (categories is List) {
            for (final c in categories) {
              if (c != null && !_isNotViolationCategory(c.toString())) {
                final catName = _normalizeViolationCategory(c.toString());
                violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
              }
            }
          }
          final reason = mod?['rejectionReason'] ?? mod?['moderationReason'] ?? data['rejectionReason'];
          if (reason != null && !_isNotViolationCategory(reason.toString())) {
            final catName = _normalizeViolationCategory(reason.toString());
            violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
          }
        } else {
          pendingVideosCount++;
        }
      }

      // Process Channels
      var totalChannelsInPeriod = 0;
      var approvedChannels = 0;
      var rejectedChannels = 0;
      var pendingChannelsCount = 0;
      final allChannelsDocs = channelsSnap?.docs ?? [];

      for (final doc in allChannelsDocs) {
        final data = doc.data();
        final timestamp = _extractTimestamp(data['updatedAt'] ?? data['createdAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalChannelsInPeriod++;
        final status = (data['status'] ?? data['verificationStatus'] ?? 'approved').toString().toLowerCase();
        if (status == 'approved' || status == 'verified') {
          approvedChannels++;
        } else if (status == 'rejected') {
          rejectedChannels++;
          final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
          recordOffense(ownerId);
          final reason = data['rejectionReason'];
          if (reason != null && !_isNotViolationCategory(reason.toString())) {
            final catName = _normalizeViolationCategory(reason.toString());
            violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
          }
        } else {
          pendingChannelsCount++;
        }
      }

      // Process Reports (reports, video_reports, videoReports)
      var totalReportsInPeriod = 0;
      var pendingReportsCount = 0;
      var resolvedReportsCount = 0;
      var dismissedReportsCount = 0;

      final allReportDocs = [
        ...?reportsSnap?.docs,
        ...?videoReportsSnap?.docs,
        ...?altVideoReportsSnap?.docs,
      ];

      final processedReportIds = <String>{};
      for (final doc in allReportDocs) {
        if (processedReportIds.contains(doc.id)) continue;
        processedReportIds.add(doc.id);

        final data = doc.data();
        final timestamp = _extractTimestamp(data['timestamp'] ?? data['createdAt'] ?? data['reportedAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalReportsInPeriod++;
        final status = (data['status'] ?? 'pending').toString().toLowerCase();

        if (status == 'resolved' || status == 'actioned' || status == 'approved' || status == 'closed') {
          resolvedReportsCount++;
        } else if (status == 'dismissed' || status == 'rejected') {
          dismissedReportsCount++;
        } else {
          pendingReportsCount++;
        }

        // Extract real report violation reason
        final reason = data['reason'] ?? data['category'] ?? data['reportReason'] ?? data['violationType'];
        if (reason != null && !_isNotViolationCategory(reason.toString())) {
          final catName = _normalizeViolationCategory(reason.toString());
          violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
        }

        // Track reported offender
        final reportedUser = (data['reportedUserId'] ?? data['targetUserId'] ?? data['uploaderId'] ?? '').toString();
        if (reportedUser.isNotEmpty) {
          recordOffense(reportedUser);
        }
      }

      // Process Flagged Media, Rejected Images Log & Community Posts
      var totalMediaInPeriod = 0;
      var approvedMedia = 0;
      var rejectedMedia = 0;
      var pendingMediaCount = 0;

      final allMediaDocs = [
        ...?flaggedImagesSnap?.docs,
        ...?rejectedLogsSnap?.docs,
        ...?communitySnap?.docs,
      ];

      final processedMediaIds = <String>{};
      for (final doc in allMediaDocs) {
        if (processedMediaIds.contains(doc.id)) continue;
        processedMediaIds.add(doc.id);

        final data = doc.data();
        final timestamp = _extractTimestamp(data['timestamp'] ?? data['flaggedAt'] ?? data['createdAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalMediaInPeriod++;
        final status = (data['status'] ?? '').toString().toUpperCase();

        if (status == 'APPROVED') {
          approvedMedia++;
        } else if (status == 'REJECTED' || doc.reference.parent.id == 'rejected_images_log') {
          rejectedMedia++;
          final uId = (data['uploaderId'] ?? data['userId'] ?? data['authorId'] ?? '').toString();
          recordOffense(uId, email: data['userEmail']?.toString());

          // SafeSearch Scores: only count if likelihood score >= 4 (LIKELY / VERY_LIKELY)
          final scores = data['safeSearchScores'] as Map<String, dynamic>?;
          if (scores != null) {
            scores.forEach((key, value) {
              if (value is num && value >= 4) {
                final catName = _normalizeViolationCategory(key);
                violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
              }
            });
          }

          final reason = data['rejectionReason'] ?? data['reason'] ?? data['violationCategory'];
          if (reason != null && !_isNotViolationCategory(reason.toString())) {
            final catName = _normalizeViolationCategory(reason.toString());
            violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
          }
        } else if (status == 'PENDING_REVIEW' || data['isFlagged'] == true) {
          pendingMediaCount++;
        } else {
          approvedMedia++;
        }
      }

      // Process Appeals
      var totalAppealsInPeriod = 0;
      var pendingAppealsCount = 0;
      var upheldAppeals = 0;
      var overturnedAppeals = 0;
      final allAppealsDocs = appealsSnap?.docs ?? [];

      for (final doc in allAppealsDocs) {
        final data = doc.data();
        final timestamp = _extractTimestamp(data['submittedAt'] ?? data['createdAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalAppealsInPeriod++;
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        if (status == 'overturned' || status == 'approved') {
          overturnedAppeals++;
        } else if (status == 'upheld' || status == 'rejected') {
          upheldAppeals++;
        } else {
          pendingAppealsCount++;
        }
      }

      // Include users with recorded strikes from the users collection in the offenses map
      userLookup.forEach((uid, info) {
        final strikes = info['strikes'] as int? ?? 0;
        final isBanned = info['isBanned'] as bool? ?? false;
        if (strikes > 0 || isBanned) {
          final existing = userOffenses[uid] ?? {
            'user': info['name'],
            'email': info['email'],
            'violationsCount': strikes,
            'strikes': strikes,
            'isBanned': isBanned,
          };
          userOffenses[uid] = existing;
        }
      });

      // Sort Top Offenders by violations & strikes
      final sortedOffenders = userOffenses.values.where((off) {
        final vCount = off['violationsCount'] as int? ?? 0;
        final strikes = off['strikes'] as int? ?? 0;
        final isBanned = off['isBanned'] == true;
        return vCount > 0 || strikes > 0 || isBanned;
      }).toList()
        ..sort((a, b) {
          final bViolations = (b['violationsCount'] as num?)?.toInt() ?? 0;
          final aViolations = (a['violationsCount'] as num?)?.toInt() ?? 0;
          final cmp = bViolations.compareTo(aViolations);
          if (cmp != 0) return cmp;
          final sB = (b['strikes'] as num?)?.toInt() ?? 0;
          final sA = (a['strikes'] as num?)?.toInt() ?? 0;
          return sB.compareTo(sA);
        });

      final topOffenders = sortedOffenders.take(8).toList();

      // Aggregate Platform Totals
      final totalModerated = totalVideosInPeriod + totalMediaInPeriod + totalChannelsInPeriod + totalReportsInPeriod;
      final totalApproved = approvedVideos + approvedMedia + approvedChannels;
      final totalRejected = rejectedVideos + rejectedMedia + rejectedChannels;
      final totalPending = pendingVideosCount + pendingMediaCount + pendingChannelsCount + pendingReportsCount;
      final activeViolations = pendingReportsCount + rejectedVideos + rejectedMedia;

      final autoApprovalRate = totalModerated > 0
          ? ((totalApproved / (totalApproved + totalRejected + 0.0001)) * 100).clamp(0, 100).round()
          : 100;

      // Platform Safety Score Calculation
      // 100 base, decreased by rejection rate & open active violations
      var calculatedScore = 100.0;
      if (totalModerated > 0) {
        final rejectRatio = totalRejected / totalModerated;
        calculatedScore -= rejectRatio * 40.0;
      }
      if (activeViolations > 0) {
        calculatedScore -= activeViolations.clamp(0, 20) * 1.5;
      }
      if (totalPending > 20) {
        calculatedScore -= (totalPending - 20).clamp(0, 30) * 0.3;
      }
      final safetyScore = calculatedScore.round().clamp(0, 100);

      analyticsData.assignAll({
        'safetyScore': safetyScore,
        'totalModerated': totalModerated,
        'totalModerated24h': totalModerated,
        'moderated24h': totalModerated,
        'autoApprovalRate': autoApprovalRate,
        'autoApproveRate': autoApprovalRate,
        'activeViolations': activeViolations,
        'totalApproved': totalApproved,
        'totalRejected': totalRejected,
        'totalPending': totalPending,
        'violationCategories': violationCounts,
        'topOffenders': topOffenders,
        'breakdown': {
          'videos': {
            'total': totalVideosInPeriod,
            'approved': approvedVideos,
            'rejected': rejectedVideos,
            'pending': pendingVideosCount,
          },
          'media': {
            'total': totalMediaInPeriod,
            'approved': approvedMedia,
            'rejected': rejectedMedia,
            'pending': pendingMediaCount,
          },
          'channels': {
            'total': totalChannelsInPeriod,
            'approved': approvedChannels,
            'rejected': rejectedChannels,
            'pending': pendingChannelsCount,
          },
          'reports': {
            'total': totalReportsInPeriod,
            'pending': pendingReportsCount,
            'resolved': resolvedReportsCount,
            'dismissed': dismissedReportsCount,
          },
          'appeals': {
            'total': totalAppealsInPeriod,
            'pending': pendingAppealsCount,
            'upheld': upheldAppeals,
            'overturned': overturnedAppeals,
          },
        },
        'platformTotals': {
          'totalUsers': totalPlatformUsers > 0 ? totalPlatformUsers : allVideosDocs.length,
          'totalVideos': allVideosDocs.length,
          'totalChannels': allChannelsDocs.length,
          'totalReports': allReportDocs.length,
          'totalAppeals': allAppealsDocs.length,
          'bannedUsers': bannedUsersCount,
        },
        'timeRange': analyticsTimeRange.value,
        'lastUpdated': DateTime.now(),
      });
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminAnalyticsMixin.fetchAnalytics');
    } finally {
      isLoadingAnalytics.value = false;
    }
  }


}
