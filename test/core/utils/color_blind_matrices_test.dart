import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/color_blind_matrices.dart';

void main() {
  group('ColorBlindMatrices', () {
    test('returns null for "Off" or unknown mode', () {
      expect(ColorBlindMatrices.getMatrix('Off'), isNull);
      expect(ColorBlindMatrices.getMatrix('None'), isNull);
      expect(ColorBlindMatrices.getMatrix(''), isNull);
    });

    test('returns correct 20-element 4x5 matrix for Protanopia', () {
      final matrix = ColorBlindMatrices.getMatrix('Protanopia (Red-blind)');
      expect(matrix, isNotNull);
      expect(matrix!.length, equals(20));
      expect(matrix, equals(ColorBlindMatrices.protanopia));
    });

    test('returns correct 20-element 4x5 matrix for Deuteranopia', () {
      final matrix = ColorBlindMatrices.getMatrix('Deuteranopia (Green-blind)');
      expect(matrix, isNotNull);
      expect(matrix!.length, equals(20));
      expect(matrix, equals(ColorBlindMatrices.deuteranopia));
    });

    test('returns correct 20-element 4x5 matrix for Tritanopia', () {
      final matrix = ColorBlindMatrices.getMatrix('Tritanopia (Blue-blind)');
      expect(matrix, isNotNull);
      expect(matrix!.length, equals(20));
      expect(matrix, equals(ColorBlindMatrices.tritanopia));
    });

    test('partial string matches also resolve correctly', () {
      expect(
        ColorBlindMatrices.getMatrix('Protanopia'),
        equals(ColorBlindMatrices.protanopia),
      );
      expect(
        ColorBlindMatrices.getMatrix('Deuteranopia'),
        equals(ColorBlindMatrices.deuteranopia),
      );
      expect(
        ColorBlindMatrices.getMatrix('Tritanopia'),
        equals(ColorBlindMatrices.tritanopia),
      );
    });
  });
}
