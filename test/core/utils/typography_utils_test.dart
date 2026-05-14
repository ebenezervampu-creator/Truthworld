import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/typography_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TypographyUtils Tests', () {
    test('measureText should return valid dimensions', () {
      const text = 'Hello Truthworld';
      const style = TextStyle(fontSize: 16.0);
      
      final measurement = TypographyUtils.measureText(
        text: text,
        style: style,
      );

      expect(measurement.width, isPositive);
      expect(measurement.height, isPositive);
      expect(measurement.lineCount, equals(1));
    });

    test('measureText should handle multi-line text', () {
      const text = 'This is a long text that should wrap into multiple lines if the width is small enough.';
      const style = TextStyle(fontSize: 16.0);
      const maxWidth = 100.0;
      
      final measurement = TypographyUtils.measureText(
        text: text,
        style: style,
        maxWidth: maxWidth,
      );

      expect(measurement.width, lessThanOrEqualTo(maxWidth));
      expect(measurement.lineCount, greaterThan(1));
    });
  });
}
