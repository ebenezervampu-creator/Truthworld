import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscriptions/subscription_state_base.dart';

/// Mixin handling refresh orchestration, filtering, and sorting logic for subscriptions.
mixin SubscriptionFiltersMixin on SubscriptionStateBase {
  @override
  Future<void> refresh() async {
    if (currentUserId == null) {
      rxErrorMessage.value = 'Please sign in to view subscriptions';
      hasError.value = true;
      rxIsLoading.value = false;
      return;
    }

    rxIsLoading.value = true;
    hasError.value = false;
    rxErrorMessage.value = '';

    try {
      await loadSubscriptions();
      await loadSubscribedChannels();
      await loadAllContent();
      applyFilters();
    } on Object catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SubscriptionController.refresh',
      );
      hasError.value = true;
      rxErrorMessage.value = AppException.from(e, stackTrace).displayMessage;
    } finally {
      rxIsLoading.value = false;
    }
  }

  @override
  void applyFilters() {
    filteredContent.value = List.from(allContent);

    // Apply content type filter
    final contentFilter = ContentFilter.values.firstWhere(
      (e) => e.name == selectedContentFilter.value,
      orElse: () => ContentFilter.all,
    );

    if (contentFilter != ContentFilter.all) {
      switch (contentFilter) {
        case ContentFilter.videos:
          filteredContent.retainWhere((c) => c.type == ContentType.video);
        case ContentFilter.playlists:
          filteredContent.retainWhere((c) => c.type == ContentType.playlist);
        case ContentFilter.communityPosts:
          filteredContent.retainWhere(
            (c) => c.type == ContentType.communityPost,
          );
        case ContentFilter.topics:
          filteredContent.retainWhere((c) => c.type == ContentType.topic);
        case ContentFilter.all:
          break;
      }
    }

    // Apply duration filter (only for videos)
    final durationFilter = DurationFilter.values.firstWhere(
      (e) => e.name == selectedDurationFilter.value,
      orElse: () => DurationFilter.all,
    );

    if (durationFilter != DurationFilter.all) {
      filteredContent.retainWhere((c) {
        if (c.type != ContentType.video) return false;
        final duration = c.video?.durationValue.inMinutes ?? 0;
        switch (durationFilter) {
          case DurationFilter.short:
            return duration < 5;
          case DurationFilter.medium:
            return duration >= 5 && duration <= 20;
          case DurationFilter.long:
            return duration > 20;
          case DurationFilter.all:
            return true;
        }
      });
    }

    // Apply date range filter
    final dateRangeFilter = DateRangeFilter.values.firstWhere(
      (e) => e.name == selectedDateRangeFilter.value,
      orElse: () => DateRangeFilter.all,
    );

    if (dateRangeFilter != DateRangeFilter.all) {
      final now = DateTime.now();
      filteredContent.retainWhere((c) {
        final contentDate = c.createdAt.toDate();
        switch (dateRangeFilter) {
          case DateRangeFilter.today:
            return contentDate.day == now.day &&
                contentDate.month == now.month &&
                contentDate.year == now.year;
          case DateRangeFilter.thisWeek:
            return now.difference(contentDate).inDays <= 7;
          case DateRangeFilter.thisMonth:
            return contentDate.month == now.month &&
                contentDate.year == now.year;
          case DateRangeFilter.thisYear:
            return contentDate.year == now.year;
          case DateRangeFilter.all:
            return true;
        }
      });
    }

    // Apply sorting
    final sortFilter = SortFilter.values.firstWhere(
      (e) => e.name == selectedSortFilter.value,
      orElse: () => SortFilter.trending,
    );

    switch (sortFilter) {
      case SortFilter.trending:
        if (Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          filteredContent.sort((a, b) {
            var scoreA = a.algorithmicScore;
            var scoreB = b.algorithmicScore;
            if (a.video != null) {
              final s = algorithm.scoreVideo(
                a.video!,
                RecommendationSurface.subscriptionFeed,
              );
              if (s != null) scoreA += s.score * 5.0;
            }
            if (b.video != null) {
              final s = algorithm.scoreVideo(
                b.video!,
                RecommendationSurface.subscriptionFeed,
              );
              if (s != null) scoreB += s.score * 5.0;
            }
            return scoreB.compareTo(scoreA);
          });
        } else {
          filteredContent.sort(
            (a, b) => b.algorithmicScore.compareTo(a.algorithmicScore),
          );
        }
      case SortFilter.popular:
        filteredContent.sort((a, b) {
          final aEngagement = _getEngagementScore(a);
          final bEngagement = _getEngagementScore(b);
          return bEngagement.compareTo(aEngagement);
        });
      case SortFilter.newest:
        filteredContent.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortFilter.oldest:
        filteredContent.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  double _getEngagementScore(SubscriptionContent content) {
    switch (content.type) {
      case ContentType.video:
        return content.video?.views.toDouble() ?? 0;
      case ContentType.playlist:
        return content.playlist?.videoCount.toDouble() ?? 0;
      case ContentType.communityPost:
        return content.communityPost?.likes.toDouble() ?? 0;
      case ContentType.topic:
        return content.topic?.followerCount.toDouble() ?? 0;
    }
  }

  void setContentFilter(String filter) {
    selectedContentFilter.value = filter;
    if (filter == ContentFilter.playlists.name ||
        filter == ContentFilter.communityPosts.name) {
      selectedDurationFilter.value = DurationFilter.all.name;
    }
    applyFilters();
  }

  void setSortFilter(String filter) {
    selectedSortFilter.value = filter;
    applyFilters();
  }

  void setDurationFilter(String filter) {
    selectedDurationFilter.value = filter;
    if (filter != DurationFilter.all.name) {
      selectedContentFilter.value = ContentFilter.videos.name;
    }
    applyFilters();
  }

  void setDateRangeFilter(String filter) {
    selectedDateRangeFilter.value = filter;
    applyFilters();
  }
}
