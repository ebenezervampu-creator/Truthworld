import 'package:truthworld/data/models/offline.dart';

/// Helper for filtering, searching, formatting timestamps, and grouping offline videos.
class DownloadFilterHelper {
  /// Filters a list of [OfflineVideo] items based on category and search query.
  static List<OfflineVideo> filterVideos({
    required List<OfflineVideo> videos,
    required String category,
    required String searchQuery,
  }) {
    var filtered = videos.toList();
    if (category == 'Videos') {
      filtered = filtered.where((v) => !v.isAudioOnly).toList();
    } else if (category == 'Audio') {
      filtered = filtered.where((v) => v.isAudioOnly).toList();
    }
    if (searchQuery.isNotEmpty) {
      final queryLower = searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (v) =>
                v.title.toLowerCase().contains(queryLower) ||
                v.channelName.toLowerCase().contains(queryLower),
          )
          .toList();
    }
    return filtered;
  }

  /// Formats a past timestamp into a relative standard English string.
  static String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Groups offline videos chronologically into 'Today', 'Yesterday', or formatted dates.
  static Map<String, List<OfflineVideo>> groupVideosByDate(
    List<OfflineVideo> videosList,
  ) {
    final groups = <String, List<OfflineVideo>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final video in videosList) {
      final date = video.downloadedAt;
      final dateOnly = DateTime(date.year, date.month, date.day);
      String key;
      if (dateOnly == today) {
        key = 'Today';
      } else if (dateOnly == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${date.day} ${_getMonthName(date.month)} ${date.year}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(video);
    }
    return groups;
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
