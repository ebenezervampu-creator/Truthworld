import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_plan_badge_item.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/plan_selection/plan_graphics.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card presenting the Standard Free tier for channel creation.
class StandardPlanCard extends StatelessWidget {
  const StandardPlanCard({
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
      final isSelected = controller.selectedPlan.value == 'standard';
      final isError =
          controller.planSelectionError.value &&
          controller.selectedPlan.value.isEmpty;

      return GestureDetector(
        onTap: () {
          controller.selectedPlan.value = 'standard';
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
                  Standard3DGraphic(isDesktop: isDesktop),
                  SizedBox(height: isDesktop ? 6 : 12),
                  const Text(
                    'Standard Channel',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ideal for creators who are starting out',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktop ? 8 : 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: isDesktop ? 6 : 8,
                    runSpacing: isDesktop ? 6 : 8,
                    children: const [
                      PlanBadgeItem(text: '70% Revenue Share (Ads & Premium)'),
                      PlanBadgeItem(text: '100% Memberships & Superchats'),
                      PlanBadgeItem(text: '10 min/day upload'),
                      PlanBadgeItem(text: 'Up to 4K UHD'),
                      PlanBadgeItem(text: r'Standard Dubbing ($0.50/lang)'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
