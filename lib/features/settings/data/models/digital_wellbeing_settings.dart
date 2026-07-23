import 'dart:convert';
import 'package:crypto/crypto.dart';

class DigitalWellbeingSettings {

  const DigitalWellbeingSettings({
    this.breakReminderMinutes = 0,
    this.lastBreakReminderTime,
    this.continuousWatchDurationMinutes = 0,
    this.ignoreBreakCasting = true,
    this.ignoreBreakFullscreen = false,
    this.bedtimeEnabled = false,
    this.bedtimeStartTime = '11:00 PM',
    this.bedtimeEndTime = '06:00 AM',
    this.bedtimeDaysSchedule = 'Everyday',
    this.pauseAutoplayDuringBedtime = true,
    this.muteNotificationsDuringBedtime = true,
    this.parentalPinEnabled = false,
    this.hashedPin,
    this.failedPinAttempts = 0,
    this.lockoutUntil,
    this.hideMatureContent = false,
    this.blockDownloads = false,
    this.blockPurchases = false,
    this.blockSettingsChanges = false,
  });

  factory DigitalWellbeingSettings.fromJson(Map<String, dynamic> json) {
    return DigitalWellbeingSettings(
      breakReminderMinutes: json['breakReminderMinutes'] as int? ?? 0,
      lastBreakReminderTime: json['lastBreakReminderTime'] as String?,
      continuousWatchDurationMinutes: json['continuousWatchDurationMinutes'] as int? ?? 0,
      ignoreBreakCasting: json['ignoreBreakCasting'] as bool? ?? true,
      ignoreBreakFullscreen: json['ignoreBreakFullscreen'] as bool? ?? false,
      bedtimeEnabled: json['bedtimeEnabled'] as bool? ?? false,
      bedtimeStartTime: json['bedtimeStartTime'] as String? ?? '11:00 PM',
      bedtimeEndTime: json['bedtimeEndTime'] as String? ?? '06:00 AM',
      bedtimeDaysSchedule: json['bedtimeDaysSchedule'] as String? ?? 'Everyday',
      pauseAutoplayDuringBedtime: json['pauseAutoplayDuringBedtime'] as bool? ?? true,
      muteNotificationsDuringBedtime: json['muteNotificationsDuringBedtime'] as bool? ?? true,
      parentalPinEnabled: json['parentalPinEnabled'] as bool? ?? false,
      hashedPin: json['hashedPin'] as String?,
      failedPinAttempts: json['failedPinAttempts'] as int? ?? 0,
      lockoutUntil: json['lockoutUntil'] as String?,
      hideMatureContent: json['hideMatureContent'] as bool? ?? false,
      blockDownloads: json['blockDownloads'] as bool? ?? false,
      blockPurchases: json['blockPurchases'] as bool? ?? false,
      blockSettingsChanges: json['blockSettingsChanges'] as bool? ?? false,
    );
  }
  final int breakReminderMinutes;
  final String? lastBreakReminderTime;
  final int continuousWatchDurationMinutes;
  final bool ignoreBreakCasting;
  final bool ignoreBreakFullscreen;

  final bool bedtimeEnabled;
  final String bedtimeStartTime;
  final String bedtimeEndTime;
  final String bedtimeDaysSchedule; // 'Everyday', 'Weekdays', 'Weekends'
  final bool pauseAutoplayDuringBedtime;
  final bool muteNotificationsDuringBedtime;

  final bool parentalPinEnabled;
  final String? hashedPin; // SHA-256
  final int failedPinAttempts;
  final String? lockoutUntil;
  final bool hideMatureContent;
  final bool blockDownloads;
  final bool blockPurchases;
  final bool blockSettingsChanges;

  static String hashPin(String rawPin) {
    final bytes = utf8.encode(rawPin);
    return sha256.convert(bytes).toString();
  }

  bool verifyPin(String rawPin) {
    if (hashedPin == null) return false;
    return hashPin(rawPin) == hashedPin;
  }

  DigitalWellbeingSettings copyWith({
    int? breakReminderMinutes,
    String? lastBreakReminderTime,
    int? continuousWatchDurationMinutes,
    bool? ignoreBreakCasting,
    bool? ignoreBreakFullscreen,
    bool? bedtimeEnabled,
    String? bedtimeStartTime,
    String? bedtimeEndTime,
    String? bedtimeDaysSchedule,
    bool? pauseAutoplayDuringBedtime,
    bool? muteNotificationsDuringBedtime,
    bool? parentalPinEnabled,
    String? hashedPin,
    int? failedPinAttempts,
    String? lockoutUntil,
    bool? hideMatureContent,
    bool? blockDownloads,
    bool? blockPurchases,
    bool? blockSettingsChanges,
  }) {
    return DigitalWellbeingSettings(
      breakReminderMinutes: breakReminderMinutes ?? this.breakReminderMinutes,
      lastBreakReminderTime: lastBreakReminderTime ?? this.lastBreakReminderTime,
      continuousWatchDurationMinutes: continuousWatchDurationMinutes ?? this.continuousWatchDurationMinutes,
      ignoreBreakCasting: ignoreBreakCasting ?? this.ignoreBreakCasting,
      ignoreBreakFullscreen: ignoreBreakFullscreen ?? this.ignoreBreakFullscreen,
      bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
      bedtimeStartTime: bedtimeStartTime ?? this.bedtimeStartTime,
      bedtimeEndTime: bedtimeEndTime ?? this.bedtimeEndTime,
      bedtimeDaysSchedule: bedtimeDaysSchedule ?? this.bedtimeDaysSchedule,
      pauseAutoplayDuringBedtime: pauseAutoplayDuringBedtime ?? this.pauseAutoplayDuringBedtime,
      muteNotificationsDuringBedtime: muteNotificationsDuringBedtime ?? this.muteNotificationsDuringBedtime,
      parentalPinEnabled: parentalPinEnabled ?? this.parentalPinEnabled,
      hashedPin: hashedPin ?? this.hashedPin,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockoutUntil: lockoutUntil ?? this.lockoutUntil,
      hideMatureContent: hideMatureContent ?? this.hideMatureContent,
      blockDownloads: blockDownloads ?? this.blockDownloads,
      blockPurchases: blockPurchases ?? this.blockPurchases,
      blockSettingsChanges: blockSettingsChanges ?? this.blockSettingsChanges,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'breakReminderMinutes': breakReminderMinutes,
      'lastBreakReminderTime': lastBreakReminderTime,
      'continuousWatchDurationMinutes': continuousWatchDurationMinutes,
      'ignoreBreakCasting': ignoreBreakCasting,
      'ignoreBreakFullscreen': ignoreBreakFullscreen,
      'bedtimeEnabled': bedtimeEnabled,
      'bedtimeStartTime': bedtimeStartTime,
      'bedtimeEndTime': bedtimeEndTime,
      'bedtimeDaysSchedule': bedtimeDaysSchedule,
      'pauseAutoplayDuringBedtime': pauseAutoplayDuringBedtime,
      'muteNotificationsDuringBedtime': muteNotificationsDuringBedtime,
      'parentalPinEnabled': parentalPinEnabled,
      'hashedPin': hashedPin,
      'failedPinAttempts': failedPinAttempts,
      'lockoutUntil': lockoutUntil,
      'hideMatureContent': hideMatureContent,
      'blockDownloads': blockDownloads,
      'blockPurchases': blockPurchases,
      'blockSettingsChanges': blockSettingsChanges,
    };
  }
}
