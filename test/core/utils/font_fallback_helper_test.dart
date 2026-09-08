import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/font_fallback_helper.dart';

void main() {
  group('FontFallbackHelper', () {
    test('stripVariationSelectors removes U+FE0F from heart emoji', () {
      const withSelector = 'Made with ❤️ for creators';
      final cleaned = stripVariationSelectors(withSelector);

      // U+FE0F should be stripped, leaving base heart U+2764
      expect(cleaned.contains('\uFE0F'), isFalse);
      expect(cleaned, equals('Made with \u2764 for creators'));
    });

    test('stripVariationSelectors removes U+FE0F from warning emoji', () {
      const withSelector = '⚠️ Warning';
      final cleaned = stripVariationSelectors(withSelector);

      expect(cleaned.contains('\uFE0F'), isFalse);
      expect(cleaned, equals('\u26A0 Warning'));
    });

    test('FontFallbackStringExtension provides .safeText and .safeEmoji', () {
      const withSelector = 'Debate ⚔️ in progress';
      expect(withSelector.safeText.contains('\uFE0F'), isFalse);
      expect(withSelector.safeEmoji.contains('\uFE0F'), isFalse);
      expect(withSelector.safeText, equals('Debate \u2694 in progress'));
    });

    test('Handles empty strings and plain ASCII cleanly', () {
      expect(''.safeText, equals(''));
      expect('Hello World'.safeText, equals('Hello World'));
    });
  });
}
