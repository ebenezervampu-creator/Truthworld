import 'package:flutter/material.dart';

/// Centralized gradients for the application.
class TWGradients extends ThemeExtension<TWGradients> {
  const TWGradients({
    required this.primary,
    required this.brand,
    required this.success,
    required this.warning,
    required this.error,
  });

  factory TWGradients.defaults() {
    return const TWGradients(
      primary: LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      brand: LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      success: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      warning: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      error: LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }
  final LinearGradient primary;
  final LinearGradient brand;
  final LinearGradient success;
  final LinearGradient warning;
  final LinearGradient error;

  @override
  ThemeExtension<TWGradients> copyWith({
    LinearGradient? primary,
    LinearGradient? brand,
    LinearGradient? success,
    LinearGradient? warning,
    LinearGradient? error,
  }) {
    return TWGradients(
      primary: primary ?? this.primary,
      brand: brand ?? this.brand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  ThemeExtension<TWGradients> lerp(
    ThemeExtension<TWGradients>? other,
    double t,
  ) {
    if (other is! TWGradients) return this;
    return TWGradients(
      primary: LinearGradient.lerp(primary, other.primary, t)!,
      brand: LinearGradient.lerp(brand, other.brand, t)!,
      success: LinearGradient.lerp(success, other.success, t)!,
      warning: LinearGradient.lerp(warning, other.warning, t)!,
      error: LinearGradient.lerp(error, other.error, t)!,
    );
  }
}

extension TWGradientsExtension on BuildContext {
  TWGradients get gradients => Theme.of(this).extension<TWGradients>()!;
}
