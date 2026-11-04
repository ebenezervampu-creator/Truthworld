import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Animated numeric rolling counter for Creator Studio metrics.
/// Smoothly rolls up from 0 to target value on first render or value change.
/// Handles currency ($), percentages (%), abbreviations (K, M, B), and unit suffixes (hrs, mins).
/// Designed with 100% Zero-setState declarative reactivity.
class StudioAnimatedMetricValue extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const StudioAnimatedMetricValue({
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ??
        const TextStyle(
          fontFamily: TWTypography.brandFamily,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        );

    final parsed = _ParsedMetric.parse(value);
    if (!parsed.isNumeric) {
      return Text(
        value,
        style: effectiveStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(value),
      duration: duration,
      curve: curve,
      tween: Tween<double>(begin: 0, end: parsed.targetNumber),
      builder: (context, animatedVal, _) {
        final formattedText = parsed.format(animatedVal);
        return Text(
          formattedText,
          style: effectiveStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _ParsedMetric {
  final bool isNumeric;
  final String prefix;
  final double targetNumber;
  final String suffix;
  final int decimalPlaces;
  final bool hasCommas;

  _ParsedMetric({
    required this.isNumeric,
    required this.prefix,
    required this.targetNumber,
    required this.suffix,
    required this.decimalPlaces,
    required this.hasCommas,
  });

  static final _numberRegex = RegExp(r'^([^0-9.-]*)([0-9,.]+)(.*)$');

  factory _ParsedMetric.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return _ParsedMetric(
        isNumeric: false,
        prefix: '',
        targetNumber: 0,
        suffix: '',
        decimalPlaces: 0,
        hasCommas: false,
      );
    }

    final match = _numberRegex.firstMatch(trimmed);
    if (match == null) {
      return _ParsedMetric(
        isNumeric: false,
        prefix: '',
        targetNumber: 0,
        suffix: trimmed,
        decimalPlaces: 0,
        hasCommas: false,
      );
    }

    final prefix = match.group(1) ?? '';
    final numberStr = match.group(2) ?? '';
    final suffix = match.group(3) ?? '';

    final hasCommas = numberStr.contains(',');
    final cleanNumberStr = numberStr.replaceAll(',', '');
    final parsedNum = double.tryParse(cleanNumberStr);

    if (parsedNum == null) {
      return _ParsedMetric(
        isNumeric: false,
        prefix: prefix,
        targetNumber: 0,
        suffix: suffix,
        decimalPlaces: 0,
        hasCommas: hasCommas,
      );
    }

    var decimalPlaces = 0;
    if (cleanNumberStr.contains('.')) {
      decimalPlaces = cleanNumberStr.split('.')[1].length;
    }

    return _ParsedMetric(
      isNumeric: true,
      prefix: prefix,
      targetNumber: parsedNum,
      suffix: suffix,
      decimalPlaces: decimalPlaces,
      hasCommas: hasCommas,
    );
  }

  String format(double current) {
    String numPart;
    if (decimalPlaces > 0) {
      numPart = current.toStringAsFixed(decimalPlaces);
    } else if (hasCommas) {
      numPart = NumberFormat('#,###').format(current.round());
    } else {
      numPart = current.round().toString();
    }
    return '$prefix$numPart$suffix';
  }
}
