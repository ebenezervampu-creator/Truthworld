import 'package:truthworld/features/admin/presentation/controllers/moderation/admin_moderation_predicates.dart';

/// Helper methods for filtering admin queues by search query, categories, and tabs.
class AdminModerationFilters {
  const AdminModerationFilters._();

  /// Filters videos by query, category, and tab
  static List<Map<String, dynamic>> filterVideos({
    required List<Map<String, dynamic>> videos,
    required String searchQuery,
    required String filterCategory,
    required String videoFilterTab,
  }) {
    final q = searchQuery.trim().toLowerCase();
    final cat = filterCategory.trim().toLowerCase();
    final tab = videoFilterTab.toLowerCase();
    return videos.where((v) {
      if (tab == 'pending' && !AdminModerationPredicates.isVideoPending(v)) {
        return false;
      }
      if (tab == 'approved' && !AdminModerationPredicates.isVideoApproved(v)) {
        return false;
      }
      if (tab == 'rejected' && !AdminModerationPredicates.isVideoRejected(v)) {
        return false;
      }
      if (cat.isNotEmpty && cat != 'all') {
        final itemCat = (v['category'] ?? '').toString().toLowerCase();
        if (itemCat != cat) return false;
      }
      if (q.isNotEmpty) {
        final title = (v['title'] ?? '').toString().toLowerCase();
        final id = (v['id'] ?? '').toString().toLowerCase();
        final user =
            (v['userId'] ?? v['creatorId'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !id.contains(q) && !user.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filters channels by query and tab
  static List<Map<String, dynamic>> filterChannels({
    required List<Map<String, dynamic>> channels,
    required String searchQuery,
    required String channelFilterTab,
  }) {
    final q = searchQuery.trim().toLowerCase();
    final tab = channelFilterTab.toLowerCase();
    return channels.where((c) {
      if (tab == 'pending' && !AdminModerationPredicates.isChannelPending(c)) {
        return false;
      }
      if (tab == 'approved' && !AdminModerationPredicates.isChannelApproved(c)) {
        return false;
      }
      if (tab == 'rejected' && !AdminModerationPredicates.isChannelRejected(c)) {
        return false;
      }
      if (q.isNotEmpty) {
        final name = (c['name'] ?? c['displayName'] ?? c['channelName'] ?? '')
            .toString()
            .toLowerCase();
        final id = (c['id'] ?? '').toString().toLowerCase();
        final handle = (c['handle'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !id.contains(q) && !handle.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filters topics by query and tab
  static List<Map<String, dynamic>> filterTopics({
    required List<Map<String, dynamic>> topics,
    required String searchQuery,
    required String topicFilterTab,
  }) {
    final q = searchQuery.trim().toLowerCase();
    final tab = topicFilterTab.toLowerCase();
    return topics.where((t) {
      if (tab == 'pending' && !AdminModerationPredicates.isTopicPending(t)) {
        return false;
      }
      if (tab == 'approved' && !AdminModerationPredicates.isTopicApproved(t)) {
        return false;
      }
      if (tab == 'rejected' && !AdminModerationPredicates.isTopicRejected(t)) {
        return false;
      }
      if (q.isNotEmpty) {
        final title = (t['title'] ?? t['name'] ?? '').toString().toLowerCase();
        final id = (t['id'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !id.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  /// Filters images/posts by query and tab
  static List<Map<String, dynamic>> filterImages({
    required List<Map<String, dynamic>> images,
    required String searchQuery,
    required String imageFilterTab,
  }) {
    final q = searchQuery.trim().toLowerCase();
    final tab = imageFilterTab.toLowerCase();
    return images.where((img) {
      if (tab == 'pending' && !AdminModerationPredicates.isImagePostPending(img)) {
        return false;
      }
      if (tab == 'approved' &&
          !AdminModerationPredicates.isImagePostApproved(img)) {
        return false;
      }
      if (tab == 'rejected' &&
          !AdminModerationPredicates.isImagePostRejected(img)) {
        return false;
      }
      if (q.isNotEmpty) {
        final cat = (img['category'] ?? '').toString().toLowerCase();
        final id = (img['id'] ?? '').toString().toLowerCase();
        final reason = (img['reason'] ?? '').toString().toLowerCase();
        if (!cat.contains(q) && !id.contains(q) && !reason.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filters reports by query and tab
  static List<Map<String, dynamic>> filterReports({
    required List<Map<String, dynamic>> reports,
    required String searchQuery,
    required String reportFilterTab,
  }) {
    final q = searchQuery.trim().toLowerCase();
    final tab = reportFilterTab.toLowerCase();
    return reports.where((r) {
      if (tab == 'pending' && !AdminModerationPredicates.isReportPending(r)) {
        return false;
      }
      if (tab == 'resolved' && !AdminModerationPredicates.isReportResolved(r)) {
        return false;
      }
      if (q.isNotEmpty) {
        final reason = (r['reason'] ?? r['reportReason'] ?? '')
            .toString()
            .toLowerCase();
        final id = (r['id'] ?? '').toString().toLowerCase();
        final vId = (r['videoId'] ?? '').toString().toLowerCase();
        if (!reason.contains(q) && !id.contains(q) && !vId.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}
