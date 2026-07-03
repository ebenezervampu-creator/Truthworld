import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

void main() {
  group('TimestampUtils Tests', () {
    test('parse should return same Timestamp if value is Timestamp', () {
      final ts = Timestamp(123456, 789);
      final result = TimestampUtils.parse(ts);
      expect(result, equals(ts));
    });

    test('parse should convert DateTime to Timestamp', () {
      final now = DateTime.now();
      final result = TimestampUtils.parse(now);
      expect(result.seconds, equals(now.millisecondsSinceEpoch ~/ 1000));
    });

    test('parse should convert millisecond int to Timestamp', () {
      const ms = 1782959849815;
      final result = TimestampUtils.parse(ms);
      expect(result.millisecondsSinceEpoch, equals(ms));
    });

    test('parse should convert seconds int to Timestamp', () {
      const sec = 1782959849;
      final result = TimestampUtils.parse(sec);
      expect(result.seconds, equals(sec));
    });

    test('parse should convert numeric String to Timestamp', () {
      const msStr = '1782959849815';
      final result = TimestampUtils.parse(msStr);
      expect(result.millisecondsSinceEpoch, equals(1782959849815));
    });

    test('parse should convert ISO date string to Timestamp', () {
      const dateStr = '2026-07-02T12:00:00.000Z';
      final result = TimestampUtils.parse(dateStr);
      expect(result.millisecondsSinceEpoch, equals(DateTime.parse(dateStr).millisecondsSinceEpoch));
    });

    test('parseToDateTime should return correct DateTime for various inputs', () {
      final now = DateTime.now();
      expect(TimestampUtils.parseToDateTime(now), equals(now));

      final ts = Timestamp.fromDate(now);
      expect(TimestampUtils.parseToDateTime(ts), equals(now));

      const ms = 1782959849815;
      expect(TimestampUtils.parseToDateTime(ms), equals(DateTime.fromMillisecondsSinceEpoch(ms)));
    });
  });
}
