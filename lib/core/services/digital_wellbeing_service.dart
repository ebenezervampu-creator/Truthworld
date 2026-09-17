import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/time_of_day_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/features/settings/data/models/digital_wellbeing_settings.dart';
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

  // Bedtime tracking state
  String? _activeBedtimeSessionKey;
  DateTime? _bedtimeSnoozedUntil;
  int _clockCheckTickCount = 0;

  int get activeWatchSeconds => _activeWatchSeconds;
  bool get isBreakPromptOpen => _isBreakPromptOpen;
  String? get activeBedtimeSessionKey => _activeBedtimeSessionKey;
  bool get isBedtimeSnoozed =>
      _bedtimeSnoozedUntil != null &&
      DateTime.now().isBefore(_bedtimeSnoozedUntil!);

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

    // 2. Bedtime Reminder Tracking (Checked every 15 seconds independently from watch time)
    _clockCheckTickCount++;
    if (_clockCheckTickCount >= 15) {
      _clockCheckTickCount = 0;
      if (settings.bedtimeEnabled) {
        _checkBedtimeSchedule(settings);
      }
    }
  }

  /// Trigger an immediate evaluation of the bedtime schedule (e.g. after settings update)
  void checkBedtimeNow() {
    if (!Get.isRegistered<UserSettingsController>()) return;
    final settings = UserSettingsController.to.wellbeing.value;
    if (settings.bedtimeEnabled) {
      _checkBedtimeSchedule(settings);
    }
  }

  /// Check whether bedtime is currently active based on current time and settings
  bool isBedtimeActive() {
    if (!Get.isRegistered<UserSettingsController>()) return false;
    final settings = UserSettingsController.to.wellbeing.value;
    if (!settings.bedtimeEnabled) return false;

    final now = DateTime.now();
    if (!TimeOfDayHelper.isScheduleActiveOnDay(
      settings.bedtimeDaysSchedule,
      now.weekday,
    )) {
      return false;
    }

    final start = TimeOfDayHelper.parse(settings.bedtimeStartTime);
    final end = TimeOfDayHelper.parse(
      settings.bedtimeEndTime,
      fallback: const TimeOfDay(hour: 6, minute: 0),
    );

    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    return TimeOfDayHelper.isTimeWithinWindow(currentTime, start, end);
  }

  /// Indicates whether autoplay should be paused because bedtime is active
  bool shouldPauseAutoplayDuringBedtime() {
    if (!Get.isRegistered<UserSettingsController>()) return false;
    final settings = UserSettingsController.to.wellbeing.value;
    return isBedtimeActive() && settings.pauseAutoplayDuringBedtime;
  }

  /// Indicates whether notifications should be muted because bedtime is active
  bool shouldMuteNotificationsDuringBedtime() {
    if (!Get.isRegistered<UserSettingsController>()) return false;
    final settings = UserSettingsController.to.wellbeing.value;
    return isBedtimeActive() && settings.muteNotificationsDuringBedtime;
  }

  /// Reset or snooze the active watch timer for Break Reminder
  void resetBreakTimer() {
    _activeWatchSeconds = 0;
  }

  void snoozeBreakTimer({int minutes = 10}) {
    if (!Get.isRegistered<UserSettingsController>()) return;
    final totalMinutes =
        UserSettingsController.to.wellbeing.value.breakReminderMinutes;
    _activeWatchSeconds = ((totalMinutes - minutes).clamp(0, totalMinutes)) * 60;
  }

  /// Snooze bedtime reminder for the specified duration (default 10 minutes)
  void snoozeBedtimeReminder({int minutes = 10}) {
    _bedtimeSnoozedUntil = DateTime.now().add(Duration(minutes: minutes));
    logger.info('Bedtime reminder snoozed for $minutes minutes');
    AppToast.info(
      'Bedtime reminder snoozed for $minutes minutes',
      duration: const Duration(seconds: 2),
    );
  }

  /// Dismiss bedtime reminder for the remainder of the current bedtime cycle
  void dismissBedtimeReminder() {
    if (!Get.isRegistered<UserSettingsController>()) return;
    final settings = UserSettingsController.to.wellbeing.value;
    final now = DateTime.now();
    final start = TimeOfDayHelper.parse(settings.bedtimeStartTime);
    final end = TimeOfDayHelper.parse(
      settings.bedtimeEndTime,
      fallback: const TimeOfDay(hour: 6, minute: 0),
    );

    _activeBedtimeSessionKey = TimeOfDayHelper.getSessionKey(
      now: now,
      start: start,
      end: end,
    );
    _bedtimeSnoozedUntil = null;
    logger.info('Bedtime reminder dismissed for session: $_activeBedtimeSessionKey');
  }

  /// Reset bedtime tracking state (e.g. when bedtime settings are toggled)
  void resetBedtimeTracking() {
    _activeBedtimeSessionKey = null;
    _bedtimeSnoozedUntil = null;
    _clockCheckTickCount = 0;
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

  void _checkBedtimeSchedule(DigitalWellbeingSettings settings) {
    final now = DateTime.now();

    // Check repeat days
    if (!TimeOfDayHelper.isScheduleActiveOnDay(
      settings.bedtimeDaysSchedule,
      now.weekday,
    )) {
      return;
    }

    final start = TimeOfDayHelper.parse(settings.bedtimeStartTime);
    final end = TimeOfDayHelper.parse(
      settings.bedtimeEndTime,
      fallback: const TimeOfDay(hour: 6, minute: 0),
    );

    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    final isWithin = TimeOfDayHelper.isTimeWithinWindow(currentTime, start, end);

    if (!isWithin) {
      // Outside bedtime window: reset snooze so next scheduled cycle triggers cleanly
      _bedtimeSnoozedUntil = null;
      return;
    }

    final currentSessionKey = TimeOfDayHelper.getSessionKey(
      now: now,
      start: start,
      end: end,
    );

    // If currently snoozed, check if snooze has elapsed
    if (_bedtimeSnoozedUntil != null) {
      if (now.isBefore(_bedtimeSnoozedUntil!)) {
        return; // Snooze still active
      }
      _bedtimeSnoozedUntil = null; // Snooze elapsed, proceed to prompt
    } else if (_activeBedtimeSessionKey == currentSessionKey) {
      // Already prompted or dismissed for this current session
      return;
    }

    _activeBedtimeSessionKey = currentSessionKey;
    _showBedtimeReminderBanner(settings.bedtimeStartTime, settings.bedtimeEndTime);
  }

  void _showBedtimeReminderBanner(String startTime, String endTime) {
    AppSnackbar.show(
      'Bedtime Reminder',
      'It is your scheduled bedtime ($startTime – $endTime). Time to rest!',
      icon: const Icon(Icons.bedtime_outlined, color: Colors.white),
      duration: const Duration(seconds: 10),
      mainButton: TextButton(
        onPressed: snoozeBedtimeReminder,
        child: const Text(
          'Snooze (10m)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
