import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/errors/error_handler.dart';

/// Utilities for formatting video views and timestamps.
class VideoCardFormatters {
  const VideoCardFormatters._();

  /// Formats view count into a compact string (e.g. 1.5K, 2M, 3B).
  static String formatViews(int views) {
    if (views < 1000) return views.toString();
    if (views < 1000000) {
      final val = views / 1000;
      final decimals = views % 1000 == 0 ? 0 : (views < 100000 ? 1 : 0);
      return '${val.toStringAsFixed(decimals)}K';
    }
    if (views < 1000000000) {
      final val = views / 1000000;
      final decimals = views % 1000000 == 0 ? 0 : (views < 100000000 ? 1 : 0);
      return '${val.toStringAsFixed(decimals)}M';
    }
    final val = views / 1000000000;
    final decimals = views % 1000000000 == 0 ? 0 : (views < 100000000000 ? 1 : 0);
    return '${val.toStringAsFixed(decimals)}B';
  }

  /// Formats a Firestore timestamp to human-friendly relative time (e.g. 2 hours ago).
  static String formatTimestamp(Timestamp timestamp) {
    try {
      return timeago.format(timestamp.toDate());
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoCardFormatters.formatTimestamp',
      );
      return 'some time ago';
    }
  }
}
