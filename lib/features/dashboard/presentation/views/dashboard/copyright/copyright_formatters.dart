import 'package:cloud_firestore/cloud_firestore.dart';

/// Formatting helpers for copyright and DMCA claims dates.
class CopyrightFormatters {
  const CopyrightFormatters._();

  static const List<String> _months = [
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

  /// Formats a Firestore Timestamp or DateTime into 'MMM d, yyyy'.
  static String formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${_months[d.month - 1]} ${d.day}, ${d.year}';
    }
    if (ts is DateTime) {
      return '${_months[ts.month - 1]} ${ts.day}, ${ts.year}';
    }
    return 'Unknown Date';
  }
}
