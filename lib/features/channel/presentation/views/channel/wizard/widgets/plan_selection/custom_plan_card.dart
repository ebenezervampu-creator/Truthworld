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
                          Icons.card_giftcard,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          r'$10 FREE Bonus Credit Included',
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
                    children: [r'$15', r'$30', r'$45', 'Custom'].map((tier) {
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
                  SizedBox(height: isDesktop ? 6 : 14),
                  Obx(() {
                    final selectedTier = controller.customPricingTier.value;
                    List<String> tierBadges;
                    if (selectedTier == 'Custom') {
                      tierBadges = [
                        'Flexible Storage & CDN',
                        'Dedicated VIP Support & SLA',
                        'Custom Integration',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$45') {
                      tierBadges = [
                        '1 TB Cloud Storage',
                        '5 TB Global CDN Bandwidth',
                        '4K HDR Video',
                        r'$20 Monthly Bonus Credit',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$30') {
                      tierBadges = [
                        '300 GB Cloud Storage',
                        '1.5 TB Global CDN Bandwidth',
                        '4K Ultra HD',
                        r'$10 Monthly Bonus Credit',
                        '100% Revenue Share',
                      ];
                    } else {
                      tierBadges = [
                        '100 GB Cloud Storage',
                        '500 GB Global CDN Bandwidth',
                        '4K Ultra HD',
                        'Unlimited Uploads',
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
