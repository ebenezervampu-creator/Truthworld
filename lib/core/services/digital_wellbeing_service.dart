import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Service responsible for managing Take a Break reminders and Bedtime reminders.
class DigitalWellbeingService extends GetxService {
  static DigitalWellbeingService get to {
    if (!Get.isRegistered<DigitalWellbeingService>()) {
      Get.put(DigitalWellbeingService(), permanent: true);
    }
    return Get.find<DigitalWellbeingService>();
  }

  Timer? _tickerTimer;
  int _activeWatchSeconds = 0;
  bool _isBreakPromptOpen = false;
  bool _hasPromptedBedtimeToday = false;
  DateTime? _lastBedtimePromptDate;

  int get activeWatchSeconds => _activeWatchSeconds;
  bool get isBreakPromptOpen => _isBreakPromptOpen;

  @override
  void onInit() {
    super.onInit();
    _startWellbeingTicker();
  }

  @override
  void onClose() {
    _tickerTimer?.cancel();
    super.onClose();
  }

  /// Start 1-second ticker to track active time and check schedules
  void _startWellbeingTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (!Get.isRegistered<UserSettingsController>()) return;
    final settings = UserSettingsController.to.wellbeing.value;

    // 1. Break Reminder Tracking
    if (settings.breakReminderMinutes > 0) {
      _activeWatchSeconds++;
      final targetSeconds = settings.breakReminderMinutes * 60;
      if (_activeWatchSeconds >= targetSeconds && !_isBreakPromptOpen) {
        _showBreakReminderDialog(settings.breakReminderMinutes);
      }
    } else {
      _activeWatchSeconds = 0;
    }

    // 2. Bedtime Reminder Tracking (Check once every minute on the 0th second)
    if (settings.bedtimeEnabled && _activeWatchSeconds % 60 == 0) {
      _checkBedtimeSchedule(settings);
    }
  }

  /// Reset or snooze the active watch timer
  void resetBreakTimer() {
    _activeWatchSeconds = 0;
  }

  void snoozeBreakTimer({int minutes = 10}) {
    // Set watch seconds so the next prompt arrives in [minutes]
    if (!Get.isRegistered<UserSettingsController>()) return;
    final totalMinutes =
        UserSettingsController.to.wellbeing.value.breakReminderMinutes;
    _activeWatchSeconds = ((totalMinutes - minutes).clamp(0, totalMinutes)) * 60;
  }

  void _showBreakReminderDialog(int intervalMinutes) {
    _isBreakPromptOpen = true;
    final context = Get.context;
    if (context == null) return;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text(
              'Time for a Break',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "You've been watching videos for $intervalMinutes minutes. Taking regular breaks helps protect your eyes and wellbeing.",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              snoozeBreakTimer();
              _isBreakPromptOpen = false;
              Get.back();
            },
            child: const Text(
              'Snooze (10m)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              resetBreakTimer();
              _isBreakPromptOpen = false;
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _checkBedtimeSchedule(dynamic settings) {
    final now = DateTime.now();

    // Check repeat days
    final scheduleDays = settings.bedtimeDaysSchedule as String? ?? 'Everyday';
    final weekday = now.weekday; // 1 = Mon, 7 = Sun
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;

    if (scheduleDays == 'Weekdays' && isWeekend) return;
    if (scheduleDays == 'Weekends' && !isWeekend) return;

    // Reset daily bedtime prompt if new day
    if (_lastBedtimePromptDate != null &&
        _lastBedtimePromptDate!.day != now.day) {
      _hasPromptedBedtimeToday = false;
    }

    if (_hasPromptedBedtimeToday) return;

    final startTimeStr = settings.bedtimeStartTime as String? ?? '23:00';
    final endTimeStr = settings.bedtimeEndTime as String? ?? '06:00';

    final startMinutes = _parseTimeToMinutes(startTimeStr);
    final endMinutes = _parseTimeToMinutes(endTimeStr);
    final currentMinutes = now.hour * 60 + now.minute;

    var isBedtime = false;
    if (startMinutes <= endMinutes) {
      // Normal range within same day (e.g. 13:00 to 15:00)
      isBedtime = currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight range (e.g. 23:00 to 06:00)
      isBedtime = currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }

    if (isBedtime) {
      _hasPromptedBedtimeToday = true;
      _lastBedtimePromptDate = now;
      _showBedtimeReminderBanner(startTimeStr, endTimeStr);
    }
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final trimmed = timeStr.trim();
      if (trimmed.contains('AM') || trimmed.contains('PM')) {
        final parsed = DateFormat('h:mm a').parse(trimmed);
        return parsed.hour * 60 + parsed.minute;
      }
      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return h * 60 + m;
      }
    } catch (e) {
      logger.warning('Failed to parse bedtime string "$timeStr": $e');
    }
    return 23 * 60; // fallback 11:00 PM
  }

  void _showBedtimeReminderBanner(String startTime, String endTime) {
    Get.snackbar(
      'Bedtime Reminder',
      'It is your scheduled bedtime ($startTime – $endTime). Time to rest!',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1E1E1E),
      colorText: AppColors.textPrimary,
      icon: const Icon(Icons.bedtime_outlined, color: Colors.white),
      duration: const Duration(seconds: 8),
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
        },
        child: const Text('OK', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
