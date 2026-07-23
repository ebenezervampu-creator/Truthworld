import 'package:flutter/material.dart';

/// Semantic shadows and elevation offsets.
class TWShadows extends ThemeExtension<TWShadows> {

  const TWShadows({
    required this.card,
    required this.dialog,
    required this.overlay,
    required this.fab,
  });

  factory TWShadows.defaults() {
    return TWShadows(
      card: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      dialog: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      overlay: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
      fab: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
  final List<BoxShadow> card;
  final List<BoxShadow> dialog;
  final List<BoxShadow> overlay;
  final List<BoxShadow> fab;

  @override
  ThemeExtension<TWShadows> copyWith({
    List<BoxShadow>? card,
    List<BoxShadow>? dialog,
    List<BoxShadow>? overlay,
    List<BoxShadow>? fab,
  }) {
    return TWShadows(
      card: card ?? this.card,
      dialog: dialog ?? this.dialog,
      overlay: overlay ?? this.overlay,
      fab: fab ?? this.fab,
    );
  }

  @override
  ThemeExtension<TWShadows> lerp(ThemeExtension<TWShadows>? other, double t) {
    if (other is! TWShadows) return this;
    return TWShadows(
      card: BoxShadow.lerpList(card, other.card, t)!,
      dialog: BoxShadow.lerpList(dialog, other.dialog, t)!,
      overlay: BoxShadow.lerpList(overlay, other.overlay, t)!,
      fab: BoxShadow.lerpList(fab, other.fab, t)!,
    );
  }
}

extension TWShadowsExtension on BuildContext {
  TWShadows get shadows => Theme.of(this).extension<TWShadows>()!;
}
