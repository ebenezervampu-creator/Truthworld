import 'package:flutter/material.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Production-grade helper for resilient time parsing, formatting, window calculations,
/// and session tracking across midnight boundaries.
class TimeOfDayHelper {
  TimeOfDayHelper._();

  /// Parse a time string into [TimeOfDay] with high tolerance for formatting quirks.
  /// Handles:
  /// - 12-hour: '11:00 PM', '06:00 AM', '11:00pm', '6:30 am'
  /// - 24-hour: '23:00', '06:00', '7:15'
  /// - Narrow non-breaking spaces (\u202F) and non-breaking spaces (\u00A0)
  static TimeOfDay parse(
    String? timeStr, {
    TimeOfDay fallback = const TimeOfDay(hour: 23, minute: 0),
  }) {
    if (timeStr == null || timeStr.trim().isEmpty) {
      return fallback;
    }

    try {
      final sanitized = timeStr
          .replaceAll('\u202F', ' ')
          .replaceAll('\u00A0', ' ')
          .trim();

      // Match 12-hour or 24-hour formats
      final regex = RegExp(
        r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$',
        caseSensitive: false,
      );
      final match = regex.firstMatch(sanitized);

      if (match != null) {
        var hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final period = match.group(3)?.toUpperCase();

        if (minute < 0 || minute > 59) return fallback;

        if (period != null) {
          // 12-hour clock
          if (hour < 1 || hour > 12) return fallback;
          if (period == 'PM' && hour < 12) {
            hour += 12;
          } else if (period == 'AM' && hour == 12) {
            hour = 0;
          }
        } else {
          // 24-hour clock
          if (hour < 0 || hour > 23) return fallback;
        }

        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TimeOfDayHelper.parse',
      );
    }

    return fallback;
  }

  /// Format [TimeOfDay] into a standard clean 12-hour display string (e.g. '11:00 PM' or '06:00 AM')
  static String format(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hourOfPeriod = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final hourStr = hourOfPeriod.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr $period';
  }

  /// Convert [TimeOfDay] to total minutes from midnight (0 .. 1439)
  static int toMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  /// Check if [current] is within the window from [start] to [end].
  /// Handles both same-day windows (e.g. 13:00 to 15:00) and overnight windows (e.g. 23:00 to 06:00).
  static bool isTimeWithinWindow(
    TimeOfDay current,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    final c = toMinutes(current);
    final s = toMinutes(start);
    final e = toMinutes(end);

    if (s <= e) {
      // Same-day window
      return c >= s && c <= e;
    } else {
      // Overnight window crossing midnight
      return c >= s || c <= e;
    }
  }

  /// Check if a repeat schedule ('Everyday', 'Weekdays', 'Weekends') applies to [weekday] (1=Mon..7=Sun)
  static bool isScheduleActiveOnDay(String scheduleDays, int weekday) {
    final isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;
    switch (scheduleDays.toLowerCase().trim()) {
      case 'weekdays':
        return !isWeekend;
      case 'weekends':
        return isWeekend;
      case 'everyday':
      default:
        return true;
    }
  }

  /// Calculates a unique session key for an active bedtime window (e.g., '2026-09-14').
  ///
  /// For overnight schedules (e.g. 11:00 PM to 6:00 AM):
  /// If the current time is after midnight but before the end time (e.g. 2:00 AM on Sept 15),
  /// the bedtime session actually belongs to the preceding evening (Sept 14).
  /// This prevents midnight re-prompts or duplicate notifications during the same sleep cycle.
  static String getSessionKey({
    required DateTime now,
    required TimeOfDay start,
    required TimeOfDay end,
  }) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = toMinutes(start);
    final endMinutes = toMinutes(end);

    var sessionDate = now;

    if (startMinutes > endMinutes && currentMinutes <= endMinutes) {
      // We are past midnight in an overnight session that started yesterday
      sessionDate = now.subtract(const Duration(days: 1));
    }

    final year = sessionDate.year.toString().padLeft(4, '0');
    final month = sessionDate.month.toString().padLeft(2, '0');
    final day = sessionDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
