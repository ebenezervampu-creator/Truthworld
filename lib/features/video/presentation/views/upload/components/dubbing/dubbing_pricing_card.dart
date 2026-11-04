import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Live pricing breakdown card for dubbing selection with ElevenLabs polish.
class DubbingPricingCard extends StatelessWidget {
  const DubbingPricingCard({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final totalSelected = controller.selectedLanguages.length;
      final cost = controller.calculatedCost;
      final flatRate = controller.flatDubbingRatePerLang;
      final wallet = controller.walletBalance;
      final isInsufficient = controller.isInsufficientBalance;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF14151B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInsufficient
                ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                : const Color(0xFF262834),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Live Pricing Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F212A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2D303E)),
                  ),
                  child: Text(
                    '\$${flatRate.toStringAsFixed(2)} / lang',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics table
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101116),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF20222C)),
              ),
              child: Column(
                children: [
                  _buildMetricRow(
                    'Selected Production Tier:',
                    '${controller.currentProductionTier.name} (${controller.currentProductionTier.badge})',
                    highlightColor: controller.isCinemaGradeEnabled.value ? const Color(0xFFFDE047) : null,
                  ),
                  const SizedBox(height: 6),
                  _buildMetricRow('Target Dubbing Languages:', '$totalSelected'),
                  const SizedBox(height: 6),
                  _buildMetricRow(
                    'Flat Rate per Language:',
                    '\$${flatRate.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  _buildMetricRow(
                    'Included Matching Subtitles:',
                    'Free ($totalSelected languages)',
                    highlightColor: const Color(0xFF34D399),
                  ),
                  if (controller.isLipSyncEnabled.value) ...[
                    const SizedBox(height: 6),
                    _buildMetricRow(
                      'AI Visual Lip-Sync (LatentSync):',
                      'Included in ${controller.currentProductionTier.name}',
                      highlightColor: const Color(0xFF38BDF8),
                    ),
                  ],
                  if (controller.isCinemaGradeEnabled.value) ...[
                    const SizedBox(height: 6),
                    _buildMetricRow(
                      'Cinema 4K + Stem Isolation:',
                      'Included in Video Ultra',
                      highlightColor: const Color(0xFFFACC15),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Total & Wallet balance row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Dubbing Cost',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${cost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Wallet Balance: \$${wallet.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isInsufficient ? const Color(0xFFEF4444) : const Color(0xFFA1A1AA),
                        fontSize: 12,
                        fontWeight: isInsufficient ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isInsufficient)
                      InkWell(
                        onTap: () {
                          if (controller.channel != null) {
                            ChannelWalletTopupSheet.show(
                              context,
                              channel: controller.channel!,
                            );
                          }
                        },
                        child: const Text(
                          '+ Add Funds',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Text(
                        '100% At-Cost Platform Rate',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMetricRow(String label, String value, {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA1A1AA),
            fontSize: 11.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
