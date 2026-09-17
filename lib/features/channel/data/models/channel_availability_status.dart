import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

enum AvailabilityStatus { unknown, checking, available, taken, invalid, error }

extension AvailabilityStatusExtension on AvailabilityStatus {
  Color get color {
    switch (this) {
      case AvailabilityStatus.unknown:
        return AppColors.textSecondary;
      case AvailabilityStatus.checking:
        return const Color(0xFFF59E0B);
      case AvailabilityStatus.available:
        return AppColors.success;
      case AvailabilityStatus.taken:
      case AvailabilityStatus.invalid:
      case AvailabilityStatus.error:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case AvailabilityStatus.unknown:
        return Icons.help_outline;
      case AvailabilityStatus.checking:
        return Icons.hourglass_empty;
      case AvailabilityStatus.available:
        return Icons.check_circle;
      case AvailabilityStatus.taken:
        return Icons.cancel;
      case AvailabilityStatus.invalid:
      case AvailabilityStatus.error:
        return Icons.error;
    }
  }

  String get message {
    switch (this) {
      case AvailabilityStatus.unknown:
        return '';
      case AvailabilityStatus.checking:
        return 'Checking availability...';
      case AvailabilityStatus.available:
        return 'Available!';
      case AvailabilityStatus.taken:
        return 'This name is already taken';
      case AvailabilityStatus.invalid:
        return 'Invalid format';
      case AvailabilityStatus.error:
        return 'Error checking availability';
    }
  }
}
