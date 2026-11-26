import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_wallet_modal.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Compact, high-precision cost estimate & TruthWorld distribution toggle
/// for the Dubbing Studio Inspector.
///
/// Built with TruthWorld Dark Theme (`AppColors`, `TWTypography`).
class DubbingPricingCalculatorCard extends StatelessWidget {
  const DubbingPricingCalculatorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DubbingStudioController>();

    return Obx(() {
      final isSubOnly = controller.mode.value == DubbingMode.subtitlesOnly;
      final publishToTw = controller.publishToTruthworld.value;
      final calculatedCost = controller.calculatedCostUsd;
      final industryCost = controller.industryBenchmarkCostUsd;
      final chars = controller.totalCharactersRequired;
      final targetCount = controller.targetLanguages.length;
      final savings = (industryCost - calculatedCost).clamp(0, 9999);

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Top-Up link
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'ESTIMATED COST',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                InkWell(
                  onTap: () => Get.dialog(const DubbingWalletModal()),
                  child: const Text(
                    'Credits & Wallet →',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textLink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Clean Tabular Cost Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$${calculatedCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    targetCount == 0
                        ? 'Select a language'
                        : '/ $chars chars • $targetCount ${targetCount == 1 ? 'language' : 'languages'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!isSubOnly && savings > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Save \$${savings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Free / Coverage Status Pill (only when applicable)
            if (controller.isFreeDubbingActive) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.success, size: 13),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '100% Free AI Dubbing Active',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (controller.totalAvailableCharacters >= chars && controller.totalAvailableCharacters > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Covered by your balance (${controller.totalAvailableCharacters} chars)',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Compact TruthWorld Feed Discount Switch
            if (!isSubOnly) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => controller.publishToTruthworld.value = !controller.publishToTruthworld.value,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Publish to TruthWorld Feed',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r'40% discount ($3 / 10k chars vs $5 export)',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: publishToTw ? AppColors.textLink : AppColors.textTertiary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: publishToTw,
                      activeThumbColor: Colors.black,
                      activeTrackColor: Colors.white,
                      inactiveThumbColor: AppColors.textSecondary,
                      inactiveTrackColor: const Color(0xFF232329),
                      onChanged: (val) => controller.publishToTruthworld.value = val,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
