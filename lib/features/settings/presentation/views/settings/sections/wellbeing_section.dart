import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';
import 'package:truthworld/core/utils/time_of_day_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class WellbeingSection extends StatelessWidget {
  const WellbeingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Digital Wellbeing & Screen Time',
      children: [
        _buildBreakReminderTile(context),
        _buildBedtimeReminderTile(context),
        _buildParentalControlsTile(context),
      ],
    );
  }

  Widget _buildBreakReminderTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(() {
      final mins = ctrl.wellbeing.value.breakReminderMinutes;
      final label = mins == 0 ? 'Off' : 'Every $mins minutes';
      return ListTile(
        leading: const Icon(Icons.timer_outlined, color: AppColors.textPrimary),
        title: const Text(
          'Remind me to take a break',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          label,
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showBreakReminderDialog(context),
      );
    });
  }

  void _showBreakReminderDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Take a Break Reminder',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0, 15, 30, 60, 90, 120]
              .map(
                (m) => Obx(
                  () => RadioListTile<int>(
                    title: Text(
                      m == 0 ? 'Off' : 'Every $m minutes',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: m,
                    groupValue: ctrl.wellbeing.value.breakReminderMinutes,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setBreakReminder(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBedtimeReminderTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(() {
      final wb = ctrl.wellbeing.value;
      return ListTile(
        leading: const Icon(
          Icons.bedtime_outlined,
          color: Colors.white,
        ),
        title: const Text(
          'Bedtime Reminder',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          wb.bedtimeEnabled
              ? '${wb.bedtimeStartTime} – ${wb.bedtimeEndTime} (${wb.bedtimeDaysSchedule})'
              : 'Off',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (wb.bedtimeEnabled)
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                tooltip: 'Customize Bedtime',
                onPressed: () => _showBedtimeScheduleDialog(context),
              ),
            Switch(
              value: wb.bedtimeEnabled,
              onChanged: (val) {
                ctrl.toggleBedtimeReminder(val);
                if (val) _showBedtimeScheduleDialog(context);
                if (Get.isRegistered<DigitalWellbeingService>()) {
                  DigitalWellbeingService.to.resetBedtimeTracking();
                  if (val) DigitalWellbeingService.to.checkBedtimeNow();
                }
              },
            ),
          ],
        ),
        onTap: () {
          if (!wb.bedtimeEnabled) {
            ctrl.toggleBedtimeReminder(true);
          }
          _showBedtimeScheduleDialog(context);
        },
      );
    });
  }

  void _showBedtimeScheduleDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      Obx(() {
        final wb = ctrl.wellbeing.value;
        return AlertDialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Bedtime Schedule',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIME WINDOW',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerCard(
                        context: context,
                        label: 'Start time',
                        timeStr: wb.bedtimeStartTime,
                        defaultHour: 23,
                        defaultMinute: 0,
                        onTimePicked: (formattedTime) {
                          ctrl.setBedtimeSchedule(
                            formattedTime,
                            wb.bedtimeEndTime,
                            wb.bedtimeDaysSchedule,
                          );
                          if (Get.isRegistered<DigitalWellbeingService>()) {
                            DigitalWellbeingService.to.resetBedtimeTracking();
                            DigitalWellbeingService.to.checkBedtimeNow();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTimePickerCard(
                        context: context,
                        label: 'End time',
                        timeStr: wb.bedtimeEndTime,
                        defaultHour: 6,
                        defaultMinute: 0,
                        onTimePicked: (formattedTime) {
                          ctrl.setBedtimeSchedule(
                            wb.bedtimeStartTime,
                            formattedTime,
                            wb.bedtimeDaysSchedule,
                          );
                          if (Get.isRegistered<DigitalWellbeingService>()) {
                            DigitalWellbeingService.to.resetBedtimeTracking();
                            DigitalWellbeingService.to.checkBedtimeNow();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'REPEAT DAYS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                ...['Everyday', 'Weekdays', 'Weekends'].map(
                  (sched) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.white,
                    title: Text(
                      sched,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    value: sched,
                    groupValue: wb.bedtimeDaysSchedule,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setBedtimeSchedule(
                          wb.bedtimeStartTime,
                          wb.bedtimeEndTime,
                          val,
                        );
                        if (Get.isRegistered<DigitalWellbeingService>()) {
                          DigitalWellbeingService.to.resetBedtimeTracking();
                          DigitalWellbeingService.to.checkBedtimeNow();
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white12),
                const SizedBox(height: 6),
                const Text(
                  'BEDTIME OPTIONS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Pause autoplay during bedtime',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text(
                    'Stop automatically playing next video',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  value: wb.pauseAutoplayDuringBedtime,
                  onChanged: ctrl.toggleBedtimeAutoplay,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Mute notifications during bedtime',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text(
                    'Silence foreground in-app alerts',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  value: wb.muteNotificationsDuringBedtime,
                  onChanged: ctrl.toggleBedtimeMuteNotifications,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTimePickerCard({
    required BuildContext context,
    required String label,
    required String timeStr,
    required int defaultHour,
    required int defaultMinute,
    required ValueChanged<String> onTimePicked,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final initial = TimeOfDayHelper.parse(
            timeStr,
            fallback: TimeOfDay(hour: defaultHour, minute: defaultMinute),
          );
          final picked = await showTimePicker(
            context: context,
            initialTime: initial,
          );
          if (picked != null && context.mounted) {
            onTimePicked(TimeOfDayHelper.format(picked));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentalControlsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(() {
      final isEnabled = ctrl.wellbeing.value.parentalPinEnabled;
      return ListTile(
        leading: Icon(
          Icons.security,
          color: isEnabled ? Colors.green : AppColors.textPrimary,
        ),
        title: const Text(
          'Parental Controls & PIN Lock',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          isEnabled
              ? 'Restricted Mode Active (SHA-256 Protected)'
              : 'Off • Tap to set 4-digit PIN lock',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showParentalPinDialog(context),
      );
    });
  }

  void _showParentalPinDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    final pinCtrl = TextEditingController();

    Get.dialog(
      Obx(() {
        final isEnabled = ctrl.wellbeing.value.parentalPinEnabled;
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text(
            isEnabled ? 'Parental Controls Active' : 'Setup Parental PIN Lock',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEnabled
                    ? 'Enter your 4-digit PIN to disable restricted mode:'
                    : 'Create a 4-digit PIN to restrict mature content & lock settings:',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  letterSpacing: 8,
                  fontSize: 20,
                ),
                decoration: const InputDecoration(hintText: '••••'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (isEnabled)
              TextButton(
                onPressed: () {
                  if (ctrl.verifyParentalPin(pinCtrl.text.trim())) {
                    ctrl.disableParentalPin();
                    Get.back();
                    AppSnackbar.info(
                      'Restricted mode turned off.',
                      title: 'Parental Controls Disabled',
                    );
                  } else {
                    AppSnackbar.warning(
                      'The PIN entered is invalid.',
                      title: 'Incorrect PIN',
                    );
                  }
                },
                child: const Text(
                  'Disable Lock',
                  style: TextStyle(color: AppColors.error),
                ),
              )
            else
              TextButton(
                onPressed: () {
                  if (pinCtrl.text.trim().length == 4) {
                    ctrl.setParentalPin(pinCtrl.text.trim());
                    Get.back();
                    AppSnackbar.success(
                      'Parental control PIN enabled successfully.',
                      title: 'PIN Set',
                    );
                  }
                },
                child: Text(
                  'Save PIN',
                  style: TextStyle(color: context.colors.brand),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ================= 3. PLAYBACK & MEDIA TILES =================


}
