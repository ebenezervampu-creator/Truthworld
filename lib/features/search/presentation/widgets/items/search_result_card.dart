import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_result_sub_cards.dart';

/// Reusable polymorphic search result card widget.
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({required this.result, super.key, this.onTap});

  final SearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case ResultType.channel:
        return SearchChannelResultItem(
          result: result,
          onTap: onTap,
          formattedViews: formatViews(result.views),
        );
      case ResultType.playlist:
        return SearchPlaylistResultItem(
          result: result,
          onTap: onTap,
        );
      case ResultType.topic:
        return SearchTopicResultItem(
          result: result,
          onTap: onTap,
          formattedViews: formatViews(result.views),
        );
      case ResultType.video:
        return SearchVideoResultItem(
          result: result,
          onTap: onTap,
          durationStr: _formatDuration(result.duration),
          formattedViews: formatViews(result.views),
          formattedTime: formatRelativeTime(result.createdAt.toDate()),
        );
    }
  }

  String? _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
  }

  /// Helper to format view/sub counts.
  static String formatViews(int count) {
    return FormatUtils.formatCount(count);
  }

  /// Helper to format relative upload dates.
  static String formatRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? "s" : ""} ago';
    }
    if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? "s" : ""} ago';
    }
    if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    }
    if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? "s" : ""} ago';
    }
    return 'just now';
  }
}
