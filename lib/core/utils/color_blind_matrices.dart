/// Standard 4x5 color transformation matrices for simulating/correcting
/// color vision deficiencies (Protanopia, Deuteranopia, Tritanopia).
class ColorBlindMatrices {
  ColorBlindMatrices._();

  /// Standard matrix for Protanopia (red-weak/blindness)
  static const List<double> protanopia = <double>[
    0.56667, 0.43333, 0.00000, 0.0, 0.0,
    0.55833, 0.44167, 0.00000, 0.0, 0.0,
    0.00000, 0.24167, 0.75833, 0.0, 0.0,
    0.00000, 0.00000, 0.00000, 1.0, 0.0,
  ];

  /// Standard matrix for Deuteranopia (green-weak/blindness)
  static const List<double> deuteranopia = <double>[
    0.62500, 0.37500, 0.00000, 0.0, 0.0,
    0.70000, 0.30000, 0.00000, 0.0, 0.0,
    0.00000, 0.30000, 0.70000, 0.0, 0.0,
    0.00000, 0.00000, 0.00000, 1.0, 0.0,
  ];

  /// Standard matrix for Tritanopia (blue-weak/blindness)
  static const List<double> tritanopia = <double>[
    0.95000, 0.05000, 0.00000, 0.0, 0.0,
    0.00000, 0.43333, 0.56667, 0.0, 0.0,
    0.00000, 0.47500, 0.52500, 0.0, 0.0,
    0.00000, 0.00000, 0.00000, 1.0, 0.0,
  ];

  /// Get matrix by setting mode name ('Protanopia', 'Deuteranopia', 'Tritanopia', or full label)
  static List<double>? getMatrix(String mode) {
    if (mode.contains('Protanopia')) {
      return protanopia;
    } else if (mode.contains('Deuteranopia')) {
      return deuteranopia;
    } else if (mode.contains('Tritanopia')) {
      return tritanopia;
    }
    return null;
  }
}
