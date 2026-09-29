import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_plan_badge_item.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/plan_selection/plan_graphics.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card presenting the Custom Plan tier with selectable pricing options.
class CustomPlanCard extends StatelessWidget {
  const CustomPlanCard({
    required this.controller,
    required this.isDarkMode,
    required this.isDesktop,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.selectedPlan.value == 'custom';
      final isError =
          controller.planSelectionError.value &&
          controller.selectedPlan.value.isEmpty;

      return GestureDetector(
        onTap: () {
          controller.selectedPlan.value = 'custom';
          controller.planSelectionError.value = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isDesktop ? 12 : 20),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF12121B)
                : AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7C3AED)
                  : isError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF27272A),
              width: (isSelected || isError) ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF7C3AED)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF3F3F46),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              Column(
                children: [
                  SizedBox(height: isDesktop ? 0 : 4),
                  CustomRocket3DGraphic(isDesktop: isDesktop),
                  SizedBox(height: isDesktop ? 6 : 12),
                  const Text(
                    'Custom Channel',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Advanced features • Higher revenue share • More control',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktop ? 6 : 14),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 10 : 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C1D95).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA855F7)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '100% Creator Revenue Share',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC084FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 10),
                  const Text(
                    'Select Custom Pricing Tier:',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [r'$15', r'$30', r'$45', r'$100', r'$200', 'Custom'].map((tier) {
                      return Obx(() {
                        final isTierSelected =
                            controller.customPricingTier.value == tier;
                        final label = tier == 'Custom' ? 'Custom' : '$tier/mo';
                        return GestureDetector(
                          onTap: () {
                            controller.selectedPlan.value = 'custom';
                            controller.customPricingTier.value = tier;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 10 : 14,
                              vertical: isDesktop ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: isTierSelected
                                   ? const Color(0xFF7C3AED)
                                  : const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTierSelected
                                    ? const Color(0xFFA855F7)
                                    : const Color(0xFF3F3F46),
                              ),
                              boxShadow: isTierSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED)
                                            .withOpacity(0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 12,
                                fontWeight: isTierSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      });
                    }).toList(),
                  ),
                  SizedBox(height: isDesktop ? 6 : 10),
                  Obx(() {
                    final isAutoPay = controller.customPlanAutoPay.value;
                    final tier = controller.customPricingTier.value;
                    final tierLabel = tier == 'Custom' ? 'Custom tier' : '$tier/mo';

                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 12,
                        vertical: isDesktop ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAutoPay
                              ? const Color(0xFFA855F7).withOpacity(0.6)
                              : const Color(0xFF27272A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isAutoPay
                                  ? const Color(0xFF7C3AED).withOpacity(0.2)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.autorenew_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Auto Pay',
                                      style: TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isAutoPay
                                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                            : const Color(0xFF3F3F46),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isAutoPay ? 'RECURRING' : 'ONE-TIME',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: isAutoPay
                                              ? const Color(0xFF34D399)
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isAutoPay
                                      ? 'Auto-renews $tierLabel each month. Cancel anytime.'
                                      : 'One-time month payment. No recurring debit.',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isAutoPay,
                            onChanged: (val) {
                              controller.selectedPlan.value = 'custom';
                              controller.customPlanAutoPay.value = val;
                            },
                            activeColor: Colors.white,
                            activeTrackColor: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: isDesktop ? 6 : 14),
                  Obx(() {
                    final selectedTier = controller.customPricingTier.value;
                    List<String> tierBadges;
                    if (selectedTier == 'Custom') {
                      tierBadges = [
                        'Flexible Storage & CDN',
                        'Dedicated VIP Support & SLA',
                        r'AI Dubbing (From $0.10/lang at-cost)',
                        'Studio Voice Cloning Included',
                        '100% Free Fact-Checking',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$200') {
                      tierBadges = [
                        '800 GB Cloud Storage',
                        '3.2 TB Global CDN Bandwidth',
                        '8K Cinema Master & HDR',
                        '100% Free Fact-Checking',
                        r'AI Dubbing (From $0.10/lang at-cost)',
                        'Studio Voice Cloning Included',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$100') {
                      tierBadges = [
                        '400 GB Cloud Storage',
                        '1.6 TB Global CDN Bandwidth',
                        '4K HDR & 8K Transcoding',
                        '100% Free Fact-Checking',
                        r'AI Dubbing (From $0.10/lang at-cost)',
                        'Studio Voice Cloning Included',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$45') {
                      tierBadges = [
                        '150 GB Cloud Storage',
                        '750 GB Global CDN Bandwidth',
                        '4K HDR Video',
                        '100% Free Fact-Checking',
                        r'AI Dubbing (From $0.10/lang at-cost)',
                        'Studio Voice Cloning Included',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$30') {
                      tierBadges = [
                        '100 GB Cloud Storage',
                        '500 GB Global CDN Bandwidth',
                        '4K Ultra HD',
                        '100% Free Fact-Checking',
                        r'AI Dubbing (From $0.10/lang at-cost)',
                        'Studio Voice Cloning Included',
                        '100% Revenue Share',
                      ];
                    } else {
                      tierBadges = [
                        '50 GB Cloud Storage',
                        '250 GB Global CDN Bandwidth',
                        '4K Ultra HD',
                        'Unlimited Uploads',
                        '100% Free Fact-Checking',
                        r'AI Dubbing (From $0.10/lang at-cost)',
                        'Studio Voice Cloning Included',
                        '100% Revenue Share',
                      ];
                    }

                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: isDesktop ? 6 : 8,
                      runSpacing: isDesktop ? 6 : 8,
                      children: tierBadges
                          .map((badge) => PlanBadgeItem(text: badge))
                          .toList(),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
