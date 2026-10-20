import 'package:flutter/material.dart';

/// Industry-standard accessible tap target.
///
/// Replaces bare [GestureDetector] and [InkWell] with proper screen reader
/// semantics. Every tappable surface in TruthWorld MUST use this widget
/// or a Material widget (ElevatedButton, IconButton, etc.).
///
/// WCAG 2.1 SC 4.1.2: All interactive elements must have accessible names.
/// WCAG 2.1 SC 2.5.5: Target size minimum 44x44 logical pixels (AAA).
///
/// Usage:
/// ```dart
/// AccessibleTap(
///   semanticLabel: 'Play video: How AI Works',
///   onTap: () => playVideo(),
///   child: VideoThumbnail(...),
/// )
/// ```
class AccessibleTap extends StatelessWidget {
  const AccessibleTap({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.onDoubleTap,
    this.semanticHint,
    this.isButton = true,
    this.isEnabled = true,
    this.isSelected,
    this.isToggled,
    this.excludeSemantics = false,
    this.enableFeedback = true,
    this.minTapTargetSize = 48.0, // Android & WCAG standard 48x48dp minimum
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    super.key,
  });

  /// Screen reader label (read aloud). REQUIRED.
  final String semanticLabel;

  /// Optional hint for screen readers (e.g., "Double tap to play")
  final String? semanticHint;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final Widget child;

  /// Whether this is semantically a button (default: true)
  final bool isButton;
  final bool isEnabled;
  final bool? isSelected;
  final bool? isToggled;
  final bool excludeSemantics;
  final bool enableFeedback;

  /// Minimum tap target size per WCAG 2.1 SC 2.5.5 (AAA: 44px)
  final double minTapTargetSize;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: isButton,
      enabled: isEnabled,
      selected: isSelected,
      toggled: isToggled,
      excludeSemantics: excludeSemantics,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTapTargetSize,
          minHeight: minTapTargetSize,
        ),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          onLongPress: isEnabled ? onLongPress : null,
          onDoubleTap: isEnabled ? onDoubleTap : null,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          splashColor: splashColor,
          highlightColor: highlightColor,
          enableFeedback: enableFeedback,
          child: child,
        ),
      ),
    );
  }
}

/// Accessible icon button with enforced semantic label.
///
/// Use instead of bare IconButton when custom styling is needed.
/// Material's IconButton already has tooltip-based semantics, but this
/// provides additional control.
class AccessibleIconAction extends StatelessWidget {
  const AccessibleIconAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 24.0,
    this.color,
    this.padding = const EdgeInsets.all(8),
    this.tooltip,
    this.isEnabled = true,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size, color: color),
      onPressed: isEnabled ? onPressed : null,
      tooltip: tooltip ?? semanticLabel,
      padding: padding,
      constraints: const BoxConstraints(
        minWidth: 48, // Android Material standard
        minHeight: 48,
      ),
    );
  }
}
