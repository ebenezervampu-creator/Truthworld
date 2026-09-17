import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampUtils {
  /// Converts any dynamic timestamp representation (int, String, DateTime, Timestamp)
  /// into a [Timestamp]. Falls back to [fallback] or [Timestamp.now()] if invalid/null.
  static Timestamp parse(dynamic value, {Timestamp? fallback}) {
    if (value == null) return fallback ?? Timestamp.now();
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is int) {
      // Sometimes we get seconds, sometimes milliseconds.
      // Firestore timestamp.seconds is usually 10 digits, milliseconds is 13 digits.
      if (value.toString().length <= 10) {
        return Timestamp(value, 0);
      }
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final parsedInt = int.tryParse(value);
      if (parsedInt != null) {
        return parse(parsedInt, fallback: fallback);
      }
      final parsedDate = DateTime.tryParse(value);
      if (parsedDate != null) {
        return Timestamp.fromDate(parsedDate);
      }
    }
    return fallback ?? Timestamp.now();
  }

  /// Converts any dynamic timestamp representation into a [DateTime].
  static DateTime? parseToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if (value.toString().length <= 10) {
        return Timestamp(value, 0).toDate();
      }
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final parsedInt = int.tryParse(value);
      if (parsedInt != null) {
        return parseToDateTime(parsedInt);
      }
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Formats a [DateTime] into a human-readable relative time string (e.g. 'Updated today', '2 days ago').
  static String formatRelativeTime(DateTime? dateTime, {String prefix = ''}) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    String relative;
    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      relative = '$years year${years > 1 ? "s" : ""} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      relative = '$months month${months > 1 ? "s" : ""} ago';
    } else if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      relative = '$weeks week${weeks > 1 ? "s" : ""} ago';
    } else if (difference.inDays > 1) {
      relative = '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      relative = 'yesterday';
    } else if (difference.inHours >= 1) {
      relative = '${difference.inHours} hour${difference.inHours > 1 ? "s" : ""} ago';
    } else if (difference.inMinutes >= 1) {
      relative = '${difference.inMinutes} minute${difference.inMinutes > 1 ? "s" : ""} ago';
    } else {
      relative = 'just now';
    }

    return prefix.isEmpty ? relative : '$prefix $relative';
  }
}
