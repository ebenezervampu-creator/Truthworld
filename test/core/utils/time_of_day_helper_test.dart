import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/time_of_day_helper.dart';

void main() {
  group('TimeOfDayHelper', () {
    test('parses 12-hour format with AM and PM', () {
      final t1 = TimeOfDayHelper.parse('11:00 PM');
      expect(t1.hour, equals(23));
      expect(t1.minute, equals(0));

      final t2 = TimeOfDayHelper.parse('06:30 AM');
      expect(t2.hour, equals(6));
      expect(t2.minute, equals(30));

      final t3 = TimeOfDayHelper.parse('12:00 AM');
      expect(t3.hour, equals(0));
      expect(t3.minute, equals(0));

      final t4 = TimeOfDayHelper.parse('12:15 PM');
      expect(t4.hour, equals(12));
      expect(t4.minute, equals(15));
    });

    test('parses lowercase am/pm and tight spacing', () {
      final t1 = TimeOfDayHelper.parse('11:00pm');
      expect(t1.hour, equals(23));
      expect(t1.minute, equals(0));

      final t2 = TimeOfDayHelper.parse('7:45am');
      expect(t2.hour, equals(7));
      expect(t2.minute, equals(45));
    });

    test('parses 24-hour format strings', () {
      final t1 = TimeOfDayHelper.parse('23:00');
      expect(t1.hour, equals(23));
      expect(t1.minute, equals(0));

      final t2 = TimeOfDayHelper.parse('06:00');
      expect(t2.hour, equals(6));
      expect(t2.minute, equals(0));

      final t3 = TimeOfDayHelper.parse('0:00');
      expect(t3.hour, equals(0));
      expect(t3.minute, equals(0));
    });

    test(r'handles narrow non-breaking space (\u202F)', () {
      final t1 = TimeOfDayHelper.parse('11:00\u202FPM');
      expect(t1.hour, equals(23));
      expect(t1.minute, equals(0));

      final t2 = TimeOfDayHelper.parse('06:00\u00A0AM');
      expect(t2.hour, equals(6));
      expect(t2.minute, equals(0));
    });

    test('falls back gracefully on invalid strings', () {
      const fallback = TimeOfDay(hour: 22, minute: 30);
      final t1 = TimeOfDayHelper.parse('invalid', fallback: fallback);
      expect(t1.hour, equals(22));
      expect(t1.minute, equals(30));

      final t2 = TimeOfDayHelper.parse('', fallback: fallback);
      expect(t2.hour, equals(22));
      expect(t2.minute, equals(30));

      final t3 = TimeOfDayHelper.parse(null, fallback: fallback);
      expect(t3.hour, equals(22));
      expect(t3.minute, equals(30));
    });

    test('formats TimeOfDay to standard 12-hour string', () {
      expect(
        TimeOfDayHelper.format(const TimeOfDay(hour: 23, minute: 0)),
        equals('11:00 PM'),
      );
      expect(
        TimeOfDayHelper.format(const TimeOfDay(hour: 6, minute: 5)),
        equals('06:05 AM'),
      );
      expect(
        TimeOfDayHelper.format(const TimeOfDay(hour: 0, minute: 0)),
        equals('12:00 AM'),
      );
      expect(
        TimeOfDayHelper.format(const TimeOfDay(hour: 12, minute: 0)),
        equals('12:00 PM'),
      );
    });

    test('correctly evaluates same-day time window', () {
      const start = TimeOfDay(hour: 13, minute: 0); // 1:00 PM
      const end = TimeOfDay(hour: 15, minute: 0);   // 3:00 PM

      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 14, minute: 0),
          start,
          end,
        ),
        isTrue,
      );
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 12, minute: 59),
          start,
          end,
        ),
        isFalse,
      );
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 15, minute: 1),
          start,
          end,
        ),
        isFalse,
      );
    });

    test('correctly evaluates overnight time window across midnight', () {
      const start = TimeOfDay(hour: 23, minute: 0); // 11:00 PM
      const end = TimeOfDay(hour: 6, minute: 0);    // 6:00 AM

      // Before midnight (11:30 PM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 23, minute: 30),
          start,
          end,
        ),
        isTrue,
      );
      // At start (11:00 PM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 23, minute: 0),
          start,
          end,
        ),
        isTrue,
      );
      // Midnight (12:00 AM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 0, minute: 0),
          start,
          end,
        ),
        isTrue,
      );
      // After midnight (2:00 AM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 2, minute: 0),
          start,
          end,
        ),
        isTrue,
      );
      // At end (6:00 AM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 6, minute: 0),
          start,
          end,
        ),
        isTrue,
      );
      // Outside window (6:01 AM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 6, minute: 1),
          start,
          end,
        ),
        isFalse,
      );
      // Afternoon (2:00 PM)
      expect(
        TimeOfDayHelper.isTimeWithinWindow(
          const TimeOfDay(hour: 14, minute: 0),
          start,
          end,
        ),
        isFalse,
      );
    });

    test('evaluates repeat days schedule accurately', () {
      // Monday = 1, Saturday = 6, Sunday = 7
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Everyday', 1), isTrue);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Everyday', 6), isTrue);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Everyday', 7), isTrue);

      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekdays', 1), isTrue);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekdays', 5), isTrue);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekdays', 6), isFalse);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekdays', 7), isFalse);

      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekends', 1), isFalse);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekends', 5), isFalse);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekends', 6), isTrue);
      expect(TimeOfDayHelper.isScheduleActiveOnDay('Weekends', 7), isTrue);
    });

    test('computes consistent session key across midnight boundary', () {
      const start = TimeOfDay(hour: 23, minute: 0);
      const end = TimeOfDay(hour: 6, minute: 0);

      // 11:30 PM on Monday Sept 14
      final mondayNight = DateTime(2026, 9, 14, 23, 30);
      final key1 = TimeOfDayHelper.getSessionKey(
        now: mondayNight,
        start: start,
        end: end,
      );
      expect(key1, equals('2026-09-14'));

      // 02:00 AM on Tuesday Sept 15 (same overnight sleep cycle)
      final tuesdayMorning = DateTime(2026, 9, 15, 2);
      final key2 = TimeOfDayHelper.getSessionKey(
        now: tuesdayMorning,
        start: start,
        end: end,
      );
      // Must equal Monday's key so midnight does not re-trigger!
      expect(key2, equals('2026-09-14'));

      // 11:15 PM on Tuesday Sept 15 (next cycle)
      final tuesdayNight = DateTime(2026, 9, 15, 23, 15);
      final key3 = TimeOfDayHelper.getSessionKey(
        now: tuesdayNight,
        start: start,
        end: end,
      );
      expect(key3, equals('2026-09-15'));
    });
  });
}
