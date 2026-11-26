import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for Super Admin to directly configure special discounts,
/// grant free Dubbing Studio credits, and configure upload duration limits for any channel.
void showAdminChannelDiscountDialog({
  required BuildContext context,
  required AdminController controller,
  required Map<String, dynamic> channel,
}) {
  if (!controller.isSuperAdmin) {
    AppSnackbar.warning('Only Super Admins can configure channel privileges and discounts.');
    return;
  }

  final channelId = (channel['id'] ?? channel['channelId'] ?? '').toString();
  final channelName = (channel['name'] ?? channel['channelName'] ?? 'Channel').toString();
  final channelHandle = (channel['handle'] ?? '').toString();

  // 1. Initial discount values from channel doc
  final currentDubType = (channel['dubbingDiscountType'] ?? 'none').toString();
  final currentDubPercent = (channel['dubbingDiscountPercent'] as num?)?.toDouble() ?? 0.0;
  final currentSubType = (channel['subtitlesDiscountType'] ?? 'none').toString();
  final currentSubPercent = (channel['subtitlesDiscountPercent'] as num?)?.toDouble() ?? 0.0;

  final selectedDubType = currentDubType.obs; // 'none', '50%', 'free', 'custom'
  final customDubPercent = (currentDubPercent > 0 ? currentDubPercent.round() : 25).obs;
  final dubCustomCtrl = TextEditingController(
    text: currentDubPercent > 0 ? currentDubPercent.round().toString() : '25',
  );

  final selectedSubType = currentSubType.obs; // 'none', '50%', 'free', 'custom'
  final customSubPercent = (currentSubPercent > 0 ? currentSubPercent.round() : 25).obs;
  final subCustomCtrl = TextEditingController(
    text: currentSubPercent > 0 ? currentSubPercent.round().toString() : '25',
  );

  // 2. Initial Free Dubbing Studio Credits
  final existingGrantedCredits = (channel['freeDubbingCredits'] as num?)?.toInt() ?? 0;
  final selectedCreditGrant = 0.obs;
  final customCreditsCtrl = TextEditingController(text: '0');

  // 3. Initial Upload Limit Duration (minutes)
  final currentSeconds = (channel['customDailyVideoDurationSeconds'] as num?)?.toInt() ??
      (channel['maxDailyVideoDurationSeconds'] as num?)?.toInt() ??
      600;
  final currentMinutes = (currentSeconds / 60).round().clamp(10, 1440);
  final selectedMinutes = currentMinutes.obs;
  final customMinutesCtrl = TextEditingController(text: currentMinutes.toString());

  // 4. Reason
  final reasonCtrl = TextEditingController(
    text: (channel['quotaIncreaseReason'] ?? channel['lastDubbingGrantReason'] ?? 'VIP Creator Partner').toString(),
  );

  final isSaving = false.obs;

  void applyQuickPreset(String mode) {
    if (mode == 'both_free') {
      selectedDubType.value = 'free';
      selectedSubType.value = 'free';
    } else if (mode == 'both_fifty') {
      selectedDubType.value = '50%';
      selectedSubType.value = '50%';
    } else if (mode == 'both_standard') {
      selectedDubType.value = 'none';
      selectedSubType.value = 'none';
    }
  }

  unawaited(
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgPage,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Channel Super Admin Privileges',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'SUPER ADMIN ONLY',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Directly configure discounts, free Dubbing Studio credits, and upload duration limits for this channel',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel Summary Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_circle_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channelName,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (channelHandle.isNotEmpty)
                              Text(
                                '@$channelHandle',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (existingGrantedCredits > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Active: ${existingGrantedCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} free chars',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick presets row
                const Text(
                  'QUICK BENEFIT PRESETS',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetButton(
                      label: 'Both 100% Free',
                      icon: Icons.card_giftcard_rounded,
                      color: AppColors.success,
                      onTap: () => applyQuickPreset('both_free'),
                    ),
                    _PresetButton(
                      label: 'Both 50% Off',
                      icon: Icons.percent_rounded,
                      color: AppColors.info,
                      onTap: () => applyQuickPreset('both_fifty'),
                    ),
                    _PresetButton(
                      label: 'Reset to Standard (0%)',
                      icon: Icons.restart_alt_rounded,
                      color: AppColors.textTertiary,
                      onTap: () => applyQuickPreset('both_standard'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ═════════════════════════════════════════════════════════════
                // SECTION 1: AI Audio Dubbing & Subtitles Discounts
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader(
                  title: '1. AI Dubbing & Subtitles Discounts',
                  icon: Icons.local_offer_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 10),
                _buildDiscountSection(
                  title: 'AI Audio Dubbing Discount',
                  subtitle: 'Applies when this channel creates AI dubbed video tracks',
                  icon: Icons.record_voice_over_rounded,
                  accentColor: AppColors.info,
                  selectedType: selectedDubType,
                  customPercent: customDubPercent,
                  customCtrl: dubCustomCtrl,
                ),
                const SizedBox(height: 14),
                _buildDiscountSection(
                  title: 'AI Subtitles Discount',
                  subtitle: 'Applies when this channel generates multilingual subtitles',
                  icon: Icons.subtitles_rounded,
                  accentColor: AppColors.textLink,
                  selectedType: selectedSubType,
                  customPercent: customSubPercent,
                  customCtrl: subCustomCtrl,
                ),
                const SizedBox(height: 22),

                // ═════════════════════════════════════════════════════════════
                // SECTION 2: Free Dubbing Studio Credits Grant
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader(
                  title: '2. Grant Free Dubbing Studio Credits',
                  icon: Icons.bolt_rounded,
                  color: AppColors.info,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add complimentary character credits to this channel directly (usable in Dubbing Studio & Video AI)',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Obx(() {
                  const creditOptions = [0, 5000, 10000, 25000, 50000, 100000];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: creditOptions.map((amount) {
                      final isSelected = selectedCreditGrant.value == amount;
                      final label = amount == 0
                          ? '+0 (No change)'
                          : '+${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars';
                      return _OptionChip(
                        label: label,
                        isSelected: isSelected,
                        activeColor: AppColors.info,
                        onTap: () {
                          selectedCreditGrant.value = amount;
                          customCreditsCtrl.text = amount.toString();
                        },
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Custom Characters to Grant:',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: customCreditsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: AppColors.bgSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 0;
                          selectedCreditGrant.value = parsed.clamp(0, 10000000);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ═════════════════════════════════════════════════════════════
                // SECTION 3: Channel Daily Upload Duration Limit
                // ═════════════════════════════════════════════════════════════
                _buildSectionHeader(
                  title: '3. Channel Daily Upload Limit Duration',
                  icon: Icons.timer_outlined,
                  color: AppColors.success,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Adjust the maximum daily video upload duration for this channel (Standard = 10 minutes)',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Obx(() {
                  const durationPresets = [10, 15, 20, 30, 45, 60, 120, 240];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: durationPresets.map((mins) {
                      final isSelected = selectedMinutes.value == mins;
                      final label = mins == 10
                          ? '10m (Standard)'
                          : mins >= 60
                              ? '${mins ~/ 60}h (${mins}m)'
                              : '${mins}m';
                      return _OptionChip(
                        label: label,
                        isSelected: isSelected,
                        activeColor: AppColors.success,
                        onTap: () {
                          selectedMinutes.value = mins;
                          customMinutesCtrl.text = mins.toString();
                        },
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Custom Duration (Minutes):',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: customMinutesCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: '10',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: AppColors.bgSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 10;
                          selectedMinutes.value = parsed.clamp(10, 1440);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Reason input
                const Text(
                  'REASON / PARTNERSHIP JUSTIFICATION',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. VIP Creator Partner, Promotional Support, Onboarding Grant',
                    hintStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Live Summary Banner
                Obx(() {
                  final dubLabel = _formatDiscountLabel(selectedDubType.value, customDubPercent.value);
                  final subLabel = _formatDiscountLabel(selectedSubType.value, customSubPercent.value);
                  final granted = selectedCreditGrant.value;
                  final mins = selectedMinutes.value;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Benefit for Creator:\n• Dubbing: $dubLabel | Subtitles: $subLabel\n• Dubbing Credits: ${granted > 0 ? "+${granted.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} free chars" : "No grant added"}\n• Daily Upload Limit: $mins minutes/day',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.warning,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Obx(() {
            return ElevatedButton.icon(
              onPressed: isSaving.value
                  ? null
                  : () async {
                      isSaving.value = true;
                      try {
                        final dubType = selectedDubType.value;
                        final dubPct = dubType == 'free'
                            ? 100.0
                            : (dubType == '50%'
                                ? 50.0
                                : (dubType == 'none'
                                    ? 0.0
                                    : customDubPercent.value.toDouble().clamp(0.0, 100.0)));

                        final subType = selectedSubType.value;
                        final subPct = subType == 'free'
                            ? 100.0
                            : (subType == '50%'
                                ? 50.0
                                : (subType == 'none'
                                    ? 0.0
                                    : customSubPercent.value.toDouble().clamp(0.0, 100.0)));

                        final success = await controller.updateChannelSuperAdminPrivileges(
                          channelId: channelId,
                          dubbingDiscountType: dubType,
                          dubbingDiscountPercent: dubPct,
                          subtitlesDiscountType: subType,
                          subtitlesDiscountPercent: subPct,
                          dailyUploadDurationMinutes: selectedMinutes.value,
                          freeCreditsToGrant: selectedCreditGrant.value,
                          reason: reasonCtrl.text.trim().isNotEmpty
                              ? reasonCtrl.text.trim()
                              : 'Super Admin Channel Privileges',
                        );

                        if (success) {
                          Get.back();
                        }
                      } finally {
                        isSaving.value = false;
                      }
                    },
              icon: isSaving.value
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 16, color: Colors.black),
              label: Text(
                isSaving.value ? 'Applying...' : 'Apply Super Admin Privileges',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

Widget _buildSectionHeader({
  required String title,
  required IconData icon,
  required Color color,
}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

Widget _buildDiscountSection({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accentColor,
  required RxString selectedType,
  required RxInt customPercent,
  required TextEditingController customCtrl,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textTertiary,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 8),
      Obx(() {
        final currentType = selectedType.value;
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _OptionChip(
              label: 'Standard (0%)',
              isSelected: currentType == 'none',
              activeColor: accentColor,
              onTap: () => selectedType.value = 'none',
            ),
            _OptionChip(
              label: '50% Off',
              isSelected: currentType == '50%',
              activeColor: accentColor,
              onTap: () => selectedType.value = '50%',
            ),
            _OptionChip(
              label: '100% Free',
              isSelected: currentType == 'free',
              activeColor: AppColors.success,
              onTap: () => selectedType.value = 'free',
            ),
            _OptionChip(
              label: currentType == 'custom'
                  ? '${customPercent.value}% Custom'
                  : 'Custom %',
              isSelected: currentType == 'custom',
              activeColor: accentColor,
              onTap: () => selectedType.value = 'custom',
            ),
          ],
        );
      }),
      Obx(() {
        if (selectedType.value != 'custom') return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Text(
                'Discount %:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: customCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: '25',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: AppColors.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    customPercent.value = parsed.clamp(0, 100);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: accentColor,
                    thumbColor: accentColor,
                    overlayColor: accentColor.withValues(alpha: 0.2),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: customPercent.value.toDouble().clamp(0.0, 100.0),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (val) {
                      customPercent.value = val.round();
                      customCtrl.text = val.round().toString();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

String _formatDiscountLabel(String type, int customPct) {
  if (type == 'free') return '100% Free';
  if (type == '50%') return '50% Discount';
  if (type == 'custom') return '$customPct% Custom Discount';
  return 'Standard (0% Discount)';
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.textLink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveActiveColor.withValues(alpha: 0.18)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? effectiveActiveColor
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
