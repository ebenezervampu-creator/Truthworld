import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Detailed comparison table showing custom plan storage, CDN, and capacity breakdown.
class CustomTierBreakdownTable extends StatelessWidget {
  const CustomTierBreakdownTable({
    required this.controller,
    required this.isDesktop,
    super.key,
  });

  final ChannelController controller;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.selectedPlan.value != 'custom') {
        return const SizedBox.shrink();
      }

      final activeTier = controller.customPricingTier.value;

      final tiers = [
        {
          'id': r'$15',
          'name': r'$15/mo (Starter)',
          'storage': '100 GB Cloud Storage',
          'cdn': '500 GB Global CDN',
          'capacity': '~300 HD/4K videos (~1,500 hrs)',
        },
        {
          'id': r'$30',
          'name': r'$30/mo (Pro)',
          'storage': '300 GB Cloud Storage',
          'cdn': '1.5 TB (1,500 GB) Global CDN',
          'capacity': '~1,000 HD/4K videos (~5,000 hrs)',
        },
        {
          'id': r'$45',
          'name': r'$45/mo (Enterprise)',
          'storage': '1 TB (1,000 GB) Storage',
          'cdn': '5 TB (5,000 GB) Global CDN',
          'capacity': '~3,000+ HD/4K videos (~15,000+ hrs)',
        },
        {
          'id': 'Custom',
          'name': 'Custom Quote',
          'storage': 'Flexible Storage Limit',
          'cdn': 'Custom Global CDN',
          'capacity': 'Enterprise Level (Custom SLA)',
        },
      ];

      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: EdgeInsets.all(isDesktop ? 16 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                  child: const Icon(
                    Icons.storage,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Custom Tiers Breakdown & Storage Comparison',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tiers.map((tier) {
              final isCurrentActive = activeTier == tier['id'];
              return GestureDetector(
                onTap: () {
                  controller.customPricingTier.value = tier['id']!;
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentActive
                        ? const Color(0xFF4C1D95).withOpacity(0.35)
                        : const Color(0xFF1C1C22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrentActive
                          ? const Color(0xFFA855F7)
                          : const Color(0xFF2E2E38),
                      width: isCurrentActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrentActive
                              ? const Color(0xFF7C3AED)
                              : Colors.transparent,
                          border: Border.all(
                            color: isCurrentActive
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF52525B),
                            width: 1.5,
                          ),
                        ),
                        child: isCurrentActive
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier['name']!,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 13,
                                fontWeight: isCurrentActive
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isCurrentActive
                                    ? const Color(0xFFC084FC)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tier['storage']} • ${tier['cdn']}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            tier['capacity']!,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}
