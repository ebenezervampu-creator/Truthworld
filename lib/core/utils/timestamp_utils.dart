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
}
