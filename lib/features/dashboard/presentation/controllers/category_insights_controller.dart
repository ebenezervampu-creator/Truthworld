import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';

class CategoryStats {
  final String category;
  final int videoCount;
  final int channelCount;
  final int totalLikes;
  final int totalViews;
  final double avgLikesPerVideo;
  final double avgViewsPerVideo;
  final double growthRate; // Velocity score based on recent video views/likes
  final double
  opportunityIndex; // High demand (likes/views) vs low supply (channel/video count)
  final bool isUntouched; // Zero channels in category
  final List<Map<String, dynamic>> topLikedVideos;

  CategoryStats({
    required this.category,
    required this.videoCount,
    required this.channelCount,
    required this.totalLikes,
    required this.totalViews,
    required this.avgLikesPerVideo,
    required this.avgViewsPerVideo,
    required this.growthRate,
    required this.opportunityIndex,
    required this.isUntouched,
    required this.topLikedVideos,
  });
}

enum CategoryInsightsFilter {
  all,
  mostLiked,
  untouched,
  contentGaps,
  fastestGrowing,
}

class CategoryInsightsController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxBool rxIsLoading = true.obs;
  final RxString rxErrorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final Rx<CategoryInsightsFilter> activeFilter =
      CategoryInsightsFilter.all.obs;

  final RxList<CategoryStats> allCategoryStats = <CategoryStats>[].obs;
  final RxInt totalTrackedCategories = 0.obs;
  final RxInt untouchedCategoryCount = 0.obs;
  final RxString topLikedCategoryName = '-'.obs;
  final RxString fastestGrowingCategoryName = '-'.obs;

  static const List<String> defaultCategories = [
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Gaming',
    'Technology',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion & Beauty',
    'Food & Cooking',
    'Business & Finance',
    'Animation',
    'Short Films',
    'Motivation',
    'History',
    'Art & Design',
    'Automotive',
    'Animals & Pets',
    'Spirituality',
    'Nature & Wildlife',
    'Kids & Family',
  ];

  @override
  void onInit() {
    super.onInit();
    unawaited(fetchCategoryInsights());
  }

  Future<void> fetchCategoryInsights() async {
    try {
      rxIsLoading.value = true;
      rxErrorMessage.value = '';

      // 1. Query real video documents and channel documents from Firestore
      final videosSnap = await _firestore
          .collection(FirestoreCollections.videos)
          .get();
      final channelsSnap = await _firestore
          .collection(FirestoreCollections.channels)
          .get();

      // Maps to aggregate data
      final categoriesSet = Set<String>.from(defaultCategories);
      final videoCounts = <String, int>{};
      final totalLikesMap = <String, int>{};
      final totalViewsMap = <String, int>{};
      final categoryChannelsMap = <String, Set<String>>{};
      final recentLikesMap = <String, int>{};
      final recentViewsMap = <String, int>{};
      final categoryVideosMap = <String, List<Map<String, dynamic>>>{};

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Process Channels
      for (final doc in channelsSnap.docs) {
        final data = doc.data();
        final channelId = doc.id;
        final rawCats = data['categories'] ?? data['category'];
        var channelCats = <String>[];
        if (rawCats is List) {
          channelCats = rawCats
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (rawCats is String && rawCats.trim().isNotEmpty) {
          channelCats = [rawCats.trim()];
        }

        for (final cat in channelCats) {
          if (cat.isEmpty) continue;
          categoriesSet.add(cat);
          categoryChannelsMap.putIfAbsent(cat, () => <String>{}).add(channelId);
        }
      }

      // Process Videos
      for (final doc in videosSnap.docs) {
        final data = doc.data();
        final cat =
            (data['category'] ?? data['videoCategory'] ?? 'Uncategorized')
                .toString()
                .trim();
        if (cat.isEmpty) continue;

        categoriesSet.add(cat);

        // Parse likes
        var likes = 0;
        if (data['likeCount'] is int) {
          likes = data['likeCount'];
        } else if (data['likes'] is int) {
          likes = data['likes'];
        } else if (data['likes'] is List) {
          likes = (data['likes'] as List).length;
        } else if (data['likedBy'] is List) {
          likes = (data['likedBy'] as List).length;
        }

        // Parse views
        var views = 0;
        if (data['viewCount'] is int) {
          views = data['viewCount'];
        } else if (data['views'] is int) {
          views = data['views'];
        } else if (data['views'] is String) {
          views = int.tryParse(data['views']) ?? 0;
        }

        // Channel tracking from video
        final channelId = (data['channelId'] ?? '').toString();
        if (channelId.isNotEmpty) {
          categoryChannelsMap.putIfAbsent(cat, () => <String>{}).add(channelId);
        }

        videoCounts[cat] = (videoCounts[cat] ?? 0) + 1;
        totalLikesMap[cat] = (totalLikesMap[cat] ?? 0) + likes;
        totalViewsMap[cat] = (totalViewsMap[cat] ?? 0) + views;

        // Created date for recent growth tracking
        final dynamic rawCreated = data['createdAt'] ?? data['uploadedAt'];
        DateTime? createdDate;
        if (rawCreated is Timestamp) {
          createdDate = rawCreated.toDate();
        } else if (rawCreated is String) {
          createdDate = DateTime.tryParse(rawCreated);
        }

        if (createdDate != null && createdDate.isAfter(thirtyDaysAgo)) {
          recentLikesMap[cat] = (recentLikesMap[cat] ?? 0) + likes;
          recentViewsMap[cat] = (recentViewsMap[cat] ?? 0) + views;
        }

        // Collect video info for top liked videos list
        categoryVideosMap.putIfAbsent(cat, () => []).add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'likes': likes,
          'views': views,
          'thumbnailUrl': data['thumbnailUrl'] ?? '',
          'channelName': data['channelName'] ?? '',
        });
      }

      // Build stats for each category
      final statsList = <CategoryStats>[];
      var untouched = 0;
      CategoryStats? maxLikedCat;
      CategoryStats? maxGrowthCat;

      for (final cat in categoriesSet) {
        final vCount = videoCounts[cat] ?? 0;
        final cCount = (categoryChannelsMap[cat] ?? {}).length;
        final tLikes = totalLikesMap[cat] ?? 0;
        final tViews = totalViewsMap[cat] ?? 0;
        final rLikes = recentLikesMap[cat] ?? 0;
        final rViews = recentViewsMap[cat] ?? 0;

        final avgLikes = vCount > 0 ? tLikes / vCount : 0.0;
        final avgViews = vCount > 0 ? tViews / vCount : 0.0;

        // Growth rate calculation: ratio of recent engagement (30 days) vs overall average
        final recentEngagement = (rLikes * 2.0) + rViews;
        final totalEngagement = (tLikes * 2.0) + tViews;
        final growthRate = totalEngagement > 0
            ? (recentEngagement / totalEngagement) * 100.0
            : (vCount == 0 ? 0.0 : 10.0);

        // Content Gap / Opportunity Index formula:
        final demand = (tLikes * 2.5) + (tViews * 0.1) + 1.0;
        final supply = (cCount * 3.0) + (vCount * 0.5) + 1.0;
        final opportunityIndex = cCount == 0
            ? (demand * 2.0)
            : (demand / supply);

        final isUntouchedCat = cCount == 0;
        if (isUntouchedCat) untouched++;

        // Top 3 liked videos for category
        final vList = categoryVideosMap[cat] ?? [];
        vList.sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
        final top3Videos = vList.take(3).toList();

        final stats = CategoryStats(
          category: cat,
          videoCount: vCount,
          channelCount: cCount,
          totalLikes: tLikes,
          totalViews: tViews,
          avgLikesPerVideo: avgLikes,
          avgViewsPerVideo: avgViews,
          growthRate: growthRate,
          opportunityIndex: opportunityIndex,
          isUntouched: isUntouchedCat,
          topLikedVideos: top3Videos,
        );

        statsList.add(stats);

        if (maxLikedCat == null || stats.totalLikes > maxLikedCat.totalLikes) {
          maxLikedCat = stats;
        }
        if (maxGrowthCat == null ||
            stats.growthRate > maxGrowthCat.growthRate) {
          maxGrowthCat = stats;
        }
      }

      allCategoryStats.assignAll(statsList);
      totalTrackedCategories.value = statsList.length;
      untouchedCategoryCount.value = untouched;
      topLikedCategoryName.value =
          maxLikedCat != null && maxLikedCat.totalLikes > 0
          ? '${maxLikedCat.category} (${maxLikedCat.totalLikes} likes)'
          : 'None yet';
      fastestGrowingCategoryName.value = maxGrowthCat != null
          ? maxGrowthCat.category
          : 'None yet';
    } catch (e, stack) {
      debugPrint('Error fetching category insights: $e\n$stack');
      rxErrorMessage.value =
          'Failed to load category insights data. Please try again.';
    } finally {
      rxIsLoading.value = false;
    }
  }

  List<CategoryStats> get filteredStats {
    final query = searchQuery.value.trim().toLowerCase();
    var list = allCategoryStats.where((s) {
      if (query.isEmpty) return true;
      return s.category.toLowerCase().contains(query);
    }).toList();

    switch (activeFilter.value) {
      case CategoryInsightsFilter.mostLiked:
        list.sort((a, b) => b.totalLikes.compareTo(a.totalLikes));
      case CategoryInsightsFilter.untouched:
        list = list.where((s) => s.isUntouched).toList();
        list.sort((a, b) => a.category.compareTo(b.category));
      case CategoryInsightsFilter.contentGaps:
        list.sort((a, b) => b.opportunityIndex.compareTo(a.opportunityIndex));
      case CategoryInsightsFilter.fastestGrowing:
        list.sort((a, b) => b.growthRate.compareTo(a.growthRate));
      case CategoryInsightsFilter.all:
        list.sort((a, b) {
          if (a.isUntouched != b.isUntouched) {
            return a.isUntouched ? -1 : 1;
          }
          return b.totalLikes.compareTo(a.totalLikes);
        });
    }

    return list;
  }
}
